#!/usr/bin/env bash
# =============================================================================
# Egress firewall — default-deny outbound, allowlisted domains only.
#
# This is the CORE firewall with shared domains. IDE variants append their
# own domains via /usr/local/bin/firewall-extra-domains.sh (if it exists).
#
# Fix for Windows/Docker Desktop: all ipset add commands use -exist
# to handle duplicate IPs from DNS (GitHub issue #15611).
# =============================================================================
set -euo pipefail

echo "============================================"
echo "  Initializing egress firewall..."
echo "============================================"

# -------------------------------------------------------
# Firewall profile support (strict = production, relaxed = development)
# Usage: FIREWALL_PROFILE=relaxed sudo /usr/local/bin/init-firewall.sh
# -------------------------------------------------------
FIREWALL_PROFILE="${FIREWALL_PROFILE:-strict}"
echo "  Profile: $FIREWALL_PROFILE"

# Load shared domain list (single source of truth)
# shellcheck source=/dev/null
source /usr/local/bin/firewall-domains.sh

if [ "$FIREWALL_PROFILE" = "relaxed" ]; then
    echo "  Relaxed mode: adding documentation + package registry domains"
fi

# -------------------------------------------------------
# Preserve Docker DNS rules before flushing
# -------------------------------------------------------
echo "  Preserving Docker DNS rules..."
DOCKER_DNS_RULES=$(iptables-save | grep -E "DOCKER|docker|172\.(1[6-9]|2[0-9]|3[0-1])\." || true)

# -------------------------------------------------------
# Flush existing rules for clean slate
# -------------------------------------------------------
iptables -F OUTPUT 2>/dev/null || true

# Restore Docker DNS rules
if [ -n "$DOCKER_DNS_RULES" ]; then
    echo "$DOCKER_DNS_RULES" | iptables-restore --noflush 2>/dev/null || true
    echo "  Docker DNS rules restored"
fi

# -------------------------------------------------------
# Create ipset for allowed IPs
# -------------------------------------------------------
ipset create allowed-domains hash:net -exist
ipset flush allowed-domains

# -------------------------------------------------------
# Allow loopback + established connections
# -------------------------------------------------------
iptables -A OUTPUT -o lo -j ACCEPT
iptables -A OUTPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# -------------------------------------------------------
# Allow DNS
# -------------------------------------------------------
iptables -A OUTPUT -p udp --dport 53 -j ACCEPT
iptables -A OUTPUT -p tcp --dport 53 -j ACCEPT

# -------------------------------------------------------
# Allow SSH (port 22)
# -------------------------------------------------------
# SSH restricted to allowlisted IPs only (GitHub, etc.) — not open to all hosts
iptables -A OUTPUT -p tcp --dport 22 -m set --match-set allowed-domains dst -j ACCEPT

# -------------------------------------------------------
# Allow host network subnet (Docker bridge)
# -------------------------------------------------------
HOST_SUBNET=$(ip route | grep 'default' | awk '{print $3}' | head -1)
if [ -n "$HOST_SUBNET" ]; then
    HOST_CIDR=$(ip route | grep -v default | grep "$(echo "$HOST_SUBNET" | cut -d. -f1-3)" | awk '{print $1}' | head -1)
    if [ -n "$HOST_CIDR" ]; then
        iptables -A OUTPUT -d "$HOST_CIDR" -j ACCEPT
        echo "  Allowed host subnet: $HOST_CIDR"
    fi
fi

# -------------------------------------------------------
# Core domains loaded from /usr/local/bin/firewall-domains.sh
# -------------------------------------------------------

# -------------------------------------------------------
# Load IDE-specific extra domains (if the variant provides them)
# -------------------------------------------------------
EXTRA_DOMAINS=()
if [ -f /usr/local/bin/firewall-extra-domains.sh ]; then
    echo "  Loading IDE-specific domains..."
    # shellcheck source=/dev/null
    source /usr/local/bin/firewall-extra-domains.sh
