#!/usr/bin/env bash
# Build, tag, and push the Tier 1 code-server image.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR/../../scripts/build-image.sh"
build_image "org-base-vscode-codeserver" "$SCRIPT_DIR"
