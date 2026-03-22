#!/usr/bin/env bash
# =============================================================================
# Start code-server (Coder) in the background, fully detached from
# VS Code Server's process tree.
#
# Three fixes for coexistence with VS Code Desktop:
#
#   1. VSCODE_IPC_HOOK_CLI delegation → strip all VSCODE_* env vars
#      Without this, code-server detects the VS Code IPC socket and
#      silently delegates to the existing VS Code instance, then exits.
#
#   2. Process tree cleanup → setsid to create new session
#      Without this, VS Code Server kills code-server ~60s after
#      postStartCommand completes.
#
#   3. Data isolation → separate --user-data-dir and --extensions-dir
#      Without this, code-server and VS Code Server share extension
#      storage, causing binary-incompatible extension host crashes.
# =============================================================================
set -euo pipefail

# Load Docker secrets if available (for non-interactive processes)
[ -f /usr/local/bin/load-secrets.sh ] && source /usr/local/bin/load-secrets.sh

# Load runtime constants
[ -f /usr/local/bin/devcontainer-constants.sh ] && source /usr/local/bin/devcontainer-constants.sh

# Security integrity check
if [ -f /usr/local/bin/verify-integrity.sh ]; then
    INTEGRITY_MODE="${INTEGRITY_MODE:-warn}" /usr/local/bin/verify-integrity.sh
fi

# Per-developer isolation
if [ -f /usr/local/bin/setup-developer-identity.sh ]; then
    /usr/local/bin/setup-developer-identity.sh
    [ -f /tmp/.ssh-password ] && export CODE_SERVER_PASSWORD=$(cat /tmp/.ssh-password)
fi

LOG_FILE="/tmp/code-server.log"
CONFIG_FILE="/home/node/.config/code-server/config.yaml"
CS_DATA_DIR="/home/node/.code-server-data"
CS_EXT_DIR="/home/node/.code-server-extensions"

# Ensure isolated directories exist
mkdir -p "$CS_DATA_DIR" "$CS_EXT_DIR"

# Kill any leftover code-server from a previous run
pkill -f "code-server" 2>/dev/null || true
sleep 1

echo "============================================"
echo "  Starting code-server (Coder)..."
echo "============================================"

# FIX #1: Build env -u flags for ALL VSCODE_* variables dynamically
UNSET_FLAGS=""
while IFS='=' read -r name _; do
    case "$name" in
        VSCODE_*) UNSET_FLAGS="$UNSET_FLAGS -u $name" ;;
    esac
done < <(env)

# FIX #2: Start in a NEW SESSION via setsid
# FIX #3: Isolated --user-data-dir and --extensions-dir
# shellcheck disable=SC2086
setsid env $UNSET_FLAGS \
    /usr/bin/code-server \
    --config "$CONFIG_FILE" \
    --user-data-dir "$CS_DATA_DIR" \
    --extensions-dir "$CS_EXT_DIR" \
    /workspace > "$LOG_FILE" 2>&1 &
disown -a 2>/dev/null || true

# Wait for code-server to bind
MAX_RETRIES=30
RETRY_INTERVAL=2
echo "  Waiting for code-server to bind to port ${PORT_CODE_SERVER}..."
for i in $(seq 1 $MAX_RETRIES); do
    if curl -sf --max-time 1 http://127.0.0.1:${PORT_CODE_SERVER} > /dev/null 2>&1; then
        echo "  code-server is ready!"
        echo ""
        echo "  ┌─────────────────────────────────────────┐"
        echo "  │  Browser IDE:  http://localhost:${PORT_CODE_SERVER}     │"
        echo "  │  Password:     ${CODE_SERVER_PASSWORD}                │"
        echo "  │  Marketplace:  Open VSX                  │"
        echo "  └─────────────────────────────────────────┘"
        echo ""
        echo "============================================"
        exit 0
    fi
    echo "  Attempt $i/$MAX_RETRIES — waiting ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

echo "  [ERROR] code-server failed to start after ${MAX_RETRIES} attempts."
echo "  Check: cat $LOG_FILE"
echo "  Check: ss -tlnp | grep ${PORT_CODE_SERVER}"
echo "============================================"
exit 1
