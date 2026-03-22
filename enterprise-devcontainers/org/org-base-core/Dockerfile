ARG BASE_IMAGE=node:20-slim
FROM ${BASE_IMAGE}

LABEL org.opencontainers.image.title="Claude Code DevContainer — Core (no IDE)"
LABEL org.opencontainers.image.description="Firewall, Claude Code, ZSH, config baking. IDE variants layer on top."

# ============================================================
# System packages
# ============================================================
RUN apt-get update && apt-get install -y --no-install-recommends \
    sudo curl wget git zsh vim nano jq fzf \
    dnsutils iptables ipset iproute2 aggregate \
    procps net-tools locales \
    unzip gnupg2 man-db \
    && rm -rf /var/lib/apt/lists/*

# GitHub CLI
RUN curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    > /etc/apt/sources.list.d/github-cli.list \
    && apt-get update && apt-get install -y --no-install-recommends gh \
    && rm -rf /var/lib/apt/lists/*

# Git Delta (better diffs) — multi-arch aware
ARG GIT_DELTA_VERSION=0.18.2
ARG TARGETARCH
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -fsSL "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" \
    -o /tmp/git-delta.deb \
    && dpkg -i /tmp/git-delta.deb \
    && rm /tmp/git-delta.deb

# ripgrep (fast recursive search — used by Claude Code) — multi-arch aware
ARG RIPGREP_VERSION=14.1.1
RUN ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "amd64") \
    && curl -fsSL "https://github.com/BurntSushi/ripgrep/releases/download/${RIPGREP_VERSION}/ripgrep_${RIPGREP_VERSION}-1_${ARCH}.deb" \
    -o /tmp/ripgrep.deb \
    && dpkg -i /tmp/ripgrep.deb \
    && rm /tmp/ripgrep.deb

# lazygit (terminal UI for git) — multi-arch aware
ARG LAZYGIT_VERSION=0.44.1
RUN LG_ARCH=$([ "$TARGETARCH" = "arm64" ] && echo "arm64" || echo "x86_64") \
    && curl -fsSL "https://github.com/jesseduffield/lazygit/releases/download/v${LAZYGIT_VERSION}/lazygit_${LAZYGIT_VERSION}_Linux_${LG_ARCH}.tar.gz" \
    | tar xz -C /usr/local/bin lazygit

# detect-secrets (pre-commit secret scanning)
RUN apt-get update && apt-get install -y --no-install-recommends python3-pip \
    && pip3 install --no-cache-dir --break-system-packages detect-secrets \
    && rm -rf /var/lib/apt/lists/*

# Locale
RUN sed -i '/en_US.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=en_US.UTF-8 LANGUAGE=en_US:en LC_ALL=en_US.UTF-8

# ============================================================
# Claude Code
# ============================================================
RUN curl -fsSL https://cli.anthropic.com/install.sh | sh

# ============================================================
# ZSH + Oh My Zsh
# ============================================================
USER node
RUN sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended \
    && git clone --depth=1 https://github.com/romkatv/powerlevel10k.git /home/node/.oh-my-zsh/custom/themes/powerlevel10k \
    && git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions /home/node/.oh-my-zsh/custom/plugins/zsh-autosuggestions \
    && git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting /home/node/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting
USER root

# ============================================================
# Shell configuration
# ============================================================
RUN cat > /home/node/.zshrc << 'ZSHRC'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"
POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true
plugins=(git zsh-autosuggestions zsh-syntax-highlighting fzf)
source $ZSH/oh-my-zsh.sh
HISTFILE=/commandhistory/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt appendhistory sharehistory
export PATH="/usr/local/share/npm-global/bin:$PATH"
ZSHRC

RUN SNIPPET="export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
    && mkdir -p /commandhistory \
    && touch /commandhistory/.bash_history /commandhistory/.zsh_history \
    && chown -R node:node /commandhistory \
    && echo "$SNIPPET" >> /home/node/.bashrc

RUN chsh -s /usr/bin/zsh node

ENV SHELL=/bin/zsh EDITOR=nano VISUAL=nano DEVCONTAINER=true

# ============================================================
# Firewall script (shared across all IDE variants)
# ============================================================
# ============================================================
# Runtime constants (sourced by startup scripts at runtime)
# ============================================================
COPY devcontainer-constants.sh /usr/local/bin/devcontainer-constants.sh
RUN chmod +x /usr/local/bin/devcontainer-constants.sh

COPY firewall-domains.sh /usr/local/bin/firewall-domains.sh
COPY init-firewall.sh /usr/local/bin/init-firewall.sh
RUN chmod +x /usr/local/bin/init-firewall.sh /usr/local/bin/firewall-domains.sh

# ============================================================
# MANAGED SETTINGS (highest precedence — CANNOT be overridden)
# ============================================================
RUN mkdir -p /etc/claude-code
COPY managed-settings.json /etc/claude-code/managed-settings.json

# ============================================================
# Claude Code user configuration
# Pre-create ALL runtime directories to prevent ENOENT crashes.
# ============================================================
RUN mkdir -p /home/node/.claude/commands \
             /home/node/.claude/debug \
             /home/node/.claude/statsig \
             /home/node/.claude/projects \
             /home/node/.claude/agents \
             /home/node/.claude/todo

COPY claude-config/CLAUDE.md /home/node/.claude/CLAUDE.md
COPY claude-config/settings.json /home/node/.claude/settings.json
COPY claude-config/commands/ /home/node/.claude/commands/

# Backup baked config for volume freshness (postStartCommand can refresh stale volumes)
RUN cp -r /home/node/.claude /home/node/.claude-baked

# MUST be last operation on ~/.claude — COPY resets ownership to root
RUN chown -R node:node /home/node/.claude /home/node/.claude-baked

# ============================================================
# Git global config — detect-secrets pre-commit hook
# ============================================================
RUN mkdir -p /home/node/.git-templates/hooks
COPY git-hooks/pre-commit /home/node/.git-templates/hooks/pre-commit
RUN chmod +x /home/node/.git-templates/hooks/pre-commit \
    && chown -R node:node /home/node/.git-templates
USER node
RUN git config --global init.templateDir /home/node/.git-templates \
    && git config --global core.pager delta \
    && git config --global interactive.diffFilter "delta --color-only" \
    && git config --global delta.navigate true \
    && git config --global delta.side-by-side true \
    && git config --global merge.conflictstyle diff3 \
    && git config --global diff.colorMoved default
USER root

# ============================================================
# Per-developer isolation + Health dashboard
# ============================================================
COPY setup-developer-identity.sh /usr/local/bin/setup-developer-identity.sh
COPY health-endpoint.sh /usr/local/bin/health-endpoint.sh
RUN chmod +x /usr/local/bin/setup-developer-identity.sh /usr/local/bin/health-endpoint.sh

# ============================================================
# Firewall domain refresh (periodic DNS re-resolution)
# ============================================================
COPY refresh-firewall.sh /usr/local/bin/refresh-firewall.sh
COPY refresh-claude-config.sh /usr/local/bin/refresh-claude-config.sh
RUN chmod +x /usr/local/bin/refresh-firewall.sh /usr/local/bin/refresh-claude-config.sh

# Install socat for health endpoint HTTP server + netcat as fallback
# Cron job for periodic firewall refresh (every 4 hours)
RUN apt-get update && apt-get install -y --no-install-recommends cron socat netcat-openbsd \
    && rm -rf /var/lib/apt/lists/* \
    && echo "0 */4 * * * root /usr/local/bin/refresh-firewall.sh" > /etc/cron.d/firewall-refresh \
    && chmod 0644 /etc/cron.d/firewall-refresh

