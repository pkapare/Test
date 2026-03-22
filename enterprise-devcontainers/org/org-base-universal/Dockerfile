# IDE VARIANT: Universal (SSH + serve-web)
# Supports: VS Code Desktop, VS Code Browser, JetBrains Gateway,
#           Cursor, Windsurf, Zed, Neovim, any SSH-capable IDE
# Ports: 8229 (serve-web browser IDE) + 2222 (SSH)
FROM kapconreg.azurecr.io/devcontainers/org-base-core:latest

ARG PORT_SSH=2222
ARG PORT_SERVE_WEB=8229

USER root

# Verify parent image security files haven't been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

# ============================================================
# VS Code CLI (for serve-web browser access)
# ============================================================
ARG TARGETARCH
RUN VSCODE_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "cli-alpine-arm64" || echo "cli-alpine-x64") \
    && curl -Lk "https://code.visualstudio.com/sha/download?build=stable&os=${VSCODE_ARCH}" \
    -o /tmp/vscode-cli.tar.gz \
    && tar -xzf /tmp/vscode-cli.tar.gz -C /usr/local/bin \
    && rm /tmp/vscode-cli.tar.gz \
    && chmod +x /usr/local/bin/code

# serve-web data directory (isolated from VS Code Desktop)
RUN mkdir -p /home/node/.vscode-serve-web \
    && chown -R node:node /home/node/.vscode-serve-web

# ============================================================
# Pre-install commonly used VS Code extensions (cached in image)
# ============================================================
RUN mkdir -p /home/node/.vscode-serve-web/extensions \
    && code serve-web --install-extension anthropic.claude-code \
       --extensions-dir /home/node/.vscode-serve-web/extensions \
       --accept-server-license-terms 2>/dev/null || true

# ============================================================
# OpenSSH Server (for JetBrains / Zed / any SSH IDE)
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# SSH configuration
RUN mkdir -p /var/run/sshd \
    && sed -i "s/#Port 22/Port ${PORT_SSH}/" /etc/ssh/sshd_config \
    && sed -i 's/#PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config \
    && sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config \
    && sed -i 's/#AllowTcpForwarding.*/AllowTcpForwarding yes/' /etc/ssh/sshd_config \
    && sed -i 's/#GatewayPorts.*/GatewayPorts no/' /etc/ssh/sshd_config \
    && sed -i 's/#X11Forwarding.*/X11Forwarding no/' /etc/ssh/sshd_config \
    && echo "AllowUsers node" >> /etc/ssh/sshd_config

RUN ssh-keygen -A
ARG SSH_PASSWORD=claude-dev
RUN echo "node:${SSH_PASSWORD}" | chpasswd

RUN mkdir -p /home/node/.ssh \
    && touch /home/node/.ssh/authorized_keys \
    && chmod 700 /home/node/.ssh \
    && chmod 600 /home/node/.ssh/authorized_keys \
    && chown -R node:node /home/node/.ssh

# JetBrains cache directory
RUN mkdir -p /home/node/.cache/JetBrains \
    && chown -R node:node /home/node/.cache

# ============================================================
# Extra firewall domains (serve-web + JetBrains combined)
# ============================================================
RUN cat > /usr/local/bin/firewall-extra-domains.sh << 'EOF'
EXTRA_DOMAINS=(
    "vscode.download.prss.microsoft.com"
    "default.exp-tas.com"
    "download.jetbrains.com"
    "download-cdn.jetbrains.com"
    "plugins.jetbrains.com"
    "cache-redirector.jetbrains.com"
    "data.services.jetbrains.com"
    "jb.gg"
    "resources.jetbrains.com"
    "account.jetbrains.com"
)
EOF

# ============================================================
# Startup scripts
# ============================================================
COPY start-serve-web.sh /usr/local/bin/start-serve-web.sh
COPY start-ssh.sh /usr/local/bin/start-ssh.sh
COPY start-universal.sh /usr/local/bin/start-universal.sh
RUN chmod +x /usr/local/bin/start-serve-web.sh \
             /usr/local/bin/start-ssh.sh \
             /usr/local/bin/start-universal.sh

# Sudoers — allow node to start sshd (separate file to avoid modifying checksummed node-firewall)
RUN echo "node ALL=(ALL) NOPASSWD: /usr/sbin/sshd" > /etc/sudoers.d/node-ssh \
    && chmod 0440 /etc/sudoers.d/node-ssh

EXPOSE ${PORT_SERVE_WEB} ${PORT_SSH} 8080

# Healthy if EITHER serve-web OR SSH is running (supports single-IDE usage)
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -sf http://127.0.0.1:8229 > /dev/null 2>&1 || ss -tlnp | grep -q ':2222' || exit 1

USER node
WORKDIR /workspace
CMD ["bash", "-c", "/usr/local/bin/start-universal.sh && sleep infinity"]
