#!/usr/bin/env bash
# run-auth-supervisor.sh — keep the Draenor authserver alive (respawn on exit).
# Launch via: distrobox enter draenor-devbox -- setsid bash /var/home/blizz/Projects/draenor-dit/runtime/run-auth-supervisor.sh &
cd /home/blizz/Draenor-Core/run-auth
exec >> /home/blizz/Draenor-Core/run-auth/authserver-live.log 2>&1
while true; do
  echo "[supervisor] $(date) starting authserver..."
  ./authserver
  echo "[supervisor] $(date) authserver exited rc=$?, restarting in 3s"
  sleep 3
done
