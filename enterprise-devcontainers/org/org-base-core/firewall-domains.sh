#!/usr/bin/env bash
# =============================================================================
# Shared firewall domain list — sourced by both init-firewall.sh and
# refresh-firewall.sh. Single source of truth for allowed domains.
# =============================================================================

CORE_DOMAINS=(
    "registry.npmjs.org"
    "api.anthropic.com"
    "sentry.io"
    "statsig.anthropic.com"
    "statsig.com"
    "marketplace.visualstudio.com"
    "vscode.blob.core.windows.net"
    "update.code.visualstudio.com"
    "az764295.vo.msecnd.net"
    "dc.services.visualstudio.com"
    "github.com"
    "api.github.com"
    "objects.githubusercontent.com"
    "raw.githubusercontent.com"
)

RELAXED_DOMAINS=(
    "stackoverflow.com"
    "docs.microsoft.com"
    "learn.microsoft.com"
    "nuget.org"
    "api.nuget.org"
    "pypi.org"
    "files.pythonhosted.org"
)
