#!/usr/bin/env bash
# Build, tag, and push the Tier 1 headless (CLI-only) image.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-image.sh"
build_image "org-base-headless" "$SCRIPT_DIR"
