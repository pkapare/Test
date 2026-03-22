# TIER 3 — Project: Sentinel CDM
# Inherits: lob-dotnet (org-base + .NET 10 SDK + LOB config)
# Adds:     Project-specific CLAUDE.md, MCP servers, slash commands
FROM kapconreg.azurecr.io/devcontainers/lob-dotnet:latest

USER root

# Verify parent image security files have not been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

# ============================================================
# Project Claude config
# ============================================================
COPY claude-config/ /tmp/project-claude/

# Append project CLAUDE.md
RUN echo "" >> /home/node/.claude/CLAUDE.md \
    && echo "---" >> /home/node/.claude/CLAUDE.md \
    && echo "" >> /home/node/.claude/CLAUDE.md \
    && cat /tmp/project-claude/CLAUDE.md >> /home/node/.claude/CLAUDE.md

# Copy MCP server config (project tier owns this)
RUN if [ -f /tmp/project-claude/claude.json ]; then /usr/local/bin/merge-mcp.sh; fi

# Copy project slash commands (additive)
RUN cp -n /tmp/project-claude/commands/*.md /home/node/.claude/commands/ 2>/dev/null || true

# Cleanup
RUN rm -rf /tmp/project-claude

# Ensure node owns everything — COPY resets to root
RUN chown -R node:node /home/node/.claude /home/node/.claude.json

USER node
WORKDIR /workspace
