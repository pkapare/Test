# IDE VARIANT: VS Code serve-web (browser IDE via Microsoft VS Code CLI)
# Image size: ~45MB on top of core
# Marketplace: VS Code Marketplace (official)
# Auth: None (connection token disabled for local use)
# Port: 8229
FROM kapconreg.azurecr.io/devcontainers/org-base-core:latest

ARG PORT_SERVE_WEB=8229

USER root

# Verify parent image security files haven't been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

# ============================================================
# VS Code CLI (for serve-web)
# ============================================================
ARG TARGETARCH
RUN VSCODE_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "cli-alpine-arm64" || echo "cli-alpine-x64") \
    && curl -Lk "https://code.visualstudio.com/sha/download?build=stable&os=${VSCODE_ARCH}" \
    -o /tmp/vscode-cli.tar.gz \
    && tar -xzf /tmp/vscode-cli.tar.gz -C /usr/local/bin \
    && rm /tmp/vscode-cli.tar.gz \
    && chmod +x /usr/local/bin/code

# ============================================================
# serve-web data directory (isolated from VS Code Desktop)
# ============================================================
RUN mkdir -p /home/node/.vscode-serve-web \
    && chown -R node:node /home/node/.vscode-serve-web

# ============================================================
# Extra firewall domains for serve-web
# ============================================================
RUN cat > /usr/local/bin/firewall-extra-domains.sh << 'EOF'
# serve-web downloads the VS Code Server binary on first launch
EXTRA_DOMAINS=(
    "vscode.download.prss.microsoft.com"
    "default.exp-tas.com"
)
EOF

# ============================================================
# Startup script
# ============================================================
COPY start-serve-web.sh /usr/local/bin/start-serve-web.sh
RUN chmod +x /usr/local/bin/start-serve-web.sh

EXPOSE ${PORT_SERVE_WEB} 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -sf http://127.0.0.1:8229 > /dev/null 2>&1 || exit 1

USER node
WORKDIR /workspace
CMD ["bash", "-c", "/usr/local/bin/verify-integrity.sh && /usr/local/bin/setup-developer-identity.sh && /usr/local/bin/start-serve-web.sh && /usr/local/bin/health-endpoint.sh & sleep infinity"]
