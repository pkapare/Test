# IDE VARIANT: code-server (Coder — fully open source browser IDE)
# Image size: ~388MB on top of core
# Marketplace: Open VSX
# Auth: Password (default: claude-dev)
# Port: 8228
# License: MIT
FROM kapconreg.azurecr.io/devcontainers/org-base-core:latest

ARG CODE_SERVER_VERSION=4.100.3

USER root

# Verify parent image security files haven't been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

# ============================================================
# code-server (Coder)
# ============================================================
RUN curl -fsSL https://code-server.dev/install.sh | sh -s -- --version=${CODE_SERVER_VERSION}

# ============================================================
# code-server config (isolated from VS Code Server)
# ============================================================
RUN mkdir -p /home/node/.config/code-server \
             /home/node/.code-server-data \
             /home/node/.code-server-extensions \
    && cat > /home/node/.config/code-server/config.yaml << 'EOF'
bind-addr: 0.0.0.0:8228
auth: password
password: claude-dev
cert: false
disable-telemetry: true
disable-update-check: true
EOF
ARG CODE_SERVER_PASSWORD=claude-dev
RUN sed -i "s/password: claude-dev/password: ${CODE_SERVER_PASSWORD}/" /home/node/.config/code-server/config.yaml
RUN chown -R node:node /home/node/.config /home/node/.code-server-data /home/node/.code-server-extensions

# ============================================================
# Extra firewall domains for code-server
# ============================================================
RUN cat > /usr/local/bin/firewall-extra-domains.sh << 'EOF'
# code-server uses Open VSX for extensions
EXTRA_DOMAINS=(
    "open-vsx.org"
    "coder.com"
)
EOF

# ============================================================
# Startup script
# ============================================================
COPY start-code-server.sh /usr/local/bin/start-code-server.sh
RUN chmod +x /usr/local/bin/start-code-server.sh

EXPOSE 8228 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -sf http://127.0.0.1:8228 > /dev/null 2>&1 || exit 1

USER node
WORKDIR /workspace
CMD ["bash", "-c", "/usr/local/bin/verify-integrity.sh && /usr/local/bin/setup-developer-identity.sh && /usr/local/bin/start-code-server.sh && /usr/local/bin/health-endpoint.sh & sleep infinity"]
