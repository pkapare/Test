# IDE VARIANT: Headless (no IDE — CLI only)
# Use cases: CI/CD pipelines, Claude Code automation, terminal-only devs
# No extra ports, no browser IDE, minimal overhead
FROM kapconreg.azurecr.io/devcontainers/org-base-core:latest

USER root

# Verify parent image security files haven't been tampered with
RUN /usr/local/bin/assert-parent-integrity.sh

# ============================================================
# No IDE-specific domains needed
# ============================================================
# No firewall-extra-domains.sh — core domains are sufficient

# ============================================================
# Startup script (firewall only, no IDE)
# ============================================================
COPY start-headless.sh /usr/local/bin/start-headless.sh
RUN chmod +x /usr/local/bin/start-headless.sh

EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD claude --version > /dev/null 2>&1 || exit 1

USER node
WORKDIR /workspace
CMD ["bash", "-c", "/usr/local/bin/start-headless.sh && sleep infinity"]
