#!/usr/bin/env bash
# Build, tag, and push the Tier 0 core image.
# Usage: ./build.sh
#   REGISTRY=myregistry.io/devcontainers SKIP_PUSH=1 ./build.sh
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-image.sh"
build_image "org-base-core" "$SCRIPT_DIR"
