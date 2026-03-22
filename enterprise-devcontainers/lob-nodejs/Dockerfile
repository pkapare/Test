# TIER 2 — LOB Node.js
# Inherits: Tier 1 IDE variant (firewall, serve-web/SSH, Claude Code, ZSH, managed-settings)
# Adds:     pnpm, Playwright, Vitest, LOB CLAUDE.md + permissions
FROM kapconreg.azurecr.io/devcontainers/org-base-universal:latest

USER root

# Verify parent image security files haven't been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

# ============================================================
# pnpm
# ============================================================
RUN corepack enable && corepack prepare pnpm@latest --activate

# ============================================================
# Merge LOB Claude config with org config
# ============================================================
COPY claude-config/ /tmp/lob-claude/

# Append LOB CLAUDE.md to org CLAUDE.md
RUN echo "" >> /home/node/.claude/CLAUDE.md \
    && echo "---" >> /home/node/.claude/CLAUDE.md \
    && echo "" >> /home/node/.claude/CLAUDE.md \
    && cat /tmp/lob-claude/CLAUDE.md >> /home/node/.claude/CLAUDE.md

# Merge settings.json
COPY merge-settings.sh /tmp/merge-settings.sh
RUN apt-get update && apt-get install -y --no-install-recommends jq && rm -rf /var/lib/apt/lists/* \
    && chmod +x /tmp/merge-settings.sh && /tmp/merge-settings.sh && rm /tmp/merge-settings.sh

# Copy LOB slash commands
RUN cp -n /tmp/lob-claude/commands/*.md /home/node/.claude/commands/ 2>/dev/null || true

# MCP server configuration (LOB baseline)
COPY merge-mcp.sh /usr/local/bin/merge-mcp.sh
RUN chmod +x /usr/local/bin/merge-mcp.sh
COPY claude-config/claude.json /home/node/.claude.json

# Cleanup
RUN rm -rf /tmp/lob-claude

RUN chown -R node:node /home/node/.claude /home/node/.claude.json

USER node
WORKDIR /workspace