# ============================================================
# Sudoers — firewall only
# ============================================================
RUN echo "node ALL=(ALL) NOPASSWD: /usr/local/bin/init-firewall.sh, /usr/local/bin/refresh-firewall.sh, /usr/sbin/chpasswd" > /etc/sudoers.d/node-firewall \
    && chmod 0440 /etc/sudoers.d/node-firewall

# Health dashboard port (overridden by IDE variants with additional ports)
EXPOSE 8080

# Default healthcheck — overridden by IDE variant Dockerfiles
HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD claude --version > /dev/null 2>&1 || exit 1

# ============================================================
# Docker secrets support — load ANTHROPIC_API_KEY from secret
# ============================================================
RUN cat > /usr/local/bin/load-secrets.sh << 'SECRETS'
#!/usr/bin/env bash
# Load API key from Docker secret if available (avoids exposing in env/process list)
if [ -f /run/secrets/anthropic_api_key ]; then
    export ANTHROPIC_API_KEY=$(cat /run/secrets/anthropic_api_key)
fi
# Load GitHub token from Docker secret if available
if [ -f /run/secrets/github_token ]; then
    export GITHUB_TOKEN=$(cat /run/secrets/github_token)
fi
SECRETS
RUN chmod +x /usr/local/bin/load-secrets.sh

# Source secrets in shell profiles
RUN echo 'source /usr/local/bin/load-secrets.sh' >> /home/node/.zshrc \
    && echo 'source /usr/local/bin/load-secrets.sh' >> /home/node/.bashrc \
    && chown node:node /home/node/.zshrc /home/node/.bashrc

# ============================================================
# Security integrity verification
# Generate checksums of critical files LAST (after all configs are baked).
# Child images that tamper with these files will be detected at startup.
# ============================================================
COPY generate-integrity-checksums.sh /usr/local/bin/generate-integrity-checksums.sh
COPY verify-integrity.sh /usr/local/bin/verify-integrity.sh
COPY assert-parent-integrity.sh /usr/local/bin/assert-parent-integrity.sh
RUN chmod +x /usr/local/bin/generate-integrity-checksums.sh \
             /usr/local/bin/verify-integrity.sh \
             /usr/local/bin/assert-parent-integrity.sh
RUN /usr/local/bin/generate-integrity-checksums.sh \
    && rm /usr/local/bin/generate-integrity-checksums.sh

USER node
WORKDIR /workspace
CMD ["zsh"]
