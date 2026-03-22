# =============================================================================
# Enterprise DevContainers — Centralized Constants (PowerShell)
#
# Single source of truth for all configurable values.
# Dot-source this file: . .\config\constants.ps1
#
# Must stay in sync with config/constants.env
# =============================================================================

# ─── Registry ────────────────────────────────────────────────────────────────
$script:REGISTRY        = "kapconreg.azurecr.io/devcontainers"
$script:ACR_NAME        = "kapconreg"

# ─── Base Image ──────────────────────────────────────────────────────────────
$script:BASE_IMAGE      = "node:20-slim"

# ─── Tool Versions ──────────────────────────────────────────────────────────
$script:GIT_DELTA_VERSION    = "0.18.2"
$script:RIPGREP_VERSION      = "14.1.1"
$script:LAZYGIT_VERSION      = "0.44.1"
$script:CODE_SERVER_VERSION  = "4.100.3"
$script:DOTNET_CHANNEL       = "10.0"

# ─── Ports ───────────────────────────────────────────────────────────────────
$script:PORT_SERVE_WEB     = 8229
$script:PORT_CODE_SERVER   = 8228
$script:PORT_SSH           = 2222
$script:PORT_HEALTH           = 8080

# ─── Security ────────────────────────────────────────────────────────────────
$script:SSH_PASSWORD           = "claude-dev"
$script:SSH_PASSWORD_RANDOMIZE = "true"
$script:CODE_SERVER_PASSWORD   = "claude-dev"
$script:FIREWALL_PROFILE       = "strict"
$script:FIREWALL_REFRESH_CRON = "0 */4 * * *"

# ─── Container Resources ────────────────────────────────────────────────────
$script:TMPFS_TMP_SIZE    = "256m"
$script:TMPFS_RUN_SIZE    = "64m"
$script:NODE_MAX_OLD_SPACE = 4096

# ─── Docker Compose Host Port Mappings ───────────────────────────────────────
$script:HOST_PORT_SERVEWEB_WEB    = 8301
$script:HOST_PORT_CODESERVER_WEB  = 8302
$script:HOST_PORT_JETBRAINS_SSH   = 2201
$script:HOST_PORT_UNIVERSAL_WEB   = 8304
$script:HOST_PORT_UNIVERSAL_SSH   = 2204
$script:HOST_PORT_LOB_DOTNET_WEB  = 8305
$script:HOST_PORT_LOB_DOTNET_SSH  = 2205
$script:HOST_PORT_LOB_NODEJS_WEB  = 8306
$script:HOST_PORT_LOB_NODEJS_SSH  = 2206
$script:HOST_PORT_PROJECT_ONE_WEB    = 8311
$script:HOST_PORT_PROJECT_ONE_SSH    = 2211
$script:HOST_PORT_PROJECT_TWO_WEB    = 8312
$script:HOST_PORT_PROJECT_TWO_SSH    = 2212
$script:HOST_PORT_PROJECT_THREE_WEB  = 8313
$script:HOST_PORT_PROJECT_THREE_SSH  = 2213

# ─── CI/CD ───────────────────────────────────────────────────────────────────
$script:CI_PLATFORMS = "linux/amd64,linux/arm64"
