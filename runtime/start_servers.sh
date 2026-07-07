#!/usr/bin/env bash
# start_servers.sh — bring up the Draenor-Core auth+world servers in draenor-devbox.
#
# This script runs ON THE HOST and shells into the container. It:
#   1. ensures Draenor's isolated MariaDB (port 3307) is up,
#   2. starts authserver in the background,
#   3. starts worldserver in the foreground (Ctrl-C to stop both).
#
# It does NOT touch the host's cata-devbox MariaDB on 3306. Draenor uses 3307 + its
# own data dir /var/lib/mysql-draenor.
set -euo pipefail

SOCK=/run/mysqld-draenor/mysqld.sock
DATA=/var/lib/mysql-draenor

distrobox enter draenor-devbox -- bash -lc '
  set -e
  # 1. MariaDB on 3307 (start if not already)
  if ! sudo mariadb --socket='"$SOCK"' -e "SELECT 1" >/dev/null 2>&1; then
    echo "## starting Draenor MariaDB on 3307..."
    sudo mariadbd --user=mysql --port=3307 --socket='"$SOCK"' --datadir='"$DATA"' \
      --bind-address=127.0.0.1 --character-set-server=utf8mb4 \
      --collation-server=utf8mb4_general_ci > /tmp/mariadb-draenor.log 2>&1 &
    sleep 6
  fi
  sudo mariadb --socket='"$SOCK"' -e "SET GLOBAL max_allowed_packet=536870912;" 2>/dev/null || true
  echo "## MariaDB: $(sudo mariadb --socket='"$SOCK"' -N -e "SELECT CONCAT(VERSION(),\"  port=\",@@port)")")"

  # 2. authserver (background)
  cd ~/Draenor-Core/run-auth
  pkill -f "authserver/authserver" 2>/dev/null || true
  echo "## starting authserver..."
  nohup ./authserver > authserver.log 2>&1 &
  sleep 3

  # 3. worldserver (foreground — Ctrl-C to stop, then it cleans up authserver too)
  echo "## starting worldserver (Ctrl-C to stop)..."
  cd ~/Draenor-Core/run-world
  trap "pkill -f \"authserver/authserver\" 2>/dev/null" EXIT
  ./worldserver
'
