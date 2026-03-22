#!/usr/bin/env bash
# =============================================================================
# Shared image build helper — called by per-directory build.sh scripts
# and scripts/build-all.sh.
#
# Usage (from a per-directory build.sh):
#   source "$(dirname "$0")/../scripts/build-image.sh"
#   build_image "org-base-core" "."
#
# Environment:
#   REGISTRY   — Container registry prefix (default: kapconreg.azurecr.io/devcontainers)
#   SKIP_PUSH  — Set to "1" to skip pushing to registry
#   SKIP_SCAN  — Set to "1" to skip Trivy scan
#   SMOKE_TEST — Set to "1" to enable smoke tests
#   TAG        — Custom tag (default: auto-generated YYYYMMDD-<sha>)
# =============================================================================
set -euo pipefail

# Load centralized constants (don't override env vars already set by caller)
_CONSTANTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../config/constants.env"
if [ -f "$_CONSTANTS" ]; then
    while IFS='=' read -r key value; do
        [[ "$key" =~ ^#.*$ || -z "$key" ]] && continue
        value="${value%%#*}"  # strip inline comments
        value="$(echo "$value" | xargs)"  # trim whitespace
        [ -z "${!key:-}" ] && export "$key=$value"
    done < "$_CONSTANTS"
fi

REGISTRY="${REGISTRY:-kapconreg.azurecr.io/devcontainers}"
SKIP_PUSH="${SKIP_PUSH:-0}"
SKIP_SCAN="${SKIP_SCAN:-0}"
SMOKE_TEST="${SMOKE_TEST:-0}"

# Track built images for summary
BUILT_IMAGES=()

# Auto-generate tag if not set
if [ -z "${TAG:-}" ]; then
    GIT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    DATE_TAG=$(date +%Y%m%d)
    TAG="${DATE_TAG}-${GIT_SHA}"
fi

build_image() {
    local NAME="$1"
    local CONTEXT="${2:-.}"
    local IMAGE_LATEST="$REGISTRY/$NAME:latest"
    local IMAGE_TAGGED="$REGISTRY/$NAME:$TAG"
    local START_TIME=$(date +%s)

    echo ""
    echo "========================================="
    echo "  Building: $NAME"
    echo "  Tags:     latest + $TAG"
    echo "  Context:  $CONTEXT"
    echo "========================================="

    docker build -t "$IMAGE_LATEST" -t "$IMAGE_TAGGED" "$CONTEXT"

    local ELAPSED=$(( $(date +%s) - START_TIME ))
    echo "    Built in ${ELAPSED}s"

    # Trivy scan
    if [ "$SKIP_SCAN" != "1" ]; then
        echo "--- Scanning $NAME ---"
        docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
            aquasec/trivy:latest image --exit-code 1 --severity CRITICAL "$IMAGE_LATEST" || \
            echo "[WARN] Trivy found CRITICAL vulnerabilities"
    fi

    # Push
    if [ "$SKIP_PUSH" != "1" ]; then
        echo "--- Pushing $NAME ---"
        docker push "$IMAGE_LATEST"
        docker push "$IMAGE_TAGGED"
    fi

    echo "--- Done: $NAME ($TAG) in ${ELAPSED}s ---"
    BUILT_IMAGES+=("$REGISTRY/$NAME:$TAG")
}

smoke_test() {
    local NAME="$1"
    local COMMANDS="$2"

    if [ "$SMOKE_TEST" != "1" ]; then return 0; fi

    echo "--- Smoke testing $NAME ---"
    local IMAGE="$REGISTRY/$NAME:latest"
    if docker run --rm "$IMAGE" bash -c "$COMMANDS"; then
        echo "[PASS] Smoke test passed: $NAME"
    else
        echo "[FAIL] Smoke test failed: $NAME"
        return 1
    fi
}

print_summary() {
    echo ""
    echo "Built images (tagged: latest + $TAG):"
    for img in "${BUILT_IMAGES[@]}"; do
        echo "  $img"
    done
    echo ""
    if [ "$SKIP_PUSH" = "1" ]; then
        echo "  [INFO] Push skipped (unset SKIP_PUSH to push)"
    fi
    if [ "$SKIP_SCAN" = "1" ]; then
        echo "  [INFO] Trivy scan skipped (unset SKIP_SCAN to scan)"
    fi
    if [ "$SMOKE_TEST" != "1" ]; then
        echo "  [INFO] Smoke tests skipped (set SMOKE_TEST=1 to enable)"
    fi
    echo ""
}
