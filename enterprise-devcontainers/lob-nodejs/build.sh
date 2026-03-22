#!/usr/bin/env bash
# Build, tag, and push the Tier 2 Node.js team image.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../scripts/build-image.sh"
build_image "lob-nodejs" "$SCRIPT_DIR"
