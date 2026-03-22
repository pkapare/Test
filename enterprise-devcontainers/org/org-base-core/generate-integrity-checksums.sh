#!/usr/bin/env bash
# =============================================================================
# Generate SHA256 checksums of critical security files.
# Called during core image build — bakes checksums into /etc/claude-code/.
# Runtime verification script checks these at container startup.
# =============================================================================
set -euo pipefail

CHECKSUM_FILE="/etc/claude-code/integrity-checksums.sha256"

# Critical files that child images MUST NOT modify
CRITICAL_FILES=(
    "/etc/claude-code/managed-settings.json"
    "/usr/local/bin/init-firewall.sh"
    "/usr/local/bin/firewall-domains.sh"
    "/usr/local/bin/refresh-firewall.sh"
    "/usr/local/bin/load-secrets.sh"
    "/usr/local/bin/devcontainer-constants.sh"
    "/etc/sudoers.d/node-firewall"
    "/home/node/.git-templates/hooks/pre-commit"
    "/usr/local/bin/verify-integrity.sh"
    "/usr/local/bin/assert-parent-integrity.sh"
    "/usr/local/bin/setup-developer-identity.sh"
    "/usr/local/bin/health-endpoint.sh"
)

echo "Generating integrity checksums..."
: > "$CHECKSUM_FILE"

MISSING=0
for f in "${CRITICAL_FILES[@]}"; do
    if [ -f "$f" ]; then
        sha256sum "$f" >> "$CHECKSUM_FILE"
        echo "  [OK] $f"
    else
        echo "  [FAIL] $f (critical file missing!)"
        MISSING=$((MISSING + 1))
    fi
done

if [ "$MISSING" -gt 0 ]; then
    echo "FATAL: $MISSING critical file(s) missing during checksum generation."
    exit 1
fi

# Lock the checksum file — owned by root, read-only
chmod 444 "$CHECKSUM_FILE"
echo "Checksums saved to $CHECKSUM_FILE"