fi

# Combine all domains
ALL_DOMAINS=("${CORE_DOMAINS[@]}" "${EXTRA_DOMAINS[@]}")

# Add relaxed-mode domains if applicable
if [ "$FIREWALL_PROFILE" = "relaxed" ]; then
    ALL_DOMAINS+=("${RELAXED_DOMAINS[@]}")
fi

# -------------------------------------------------------
# Resolve and allow each domain
# -------------------------------------------------------
for domain in "${ALL_DOMAINS[@]}"; do
    echo "  Resolving $domain..."

    ips=$(dig +noall +answer +time=2 +tries=1 A "$domain" 2>/dev/null | awk '$4 == "A" {print $5}')
    if [ -z "$ips" ]; then
        echo "    [WARN] No A records for $domain — skipping"
        continue
    fi

    for ip in $ips; do
        ipset add allowed-domains "$ip" -exist
        echo "    Added $ip"
    done
done

# -------------------------------------------------------
# GitHub CIDR ranges (full ranges via aggregate)
# -------------------------------------------------------
echo "  Fetching GitHub CIDR ranges..."
CIDR_REGEX='^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/[0-9]+$'
gh_meta=$(curl -sf --max-time 10 https://api.github.com/meta 2>/dev/null || echo "")
if [ -n "$gh_meta" ]; then
    cidrs=$(echo "$gh_meta" | jq -r '(.web // [])[], (.api // [])[], (.git // [])[]' 2>/dev/null)
    if [ -n "$cidrs" ]; then
        aggregated=$(echo "$cidrs" | aggregate -q 2>/dev/null || echo "$cidrs")
        while read -r cidr; do
            if [[ "$cidr" =~ $CIDR_REGEX ]]; then
                ipset add allowed-domains "$cidr" -exist 2>/dev/null || true
            fi
        done <<< "$aggregated"
        echo "    GitHub CIDRs added"
    fi
else
    echo "    [WARN] Could not fetch GitHub meta — GitHub CIDRs not added"
fi

# -------------------------------------------------------
# Apply the allowlist and set default-deny on all OUTPUT
# -------------------------------------------------------
iptables -A OUTPUT -m set --match-set allowed-domains dst -j ACCEPT
iptables -P OUTPUT DROP

echo ""
echo "  Firewall active"
echo "  Default: DENY all outbound"
echo "  Allowed: $(ipset list allowed-domains | tail -n +9 | wc -l) entries"

# Write marker for health endpoint (avoids needing iptables root access)
echo "$(ipset list allowed-domains | tail -n +9 | wc -l)" > /tmp/.firewall-entry-count
touch /tmp/.firewall-active

# -------------------------------------------------------
# Persist firewall profile for cron refresh
# -------------------------------------------------------
echo "FIREWALL_PROFILE=$FIREWALL_PROFILE" > /etc/firewall-profile.env

# -------------------------------------------------------
# Start cron daemon for periodic DNS refresh
# -------------------------------------------------------
if command -v cron &> /dev/null; then
    service cron start 2>/dev/null || cron 2>/dev/null || true
    echo "  Cron daemon started (DNS refresh every 4h)"
fi

echo "============================================"

# -------------------------------------------------------
# Validation tests
# -------------------------------------------------------
echo ""
echo "  Running validation..."

# Test 1: Blocked domain should fail
if curl -sf --max-time 5 https://example.com > /dev/null 2>&1; then
    echo "    [FAIL] example.com should be blocked but is reachable"
else
    echo "    [PASS] example.com is blocked"
fi

# Test 2: Allowed domain should succeed
if curl -sf --max-time 5 https://api.github.com > /dev/null 2>&1; then
    echo "    [PASS] api.github.com is reachable"
else
    echo "    [WARN] api.github.com is not reachable — check DNS or network"
fi

echo "============================================"
