#!/usr/bin/env bash
# =============================================================================
# Universal startup — launches BOTH serve-web and SSH server.
#
# Access points after startup:
#   VS Code Desktop:   Automatic (Reopen in Container)
#   VS Code Browser:   http://localhost:8229
#   JetBrains Gateway: ssh node@localhost -p 2222
#   Cursor/Windsurf:   Same as VS Code Desktop (DevContainer extension)
#   Zed:               ssh node@localhost -p 2222
#   Any SSH IDE:       ssh node@localhost -p 2222
#   Terminal:          docker exec -it <id> zsh
# =============================================================================
set -euo pipefail

# Load Docker secrets if available (for non-interactive processes)
[ -f /usr/local/bin/load-secrets.sh ] && source /usr/local/bin/load-secrets.sh

# Load runtime constants
[ -f /usr/local/bin/devcontainer-constants.sh ] && source /usr/local/bin/devcontainer-constants.sh

# ── Security integrity check (cannot be skipped by child images) ─────────
# This runs inside the parent's startup script. Even if a child Dockerfile
# removes the build-time assert, this runtime check still executes because
# the child inherits this script via the Docker layer.
# If the child replaces this script, the checksum of start-universal.sh
# itself will fail verification.
if [ -f /usr/local/bin/verify-integrity.sh ]; then
    INTEGRITY_MODE="${INTEGRITY_MODE:-warn}" /usr/local/bin/verify-integrity.sh
fi

ERRORS=0

# ── Per-developer isolation (unique password, identity tracking) ─────────
if [ -f /usr/local/bin/setup-developer-identity.sh ]; then
    /usr/local/bin/setup-developer-identity.sh
    # Re-source constants to pick up the generated password
    [ -f /tmp/.ssh-password ] && export SSH_PASSWORD=$(cat /tmp/.ssh-password)
fi

echo "============================================"
echo "  Starting Universal IDE environment..."
echo "============================================"
echo ""

# Start serve-web (browser IDE)
if ! /usr/local/bin/start-serve-web.sh; then
    echo "  [ERROR] serve-web failed to start"
    ERRORS=$((ERRORS + 1))
fi

# Start SSH server (JetBrains / Zed / SSH IDEs)
if ! /usr/local/bin/start-ssh.sh; then
    echo "  [ERROR] SSH server failed to start"
    ERRORS=$((ERRORS + 1))
fi

echo ""
if [ "$ERRORS" -gt 0 ]; then
    echo "  ┌──────────────────────────────────────────────┐"
    echo "  │  WARNING: $ERRORS service(s) failed to start    │"
    echo "  │  Check logs above for details                 │"
    echo "  └──────────────────────────────────────────────┘"
    exit 1
else
    echo "  ┌──────────────────────────────────────────────┐"
    echo "  │  All access points ready:                     │"
    echo "  │                                               │"
    echo "  │  VS Code Desktop:  Reopen in Container        │"
    echo "  │  VS Code Browser:  http://localhost:${PORT_SERVE_WEB}      │"
    echo "  │  JetBrains/SSH:    ssh node@localhost -p ${PORT_SSH}  │"
    echo "  │  Password:         ${SSH_PASSWORD}                  │"
    echo "  │  Health:           http://localhost:${PORT_HEALTH}       │"
    echo "  └──────────────────────────────────────────────┘"
fi

# ── Start health dashboard (background) ──────────────────────────────────
if [ -f /usr/local/bin/health-endpoint.sh ]; then
    /usr/local/bin/health-endpoint.sh &
    disown -a 2>/dev/null || true
fi
echo ""
