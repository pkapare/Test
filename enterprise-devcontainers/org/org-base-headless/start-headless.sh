#!/usr/bin/env bash
# =============================================================================
# Headless startup — firewall only, no IDE server.
#
# Use cases:
#   - CI/CD pipelines: claude -p "review this PR" --print
#   - Automation: claude --dangerously-skip-permissions -p "fix lint errors"
#   - Terminal users: direct SSH or docker exec
# =============================================================================
set -euo pipefail

# Load Docker secrets if available (for non-interactive processes)
[ -f /usr/local/bin/load-secrets.sh ] && source /usr/local/bin/load-secrets.sh

# Load runtime constants
[ -f /usr/local/bin/devcontainer-constants.sh ] && source /usr/local/bin/devcontainer-constants.sh

# Security integrity check (cannot be skipped by child images)
if [ -f /usr/local/bin/verify-integrity.sh ]; then
    INTEGRITY_MODE="${INTEGRITY_MODE:-warn}" /usr/local/bin/verify-integrity.sh
fi

# Per-developer isolation
if [ -f /usr/local/bin/setup-developer-identity.sh ]; then
    /usr/local/bin/setup-developer-identity.sh
fi

# Start health endpoint in background
if [ -f /usr/local/bin/health-endpoint.sh ]; then
    /usr/local/bin/health-endpoint.sh &
    disown -a 2>/dev/null || true
fi

echo "============================================"
echo "  Headless mode — no IDE server"
echo "  Claude Code ready in terminal"
echo "============================================"
