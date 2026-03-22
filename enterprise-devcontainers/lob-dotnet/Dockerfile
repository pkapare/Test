# TIER 2 — LOB .NET
# Inherits: Tier 1 IDE variant (firewall, serve-web/SSH, Claude Code, ZSH, managed-settings)
# Adds:     .NET 10 SDK, EF Core tools, LOB CLAUDE.md + permissions
FROM kapconreg.azurecr.io/devcontainers/org-base-universal:latest

USER root

# Verify parent image security files haven't been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

# ============================================================
# .NET 10 SDK
# ============================================================
ARG DOTNET_CHANNEL=10.0
RUN curl -fsSL https://dot.net/v1/dotnet-install.sh -o /tmp/dotnet-install.sh \
    && chmod +x /tmp/dotnet-install.sh \
    && /tmp/dotnet-install.sh --channel ${DOTNET_CHANNEL} --install-dir /usr/share/dotnet \
    && ln -sf /usr/share/dotnet/dotnet /usr/local/bin/dotnet \
    && rm /tmp/dotnet-install.sh

ENV DOTNET_ROOT=/usr/share/dotnet
ENV PATH="${PATH}:/usr/share/dotnet:/home/node/.dotnet/tools"
ENV DOTNET_CLI_TELEMETRY_OPTOUT=1
ENV DOTNET_NOLOGO=1

# EF Core tools (installed as node user)
USER node
RUN dotnet tool install --global dotnet-ef
USER root

# ============================================================
# Merge LOB Claude config with org config
# Config merge rules:
#   CLAUDE.md    → concatenate (org + LOB appended)
#   settings.json → arrays merged via jq (permissions combined + deduped)
#   commands/    → additive (LOB commands added alongside org commands)
# ============================================================
COPY claude-config/ /tmp/lob-claude/

# Append LOB CLAUDE.md to org CLAUDE.md
RUN echo "" >> /home/node/.claude/CLAUDE.md \
    && echo "---" >> /home/node/.claude/CLAUDE.md \
    && echo "" >> /home/node/.claude/CLAUDE.md \
    && cat /tmp/lob-claude/CLAUDE.md >> /home/node/.claude/CLAUDE.md

# Merge settings.json (combine permission arrays, LOB overrides scalars)
COPY merge-settings.sh /tmp/merge-settings.sh
RUN apt-get update && apt-get install -y --no-install-recommends jq && rm -rf /var/lib/apt/lists/* \
    && chmod +x /tmp/merge-settings.sh && /tmp/merge-settings.sh && rm /tmp/merge-settings.sh

# Copy LOB slash commands (additive — doesn't remove org commands)
RUN cp -n /tmp/lob-claude/commands/*.md /home/node/.claude/commands/ 2>/dev/null || true

# Append NuGet domains to firewall allowlist (required for dotnet restore)
RUN cat >> /usr/local/bin/firewall-extra-domains.sh << 'EOF'

# NuGet domains (added by lob-dotnet)
EXTRA_DOMAINS+=(
    "nuget.org"
    "api.nuget.org"
    "azuresearch-usnc.nuget.org"
    "az635243.vo.msecnd.net"
)
EOF

# MCP server configuration (LOB baseline)
COPY merge-mcp.sh /usr/local/bin/merge-mcp.sh
RUN chmod +x /usr/local/bin/merge-mcp.sh
COPY claude-config/claude.json /home/node/.claude.json

# Cleanup
RUN rm -rf /tmp/lob-claude

RUN chown -R node:node /home/node/.claude /home/node/.claude.json

USER node
WORKDIR /workspace
