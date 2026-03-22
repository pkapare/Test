#!/usr/bin/env bash
# =============================================================================
# Verify integrity of critical security files at container startup.
#
# Compares current file checksums against the ones baked during core image build.
# If ANY critical file has been modified, tampered, or removed by a child image,
# this script logs a CRITICAL warning and optionally blocks startup.
#
# Called from: postStartCommand in devcontainer.json, or startup scripts.
# Behavior:   INTEGRITY_MODE=enforce → exit 1 on failure (blocks startup)
#             INTEGRITY_MODE=warn    → log warning but continue (default)
# =============================================================================
set -euo pipefail

CHECKSUM_FILE="/etc/claude-code/integrity-checksums.sha256"
INTEGRITY_MODE="${INTEGRITY_MODE:-warn}"
LOG_FILE="/tmp/integrity-check.log"

echo "============================================"
echo "  Verifying security file integrity..."
echo "  Mode: ${INTEGRITY_MODE}"
echo "============================================"

if [ ! -f "$CHECKSUM_FILE" ]; then
    echo "  [WARN] No checksum file found — skipping integrity check"
    if [ "$INTEGRITY_MODE" = "enforce" ]; then
        echo "  MODE=enforce — blocking startup without integrity verification."
        exit 1
    fi
    echo "============================================"
    exit 0
fi

FAILURES=0
CHECKED=0
TIMESTAMP=$(date -Iseconds)

while IFS=' ' read -r expected_hash filepath; do
    # Skip empty lines
    [ -z "$expected_hash" ] && continue

    # Clean filepath (sha256sum outputs "  filename" with two spaces)
    filepath=$(echo "$filepath" | sed 's/^ *//')

    if [ ! -f "$filepath" ]; then
        echo "  [CRITICAL] MISSING: $filepath — file has been removed!"
        echo "[$TIMESTAMP] CRITICAL: MISSING $filepath" >> "$LOG_FILE"
        FAILURES=$((FAILURES + 1))
    else
        actual_hash=$(sha256sum "$filepath" | awk '{print $1}')
        if [ "$actual_hash" != "$expected_hash" ]; then
            echo "  [CRITICAL] MODIFIED: $filepath — checksum mismatch!"
            echo "    Expected: $expected_hash"
            echo "    Actual:   $actual_hash"
            echo "[$TIMESTAMP] CRITICAL: MODIFIED $filepath expected=$expected_hash actual=$actual_hash" >> "$LOG_FILE"
            FAILURES=$((FAILURES + 1))
        else
            echo "  [OK] $filepath"
        fi
    fi
    CHECKED=$((CHECKED + 1))
done < "$CHECKSUM_FILE"

echo ""
echo "  Checked: $CHECKED files"
echo "  Failures: $FAILURES"

if [ "$FAILURES" -gt 0 ]; then
    echo ""
    echo "  ┌─────────────────────────────────────────────────────┐"
    echo "  │  SECURITY ALERT: $FAILURES critical file(s) tampered!    │"
    echo "  │                                                       │"
    echo "  │  A child image has modified security configurations   │"
    echo "  │  baked into the org base image. This may indicate     │"
    echo "  │  an unauthorized bypass of security controls.         │"
    echo "  │                                                       │"
    echo "  │  Check: cat /tmp/integrity-check.log                  │"
    echo "  └─────────────────────────────────────────────────────┘"
    echo ""

    if [ "$INTEGRITY_MODE" = "enforce" ]; then
        echo "  MODE=enforce — blocking container startup."
        echo "============================================"
        exit 1
    else
        echo "  MODE=warn — continuing with degraded security."
        echo "============================================"
    fi
else
    echo "  All critical files verified — integrity OK"
    echo "============================================"
fi
