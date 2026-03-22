#!/usr/bin/env bash
# Build, tag, and push the Tier 3 Project Two image.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-image.sh"
build_image "project-two" "$SCRIPT_DIR"
