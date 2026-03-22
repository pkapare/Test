# TIER 3 — Project: OpenClaw Enterprise
# Inherits: lob-dotnet (org-base + .NET 10 SDK + LOB config)
# Adds:     Project-specific CLAUDE.md, MCP servers, slash commands
FROM kapconreg.azurecr.io/devcontainers/lob-dotnet:latest

USER root

# Verify parent image security files have not been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

COPY claude-config/ /tmp/project-claude/

RUN echo "" >> /home/node/.claude/CLAUDE.md \
    && echo "---" >> /home/node/.claude/CLAUDE.md \
    && echo "" >> /home/node/.claude/CLAUDE.md \
    && cat /tmp/project-claude/CLAUDE.md >> /home/node/.claude/CLAUDE.md

RUN if [ -f /tmp/project-claude/claude.json ]; then /usr/local/bin/merge-mcp.sh; fi
RUN cp -n /tmp/project-claude/commands/*.md /home/node/.claude/commands/ 2>/dev/null || true

RUN rm -rf /tmp/project-claude
RUN chown -R node:node /home/node/.claude /home/node/.claude.json

USER node
WORKDIR /workspace
