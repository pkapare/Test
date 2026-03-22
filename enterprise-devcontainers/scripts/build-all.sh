#!/usr/bin/env bash
# =============================================================================
# Build all images top to bottom in dependency order.
#
# Usage:
#   ./scripts/build-all.sh                                           # Build all (universal)
#   ./scripts/build-all.sh kapconreg.azurecr.io/devcontainers all    # All IDE variants
#   SKIP_PUSH=1 SKIP_SCAN=1 ./scripts/build-all.sh                  # Local only
#   TAG=v1.2.3 ./scripts/build-all.sh                                # Custom tag
#   SMOKE_TEST=1 ./scripts/build-all.sh                              # With smoke tests
#
# Arguments:
#   $1 — Registry prefix (default: kapconreg.azurecr.io/devcontainers)
#   $2 — IDE variant: universal|serveweb|codeserver|jetbrains|headless|all
#        (default: universal)
#
# Environment:
#   SKIP_PUSH  — "1" to skip registry push
#   SKIP_SCAN  — "1" to skip Trivy scan
#   SMOKE_TEST — "1" to run smoke tests after each tier
#   TAG        — Custom tag (default: YYYYMMDD-<sha>)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

export REGISTRY="${1:-${REGISTRY:-kapconreg.azurecr.io/devcontainers}}"
VARIANT="${2:-universal}"

source "$SCRIPT_DIR/build-image.sh"

echo ""
echo "=========================================="
echo "  Building All Images (Top to Bottom)"
echo "  Registry:   $REGISTRY"
echo "  Tag:        $TAG"
echo "  Variant:    $VARIANT"
echo "  Skip Push:  ${SKIP_PUSH:-0}"
echo "  Skip Scan:  ${SKIP_SCAN:-0}"
echo "  Smoke Test: ${SMOKE_TEST:-0}"
echo "=========================================="
START=$(date +%s)

# ─── Authenticate with ACR (skip if not pushing) ────────────────────────────
if [ "$SKIP_PUSH" != "1" ]; then
    echo ""
    echo "--- Authenticating with ACR ---"
    az acr login --name "${ACR_NAME:-kapconreg}" || { echo "ACR login failed"; exit 1; }
fi

# ─── Tier 0 — Core ──────────────────────────────────────────────────────────
echo ""
echo "══════════════ TIER 0 — Core ══════════════"
build_image "org-base-core" "$ROOT_DIR/org/org-base-core"
smoke_test  "org-base-core" "claude --version && git --version && jq --version && rg --version"

# ─── Tier 1 — IDE Variants ──────────────────────────────────────────────────
echo ""
echo "══════════════ TIER 1 — IDE Variants ══════════════"
case "$VARIANT" in
    all)
        build_image "org-base-universal"         "$ROOT_DIR/org/org-base-universal"
        build_image "org-base-vscode-serveweb"   "$ROOT_DIR/org/org-base-vscode-serveweb"
        build_image "org-base-vscode-codeserver"  "$ROOT_DIR/org/org-base-vscode-codeserver"
        build_image "org-base-jetbrains"         "$ROOT_DIR/org/org-base-jetbrains"
        build_image "org-base-headless"          "$ROOT_DIR/org/org-base-headless"
        smoke_test  "org-base-universal"         "claude --version && code --version && which sshd"
        smoke_test  "org-base-headless"          "claude --version"
        ;;
    universal)
        build_image "org-base-universal" "$ROOT_DIR/org/org-base-universal"
        smoke_test  "org-base-universal" "claude --version && code --version && which sshd"
        ;;
    serveweb)
        build_image "org-base-vscode-serveweb" "$ROOT_DIR/org/org-base-vscode-serveweb"
        smoke_test  "org-base-vscode-serveweb" "claude --version && code --version"
        ;;
    codeserver)
        build_image "org-base-vscode-codeserver" "$ROOT_DIR/org/org-base-vscode-codeserver"
        smoke_test  "org-base-vscode-codeserver" "claude --version && which code-server"
        ;;
    jetbrains)
        build_image "org-base-jetbrains" "$ROOT_DIR/org/org-base-jetbrains"
        smoke_test  "org-base-jetbrains" "claude --version && which sshd"
        ;;
    headless)
        build_image "org-base-headless" "$ROOT_DIR/org/org-base-headless"
        smoke_test  "org-base-headless" "claude --version"
        ;;
    *)
        echo "Unknown variant: $VARIANT"
        echo "Valid: universal, serveweb, codeserver, jetbrains, headless, all"
        exit 1
        ;;
esac

# ─── Tier 2 — LOB / Stack ──────────────────────────────────────────────────
echo ""
echo "══════════════ TIER 2 — LOB / Stack ══════════════"
build_image "lob-dotnet" "$ROOT_DIR/lob-dotnet"
build_image "lob-nodejs" "$ROOT_DIR/lob-nodejs"
smoke_test  "lob-dotnet" "claude --version && dotnet --version && dotnet tool list -g"
smoke_test  "lob-nodejs" "claude --version && node --version && pnpm --version"

# ─── Tier 3 — Projects ──────────────────────────────────────────────────────
echo ""
echo "══════════════ TIER 3 — Projects ══════════════"
build_image "project-one"   "$ROOT_DIR/projects/project-one"
build_image "project-two"   "$ROOT_DIR/projects/project-two"
build_image "project-three" "$ROOT_DIR/projects/project-three"

smoke_test "project-one" \
    "claude --version && dotnet --version && cat ~/.claude/CLAUDE.md | head -5 && ls ~/.claude/commands/ && test -f ~/.claude.json && echo 'MCP config exists'"
smoke_test "project-two" \
    "claude --version && dotnet --version && cat ~/.claude/CLAUDE.md | head -5 && ls ~/.claude/commands/ && test -f ~/.claude.json && echo 'MCP config exists'"
smoke_test "project-three" \
    "claude --version && dotnet --version && cat ~/.claude/CLAUDE.md | head -5 && ls ~/.claude/commands/ && test -f ~/.claude.json && echo 'MCP config exists'"

# ─── Summary ─────────────────────────────────────────────────────────────────
ELAPSED=$(( $(date +%s) - START ))
echo ""
echo "=========================================="
echo "  All images built successfully!"
echo "  Total time: ${ELAPSED}s"
echo "=========================================="
print_summary
