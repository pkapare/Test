#!/usr/bin/env bash
# =============================================================================
# Health Dashboard — lightweight HTTP endpoint returning JSON service status.
#
# Listens on PORT_HEALTH (default: 8080) and responds to any HTTP request
# with a JSON payload describing the status of all container services.
#
# Usage:
#   /usr/local/bin/health-endpoint.sh &          # Start in background
#   curl -s http://localhost:8080/health | jq .   # Query from host
#
# Suitable for Kubernetes liveness/readiness probes:
#   livenessProbe:
#     httpGet:
#       path: /health
#       port: 8080
# =============================================================================
set -euo pipefail

PORT_HEALTH="${PORT_HEALTH:-8080}"

# Load constants for port references
[ -f /usr/local/bin/devcontainer-constants.sh ] && source /usr/local/bin/devcontainer-constants.sh

check_service() {
    local name="$1"
    local check_cmd="$2"
    if eval "$check_cmd" > /dev/null 2>&1; then
        echo "\"$name\": {\"status\": \"up\"}"
    else
        echo "\"$name\": {\"status\": \"down\"}"
    fi
}

generate_health_json() {
    local services=()
    local overall="healthy"

    # Check serve-web (VS Code browser IDE)
    if ss -tlnp 2>/dev/null | grep -q ":${PORT_SERVE_WEB:-8229}"; then
        services+=("\"serve_web\": {\"status\": \"up\", \"port\": ${PORT_SERVE_WEB:-8229}}")
    else
        services+=("\"serve_web\": {\"status\": \"down\", \"port\": ${PORT_SERVE_WEB:-8229}}")
    fi

    # Check SSH
    if ss -tlnp 2>/dev/null | grep -q ":${PORT_SSH:-2222}"; then
        services+=("\"ssh\": {\"status\": \"up\", \"port\": ${PORT_SSH:-2222}}")
    else
        services+=("\"ssh\": {\"status\": \"down\", \"port\": ${PORT_SSH:-2222}}")
    fi

    # Check code-server (if applicable)
    if ss -tlnp 2>/dev/null | grep -q ":${PORT_CODE_SERVER:-8228}"; then
        services+=("\"code_server\": {\"status\": \"up\", \"port\": ${PORT_CODE_SERVER:-8228}}")
    fi

    # Check Claude Code CLI (timeout prevents health loop hang)
    if command -v claude &>/dev/null && timeout 5 claude --version &>/dev/null; then
        local claude_ver=$(timeout 5 claude --version 2>/dev/null | head -1)
        services+=("\"claude_code\": {\"status\": \"up\", \"version\": \"${claude_ver}\"}")
    else
        services+=("\"claude_code\": {\"status\": \"down\"}")
        overall="degraded"
    fi

    # Check firewall (look for marker from init-firewall.sh)
    if [ -f /tmp/.firewall-active ]; then
        local fw_entries=$(cat /tmp/.firewall-entry-count 2>/dev/null || echo 0)
        services+=("\"firewall\": {\"status\": \"active\", \"policy\": \"default-deny\", \"allowed_entries\": ${fw_entries}}")
    else
        services+=("\"firewall\": {\"status\": \"inactive\"}")
        overall="degraded"
    fi

    # Check MCP servers config
    if [ -f /home/node/.claude.json ]; then
        local mcp_count=$(jq '.mcpServers | length' /home/node/.claude.json 2>/dev/null || echo 0)
        services+=("\"mcp_servers\": {\"status\": \"configured\", \"count\": ${mcp_count}}")
    else
        services+=("\"mcp_servers\": {\"status\": \"none\"}")
    fi

    # Check audit log
    if [ -f /home/node/.claude/audit.log ]; then
        local audit_lines=$(wc -l < /home/node/.claude/audit.log 2>/dev/null || echo 0)
        services+=("\"audit_log\": {\"status\": \"active\", \"entries\": ${audit_lines}}")
    else
        services+=("\"audit_log\": {\"status\": \"empty\"}")
    fi

    # Check integrity
    if [ -f /etc/claude-code/integrity-checksums.sha256 ]; then
        services+=("\"integrity\": {\"status\": \"checksums_present\"}")
    else
        services+=("\"integrity\": {\"status\": \"no_checksums\"}")
        overall="degraded"
    fi

    # Developer identity
    if [ -f /home/node/.developer-identity.json ]; then
        local dev_name=$(jq -r '.developer.name' /home/node/.developer-identity.json 2>/dev/null || echo "unknown")
        local dev_email=$(jq -r '.developer.email' /home/node/.developer-identity.json 2>/dev/null || echo "unknown")
        services+=("\"developer\": {\"name\": \"${dev_name}\", \"email\": \"${dev_email}\"}")
    fi

    # Build JSON response
    local timestamp=$(date -Iseconds)
    local hostname=$(hostname)
    local uptime_secs=$(awk '{print int($1)}' /proc/uptime 2>/dev/null || echo 0)

    echo "{"
    echo "  \"status\": \"${overall}\","
    echo "  \"timestamp\": \"${timestamp}\","
    echo "  \"hostname\": \"${hostname}\","
    echo "  \"uptime_seconds\": ${uptime_secs},"
    echo "  \"services\": {"

    local IFS_BAK="$IFS"
    local count=${#services[@]}
    for i in "${!services[@]}"; do
        if [ "$i" -lt $((count - 1)) ]; then
            echo "    ${services[$i]},"
        else
            echo "    ${services[$i]}"
        fi
    done

    echo "  }"
    echo "}"
}

# ─── HTTP Server — generates fresh health data per request ───────────────────
echo "[health] Starting health endpoint on port ${PORT_HEALTH}..."

# HTTP server — generates fresh health data per request
while true; do
    BODY=$(generate_health_json)
    {
        echo -e "HTTP/1.1 200 OK\r"
        echo -e "Content-Type: application/json\r"
        echo -e "Connection: close\r"
        echo -e "Content-Length: ${#BODY}\r"
        echo -e "\r"
        printf '%s' "$BODY"
    } | socat - TCP-LISTEN:${PORT_HEALTH},reuseaddr 2>/dev/null || \
    {
        echo -e "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\nContent-Length: ${#BODY}\r\n\r\n${BODY}" | \
        nc -l -p ${PORT_HEALTH} -q 1 2>/dev/null
    } || sleep 1
done
