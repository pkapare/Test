#!/usr/bin/env bash
# Build, tag, and push the Tier 1 VS Code serve-web image.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-image.sh"
build_image "org-base-vscode-serveweb" "$SCRIPT_DIR"
