#!/usr/bin/env bash
# =============================================================================
# Periodic firewall domain refresh — re-resolves DNS for allowed domains.
# Runs via cron every 4 hours to handle CDN IP rotation.
#
# Usage: Called automatically via cron, or manually:
#   sudo /usr/local/bin/refresh-firewall.sh
# =============================================================================
set -euo pipefail

LOG_FILE="/tmp/firewall-refresh.log"

# Load persisted firewall profile from init
[ -f /etc/firewall-profile.env ] && source /etc/firewall-profile.env

echo "[$(date -Iseconds)] Refreshing firewall domains..." >> "$LOG_FILE"

# -------------------------------------------------------
# Load shared domain list (single source of truth with init-firewall.sh)
# -------------------------------------------------------
# shellcheck source=/dev/null
source /usr/local/bin/firewall-domains.sh

# Load IDE-specific extra domains (if variant provides them)
EXTRA_DOMAINS=()
if [ -f /usr/local/bin/firewall-extra-domains.sh ]; then
    # shellcheck source=/dev/null
    source /usr/local/bin/firewall-extra-domains.sh
fi

ALL_DOMAINS=("${CORE_DOMAINS[@]}" "${EXTRA_DOMAINS[@]}")

# Add relaxed-mode domains if applicable
FIREWALL_PROFILE="${FIREWALL_PROFILE:-strict}"
if [ "$FIREWALL_PROFILE" = "relaxed" ]; then
    ALL_DOMAINS+=("${RELAXED_DOMAINS[@]}")
fi

# -------------------------------------------------------
# Re-resolve and update ipset (create fresh set, then swap)
# -------------------------------------------------------
ipset create allowed-domains-new hash:net -exist
ipset flush allowed-domains-new

ADDED=0
for domain in "${ALL_DOMAINS[@]}"; do
    ips=$(dig +noall +answer +short +time=2 +tries=1 A "$domain" 2>/dev/null | grep -E '^[0-9]+\.' || true)
    for ip in $ips; do
        ipset add allowed-domains-new "$ip" -exist 2>/dev/null && ADDED=$((ADDED + 1))
    done
done

# -------------------------------------------------------
# Refresh GitHub CIDRs
# -------------------------------------------------------
CIDR_REGEX='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'
gh_meta=$(curl -sf --max-time 10 https://api.github.com/meta 2>/dev/null || echo "")
if [ -n "$gh_meta" ]; then
    cidrs=$(echo "$gh_meta" | jq -r '(.web // [])[], (.api // [])[], (.git // [])[]' 2>/dev/null)
    if [ -n "$cidrs" ]; then
        aggregated=$(echo "$cidrs" | aggregate -q 2>/dev/null || echo "$cidrs")
        while read -r cidr; do
            if [[ "$cidr" =~ $CIDR_REGEX ]]; then
                ipset add allowed-domains-new "$cidr" -exist 2>/dev/null && ADDED=$((ADDED + 1)) || true
            fi
        done <<< "$aggregated"
    fi
fi

# Only swap if we resolved a reasonable number of IPs
# (the core domain list alone should produce 10+ IPs)
if [ "$ADDED" -lt 5 ]; then
    echo "[$(date -Iseconds)] ABORT: Only $ADDED IPs resolved — keeping existing ipset (DNS may be down)" >> "$LOG_FILE"
    ipset destroy allowed-domains-new 2>/dev/null || true
    exit 0
fi

# Atomic swap: replace old set with new (no traffic interruption)
ipset swap allowed-domains-new allowed-domains 2>/dev/null || true
ipset destroy allowed-domains-new 2>/dev/null || true

echo "[$(date -Iseconds)] Refresh complete — $ADDED IPs added/updated" >> "$LOG_FILE"
