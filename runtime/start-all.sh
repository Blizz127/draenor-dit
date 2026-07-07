#!/usr/bin/env bash
# start-all.sh — bring the FULL Draenor stack up after a reboot.
#
# PREREQUISITE (host sudo, once per boot — /etc/hosts persists, port floor does not):
#     sudo bash /var/home/blizz/Projects/draenor-dit/runtime/setup-client-connect.sh
# Then run THIS script (no sudo needed; container sudo is passwordless):
#     bash /var/home/blizz/Projects/draenor-dit/runtime/start-all.sh
# Then launch the client:
#     bash /var/home/blizz/Projects/draenor-dit/runtime/launch-client-gamescope.sh
#
# Account: blizz@blizz127.com / xenon127   Character: Blizz (guid 1, GM lvl 3)
set -uo pipefail
BOX=draenor-devbox
SOCK=/run/mysqld-draenor/mysqld.sock
DATA=/var/lib/mysql-draenor
NGDP=/var/home/blizz/Projects/draenor-dit/runtime/ngdp

echo "## 1. MariaDB 3307 (container)"
if ! distrobox enter $BOX -- bash -lc "sudo mariadb --socket=$SOCK -e 'SELECT 1'" >/dev/null 2>&1; then
  distrobox enter $BOX -- setsid bash -c "sudo mariadbd --user=mysql --port=3307 --socket=$SOCK --datadir=$DATA --bind-address=127.0.0.1 --character-set-server=utf8mb4 --collation-server=utf8mb4_general_ci >/tmp/mariadb-draenor.log 2>&1 &"
  for i in $(seq 1 15); do sleep 2; distrobox enter $BOX -- bash -lc "sudo mariadb --socket=$SOCK -e 'SELECT 1'" >/dev/null 2>&1 && break; done
fi
distrobox enter $BOX -- bash -lc "sudo mariadb --socket=$SOCK -e 'SET GLOBAL max_allowed_packet=536870912'" >/dev/null 2>&1
echo "   MariaDB: $(distrobox enter $BOX -- bash -lc "sudo mariadb --socket=$SOCK -e 'SELECT 1'" >/dev/null 2>&1 && echo UP || echo DOWN)"

echo "## 2. authserver 1119 (container, respawn supervisor)"
distrobox enter $BOX -- setsid bash /var/home/blizz/Projects/draenor-dit/runtime/run-auth-supervisor.sh >/dev/null 2>&1 &

echo "## 3. worldserver 8085 (container, FIFO console)"
distrobox enter $BOX -- setsid bash /var/home/blizz/Projects/draenor-dit/runtime/run-world-console.sh >/dev/null 2>&1 &

echo "## 4. NGDP HTTP :80 + socat :87->1119 (HOST; needs port floor lowered by setup-client-connect.sh)"
: > "$NGDP/http.log"
setsid python3 "$NGDP/serve.py" > "$NGDP/http.log" 2>&1 < /dev/null &
setsid socat TCP-LISTEN:87,fork,reuseaddr,bind=127.0.0.1 TCP:127.0.0.1:1119 > "$NGDP/socat.log" 2>&1 < /dev/null &

sleep 8
echo "## listeners:"
distrobox enter $BOX -- bash -lc 'ss -ltn | grep -E ":1119|:8085|:3307"' 2>/dev/null
ss -ltn 2>/dev/null | grep -E "127.0.0.1:80 |127.0.0.1:87 " || echo "   !! :80/:87 NOT up — did you run setup-client-connect.sh (sudo) first?"
echo "## versions self-test:"; curl -s --max-time 4 "http://us-cdn.fstorm.cc/wow/versions" | head -2 || echo "   curl failed"
echo "## DONE. Launch client: bash runtime/launch-client-gamescope.sh"
