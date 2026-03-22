#!/usr/bin/env bash
# =============================================================================
# Start SSH server for JetBrains Gateway / any SSH-based IDE.
#
# JetBrains Gateway connects via SSH, then downloads and starts the
# appropriate IDE backend (IntelliJ, Rider, WebStorm, etc.) inside
# the container automatically.
#
# Connection from host:
#   JetBrains Gateway → New Connection → SSH
#   Host: localhost  Port: 2222  User: node  Password: claude-dev
#
# Or with key-based auth:
#   Mount authorized_keys into the container:
#   "source=${localEnv:USERPROFILE}/.ssh/id_rsa.pub,target=/home/node/.ssh/authorized_keys,type=bind,readonly"
# =============================================================================
set -euo pipefail

# Load Docker secrets if available
[ -f /usr/local/bin/load-secrets.sh ] && source /usr/local/bin/load-secrets.sh

# Load runtime constants
[ -f /usr/local/bin/devcontainer-constants.sh ] && source /usr/local/bin/devcontainer-constants.sh

# Pick up randomized password if it was generated
[ -f /tmp/.ssh-password ] && SSH_PASSWORD=$(cat /tmp/.ssh-password)

echo "============================================"
echo "  Starting SSH server..."
echo "============================================"

# Start sshd (needs sudo)
sudo /usr/sbin/sshd -D -p ${PORT_SSH} &
disown -a 2>/dev/null || true

# Wait for sshd to bind
MAX_RETRIES=10
for i in $(seq 1 $MAX_RETRIES); do
    if ss -tlnp | grep -q ":${PORT_SSH}"; then
        echo "  SSH server is ready!"
        echo ""
        echo "  ┌──────────────────────────────────────────────┐"
        echo "  │  SSH:       ssh node@localhost -p ${PORT_SSH}        │"
        echo "  │  Password:  ${SSH_PASSWORD}                        │"
        echo "  │                                               │"
        echo "  │  JetBrains Gateway:                           │"
        echo "  │    Host: localhost  Port: ${PORT_SSH}  User: node    │"
        echo "  │                                               │"
        echo "  │  For key auth, mount your public key:         │"
        echo "  │    target=/home/node/.ssh/authorized_keys     │"
        echo "  └──────────────────────────────────────────────┘"
        echo ""
        echo "============================================"
        exit 0
    fi
    sleep 1
done

echo "  [ERROR] SSH server failed to start"
echo "============================================"
exit 1
