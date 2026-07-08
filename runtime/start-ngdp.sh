#!/usr/bin/env bash
# start-ngdp.sh — the UNPRIVILEGED half. Run AFTER setup-client-connect.sh.
# Starts three host-side services:
#   1. DNS server  (:53)  — resolves *.fstorm.cc -> DRAENOR_SERVER_IP
#   2. NGDP HTTP   (:80)  — serves versions/cdns for the Firestorm client
#   3. socat       (:87)  — forwards bnet login port -> authserver :1119
# All bind to 0.0.0.0 (or the Tailscale IP for DNS) so remote clients can reach them.
# Ctrl-C stops all three.
set -uo pipefail
NGDP=/var/home/blizz/Projects/draenor-dit/runtime/ngdp
SERVER_IP="${DRAENOR_SERVER_IP:-100.111.220.11}"

pkill -f "$NGDP/serve.py" 2>/dev/null || true
pkill -f "$NGDP/dns.py"   2>/dev/null || true
pkill -f "TCP-LISTEN:87"  2>/dev/null || true
sleep 1

DRAENOR_SERVER_IP="$SERVER_IP" DNS_BIND="$SERVER_IP" python3 "$NGDP/dns.py" > "$NGDP/dns.log" 2>&1 &
DNS_PID=$!
DRAENOR_SERVER_IP="$SERVER_IP" python3 "$NGDP/serve.py" > "$NGDP/http.log" 2>&1 &
HTTP_PID=$!
socat TCP-LISTEN:87,fork,reuseaddr,bind=0.0.0.0 TCP:127.0.0.1:1119 > "$NGDP/socat.log" 2>&1 &
SOCAT_PID=$!
sleep 1

echo "DNS :53 pid=$DNS_PID  |  NGDP HTTP :80 pid=$HTTP_PID  |  socat :87->1119 pid=$SOCAT_PID"
ss -lun | grep ":53 " || echo "WARN: DNS :53 not listening"
ss -ltn | grep -E ":80 |:87 " || echo "WARN: 80/87 not listening (did setup-client-connect.sh run?)"
echo "logs: $NGDP/dns.log  $NGDP/http.log  $NGDP/socat.log"
trap "kill $DNS_PID $HTTP_PID $SOCAT_PID 2>/dev/null" EXIT
wait
