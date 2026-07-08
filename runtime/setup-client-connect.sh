#!/usr/bin/env bash
# setup-client-connect.sh — the PRIVILEGED half of pointing the Firestorm WoD
# client at the local Draenor-Core server. Run once per boot: sudo bash <this>
#
# What it does (and why):
#  1. systemd-resolved drop-in: routes *.fstorm.cc DNS queries to the Draenor
#     DNS helper (runtime/ngdp/dns.py on port 53). This replaces the old
#     /etc/hosts approach.
#  2. Remove any old /etc/hosts fstorm entries (superseded by DNS).
#  3. Lower the unprivileged-port floor to 53 so the DNS server (:53), NGDP
#     HTTP (:80), and bnet port-forward (:87) can all bind as your normal user.
set -euo pipefail

SERVER_IP="${1:-${DRAENOR_SERVER_IP:-100.111.220.11}}"

# --- 1. systemd-resolved drop-in (persistent across reboots) ---
DROPIN_DIR="/etc/systemd/resolved.conf.d"
DROPIN_FILE="$DROPIN_DIR/draenor-fstorm.conf"
mkdir -p "$DROPIN_DIR"
cat > "$DROPIN_FILE" <<EOF
# draenor-dit: route *.fstorm.cc to the local DNS server.
# The DNS server (runtime/ngdp/dns.py) resolves fstorm.cc -> $SERVER_IP
# and forwards all other queries to 1.1.1.1.
[Resolve]
DNS=$SERVER_IP
Domains=~fstorm.cc
EOF
echo "resolved.conf.d: created $DROPIN_FILE (fstorm.cc -> $SERVER_IP)"

# Restart systemd-resolved to pick up the drop-in (safe to re-run).
systemctl restart systemd-resolved 2>/dev/null || true
echo "systemd-resolved restarted"

# --- 2. Remove old /etc/hosts fstorm entries (superseded by DNS) ---
sed -i '/# draenor-dit local WoD server/,$d' /etc/hosts 2>/dev/null || true
sed -i '/logon\.fstorm\.cc/d;/logon-cdn\.fstorm\.cc/d;/us-cdn\.fstorm\.cc/d;/eu-cdn\.fstorm\.cc/d' /etc/hosts 2>/dev/null || true
echo "/etc/hosts: removed old fstorm.cc entries (now handled by DNS)"

# --- 3. Lower port floor to 53 (per-boot; does NOT persist across reboot) ---
sysctl -w net.ipv4.ip_unprivileged_port_start=53
echo "port floor lowered to 53 (lets DNS:53, NGDP:80, socat:87 bind as your user)"
echo "DONE. Now start the stack with the same IP:"
echo "  DRAENOR_SERVER_IP=$SERVER_IP bash /var/home/blizz/Projects/draenor-dit/runtime/start-all.sh"
