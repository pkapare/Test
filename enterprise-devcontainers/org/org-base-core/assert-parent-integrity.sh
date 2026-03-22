#!/usr/bin/env bash
# =============================================================================
# Assert parent image integrity — called during child image builds.
#
# LOB and project Dockerfiles should call this early in their build
# to verify the parent image's security files haven't been tampered with
# by intermediate layers.
#
# Usage (in child Dockerfile):
#   RUN /usr/local/bin/assert-parent-integrity.sh
#
# This script runs the same checksum verification as verify-integrity.sh
# but in ENFORCE mode — it will FAIL THE BUILD if any critical file
# has been modified.
# =============================================================================
set -euo pipefail

CHECKSUM_FILE="/etc/claude-code/integrity-checksums.sha256"

if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "[INTEGRITY] FAIL: No checksums found — parent image is not a valid org-base-core image"
    exit 1
fi

echo "[INTEGRITY] Verifying parent image security files..."
FAILURES=0

while IFS=' ' read -r expected_hash filepath; do
    [ -z "$expected_hash" ] && continue
    filepath=$(echo "$filepath" | sed 's/^ *//')

    if [ ! -f "$filepath" ]; then
        echo "[INTEGRITY] FAIL: $filepath — MISSING"
        FAILURES=$((FAILURES + 1))
    else
        actual_hash=$(sha256sum "$filepath" | awk '{print $1}')
        if [ "$actual_hash" != "$expected_hash" ]; then
            echo "[INTEGRITY] FAIL: $filepath — MODIFIED"
            FAILURES=$((FAILURES + 1))
        fi
    fi
done < "$CHECKSUM_FILE"

if [ "$FAILURES" -gt 0 ]; then
    echo "[INTEGRITY] BUILD BLOCKED: $FAILURES critical security file(s) have been tampered with."
    echo "[INTEGRITY] Restore the original org-base-core image or contact the platform team."
    exit 1
fi

echo "[INTEGRITY] All critical files verified — parent image is intact."
