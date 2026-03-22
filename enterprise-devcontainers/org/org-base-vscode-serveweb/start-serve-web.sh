#!/usr/bin/env bash
# =============================================================================
# Start VS Code CLI serve-web in the background, fully detached from
# VS Code Server's process tree.
#
# This replaces code-server (Coder) with Microsoft's official VS Code CLI
# serve-web command. Same three fixes apply:
#
#   1. VSCODE_IPC_HOOK_CLI delegation → strip all VSCODE_* env vars
#   2. Process tree cleanup → setsid to create new session
#   3. Data isolation → separate --server-data-dir
#
# serve-web serves the full VS Code UI in the browser using the official
# VS Code Marketplace (not Open VSX like code-server).
# =============================================================================
set -euo pipefail

# Load Docker secrets if available
[ -f /usr/local/bin/load-secrets.sh ] && source /usr/local/bin/load-secrets.sh

# Load runtime constants
[ -f /usr/local/bin/devcontainer-constants.sh ] && source /usr/local/bin/devcontainer-constants.sh

LOG_FILE="/tmp/serve-web.log"
DATA_DIR="/home/node/.vscode-serve-web"

# Ensure data directory exists
mkdir -p "$DATA_DIR"

# Kill any leftover serve-web from a previous run
pkill -f "code serve-web" 2>/dev/null || true
sleep 1

echo "============================================"
echo "  Starting VS Code serve-web..."
echo "============================================"

# Build env -u flags for ALL VSCODE_* variables dynamically
UNSET_FLAGS=""
while IFS='=' read -r name _; do
    case "$name" in
        VSCODE_*) UNSET_FLAGS="$UNSET_FLAGS -u $name" ;;
    esac
done < <(env)

# Start serve-web in a NEW SESSION via setsid
# --host 0.0.0.0          → listen on all interfaces (needed for Docker port forwarding)
# --port 8229              → our standard port
# --without-connection-token → no token auth (use network isolation instead)
# --server-data-dir        → isolated from VS Code Desktop's data
# --accept-server-license-terms → non-interactive acceptance
# shellcheck disable=SC2086
setsid env $UNSET_FLAGS \
    /usr/local/bin/code serve-web \
    --host 0.0.0.0 \
    --port ${PORT_SERVE_WEB} \
    --without-connection-token \
    --server-data-dir "$DATA_DIR" \
    --accept-server-license-terms \
    > "$LOG_FILE" 2>&1 &
disown -a 2>/dev/null || true

# Wait for serve-web to bind
MAX_RETRIES=30
RETRY_INTERVAL=2
echo "  Waiting for serve-web to bind to port ${PORT_SERVE_WEB}..."
for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf --max-time 1 http://127.0.0.1:${PORT_SERVE_WEB} > /dev/null 2>&1; then
        echo "  serve-web is ready!"
        echo ""
        echo "  ┌─────────────────────────────────────────┐"
        echo "  │  Browser IDE:  http://localhost:${PORT_SERVE_WEB}     │"
        echo "  │  Auth:         none (connection token    │"
        echo "  │                disabled)                 │"
        echo "  └─────────────────────────────────────────┘"
        echo ""
        echo "============================================"
        exit 0
    fi
    echo "  Attempt $i/$MAX_RETRIES — waiting ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

echo "  [ERROR] serve-web failed to bind to port ${PORT_SERVE_WEB} after $MAX_RETRIES attempts."
echo "  First launch downloads the VS Code Server binary (~60MB)."
echo "  Check: cat $LOG_FILE"
echo "  Check: ss -tlnp | grep ${PORT_SERVE_WEB}"
echo "============================================"
exit 1
