#!/usr/bin/env bash
# start-ngdp.sh — the UNPRIVILEGED half. Run AFTER setup-client-connect.sh.
# Starts the local NGDP versions/cdns HTTP server (:80) and forwards the bnet
# login port :87 -> authserver :1119. Both on 127.0.0.1. Ctrl-C stops both.
set -uo pipefail
NGDP=/var/home/blizz/Projects/draenor-dit/runtime/ngdp

pkill -f "$NGDP/serve.py" 2>/dev/null || true
pkill -f "TCP-LISTEN:87" 2>/dev/null || true
sleep 1

python3 "$NGDP/serve.py" > "$NGDP/http.log" 2>&1 &
HTTP_PID=$!
socat TCP-LISTEN:87,fork,reuseaddr,bind=127.0.0.1 TCP:127.0.0.1:1119 > "$NGDP/socat.log" 2>&1 &
SOCAT_PID=$!
sleep 1

echo "NGDP HTTP :80 pid=$HTTP_PID  |  socat :87->1119 pid=$SOCAT_PID"
ss -ltn | grep -E ":80 |:87 " || echo "WARN: 80/87 not listening (did setup-client-connect.sh run?)"
echo "logs: $NGDP/http.log  $NGDP/socat.log"
trap "kill $HTTP_PID $SOCAT_PID 2>/dev/null" EXIT
wait
