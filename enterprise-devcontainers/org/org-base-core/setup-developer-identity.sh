#!/usr/bin/env bash
# =============================================================================
# Per-Developer Isolation — unique credentials per container instance.
#
# Instead of the shared default password "claude-dev", this script:
#   1. Generates a random SSH password at container start
#   2. Sets it for the node user
#   3. Records developer identity for audit correlation
#   4. Imports SSH public key if provided via env var
#
# Environment variables:
#   DEV_NAME      — Developer's name (e.g., "Jane Smith")
#   DEV_EMAIL     — Developer's email (e.g., "jane@company.com")
#   DEV_SSH_KEY   — SSH public key to authorize (optional, e.g., "ssh-rsa AAAA...")
#   SSH_PASSWORD  — Explicit password override (if set, skip random generation)
#
# Called from: startup scripts (start-universal.sh, etc.)
# =============================================================================
set -euo pipefail

IDENTITY_FILE="/home/node/.developer-identity.json"
PASSWORD_FILE="/tmp/.ssh-password"

# ─── Generate or use explicit password ───────────────────────────────────────
if [ "${SSH_PASSWORD_RANDOMIZE:-true}" = "true" ] && { [ "${SSH_PASSWORD:-}" = "claude-dev" ] || [ -z "${SSH_PASSWORD:-}" ]; }; then
    # Generate a 16-char random password
    GENERATED_PASSWORD=$(head -c 64 /dev/urandom | base64 | tr -dc 'a-zA-Z0-9' | head -c 16)
    if [ ${#GENERATED_PASSWORD} -lt 16 ]; then
        echo "[identity] WARNING: Short random output, using fallback"
        GENERATED_PASSWORD=$(date +%s%N | sha256sum | head -c 16)
    fi
    echo "$GENERATED_PASSWORD" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"

    # Set the new password (requires sudo)
    echo "node:${GENERATED_PASSWORD}" | sudo chpasswd 2>/dev/null || true

    # Update the runtime constant so startup banners show the real password
    export SSH_PASSWORD="$GENERATED_PASSWORD"
else
    # Using explicit password from env/constants — no change needed
    echo "${SSH_PASSWORD:-claude-dev}" > "$PASSWORD_FILE"
    chmod 600 "$PASSWORD_FILE"
fi

# ─── Import SSH public key if provided ───────────────────────────────────────
if [ -n "${DEV_SSH_KEY:-}" ]; then
    mkdir -p /home/node/.ssh
    echo "$DEV_SSH_KEY" > /home/node/.ssh/authorized_keys
    chmod 600 /home/node/.ssh/authorized_keys
    chown node:node /home/node/.ssh/authorized_keys 2>/dev/null || true
    echo "[identity] SSH public key imported for ${DEV_EMAIL:-unknown}"
fi

# ─── Record developer identity ──────────────────────────────────────────────
TIMESTAMP=$(date -Iseconds)
jq -n \
  --arg name "${DEV_NAME:-anonymous}" \
  --arg email "${DEV_EMAIL:-unknown}" \
  --arg ts "$TIMESTAMP" \
  --arg cid "$(hostname)" \
  --argjson ssh_key "$([ -n "${DEV_SSH_KEY:-}" ] && echo true || echo false)" \
  --argjson pw_rand "$([ "${SSH_PASSWORD_RANDOMIZE:-true}" = "true" ] && echo true || echo false)" \
  '{developer: {name: $name, email: $email, timestamp: $ts, container_id: $cid, ssh_key_provided: $ssh_key, password_randomized: $pw_rand}}' \
  > "$IDENTITY_FILE"
chown node:node "$IDENTITY_FILE" 2>/dev/null || true

echo "[identity] Developer: ${DEV_NAME:-anonymous} <${DEV_EMAIL:-unknown}>"
echo "[identity] Container: $(hostname)"
echo "[identity] Password saved to $PASSWORD_FILE (visible in startup banner)"
