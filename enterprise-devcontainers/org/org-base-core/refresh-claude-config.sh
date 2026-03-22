#!/usr/bin/env bash
# =============================================================================
# Refresh Claude Code config from baked backup.
#
# When ~/.claude is mounted as a Docker volume, the volume retains OLD contents
# after image updates. This script copies fresh config from the baked backup
# (created during docker build) into the volume.
#
# Safe to run repeatedly — only overwrites config files, preserves runtime data.
#
# Usage: Called from devcontainer.json postStartCommand:
#   /usr/local/bin/refresh-claude-config.sh
# =============================================================================
set -euo pipefail

BAKED="/home/node/.claude-baked"
LIVE="/home/node/.claude"

if [ ! -d "$BAKED" ]; then
    echo "[refresh-config] No baked config found — skipping"
    exit 0
fi

echo "[refresh-config] Refreshing Claude Code config from baked image..."

# Refresh CLAUDE.md (always overwrite — baked version is authoritative)
cp "$BAKED/CLAUDE.md" "$LIVE/CLAUDE.md" 2>/dev/null || true

# Refresh settings.json (always overwrite — merged permissions are authoritative)
cp "$BAKED/settings.json" "$LIVE/settings.json" 2>/dev/null || true

# Refresh commands (copy new ones, overwrite existing)
cp "$BAKED/commands/"*.md "$LIVE/commands/" 2>/dev/null || true

# Ensure runtime directories exist
mkdir -p "$LIVE/debug" "$LIVE/statsig" "$LIVE/projects" "$LIVE/agents" "$LIVE/todo"

# Fix ownership (may already be owned by node; tolerate failure)
chown -R node:node "$LIVE" 2>/dev/null || true

echo "[refresh-config] Config refreshed from image"
