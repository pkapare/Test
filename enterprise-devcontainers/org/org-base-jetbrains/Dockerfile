# IDE VARIANT: JetBrains (SSH-based remote development)
# Supports: IntelliJ IDEA, Rider, WebStorm, PyCharm, GoLand, etc.
# Connection: JetBrains Gateway → SSH → container
# Port: 2222 (SSH)
# Auth: Key-based (mount authorized_keys) or password
FROM kapconreg.azurecr.io/devcontainers/org-base-core:latest

ARG PORT_SSH=2222

USER root

# Verify parent image security files haven't been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

# ============================================================
# OpenSSH Server
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

# Generate host keys
RUN ssh-keygen -A

# Set default password for node user (override via build ARG or mount authorized_keys)
ARG SSH_PASSWORD=claude-dev
RUN echo "node:${SSH_PASSWORD}" | chpasswd

# Prepare authorized_keys location
RUN mkdir -p /home/node/.ssh \
    && touch /home/node/.ssh/authorized_keys \
    && chmod 700 /home/node/.ssh \
    && chmod 600 /home/node/.ssh/authorized_keys \
    && chown -R node:node /home/node/.ssh

# ============================================================
# JetBrains-specific environment
# JetBrains Gateway expects certain paths and capabilities
# ============================================================
RUN mkdir -p /home/node/.cache/JetBrains \
    && chown -R node:node /home/node/.cache

# ============================================================
# Extra firewall domains for JetBrains
# ============================================================
RUN cat > /usr/local/bin/firewall-extra-domains.sh << 'EOF'
# JetBrains Gateway downloads IDE backends and plugins
EXTRA_DOMAINS=(
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
# Startup script
# ============================================================
COPY start-ssh.sh /usr/local/bin/start-ssh.sh
RUN chmod +x /usr/local/bin/start-ssh.sh

# Sudoers — allow node to start sshd (separate file to avoid modifying checksummed node-firewall)
RUN echo "node ALL=(ALL) NOPASSWD: /usr/sbin/sshd" > /etc/sudoers.d/node-ssh \
    && chmod 0440 /etc/sudoers.d/node-ssh

EXPOSE ${PORT_SSH} 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD ss -tlnp | grep -q ':2222' || exit 1

USER node
WORKDIR /workspace
CMD ["bash", "-c", "/usr/local/bin/verify-integrity.sh && /usr/local/bin/setup-developer-identity.sh && /usr/local/bin/start-ssh.sh && /usr/local/bin/health-endpoint.sh & sleep infinity"]
