#!/usr/bin/env bash
# run-world-console.sh — start worldserver with a FIFO on stdin so console
# commands can be injected (e.g. `.account create`). Detaches via setsid.
# Launch: distrobox enter draenor-devbox -- setsid bash \
#   /var/home/blizz/Projects/draenor-dit/runtime/run-world-console.sh &
# Send a command: echo '.account create ...' > ~/Draenor-Core/run-world/console.fifo
cd /home/blizz/Draenor-Core/run-world
FIFO=/home/blizz/Draenor-Core/run-world/console.fifo
rm -f "$FIFO"
mkfifo "$FIFO"
# Hold the write end open (fd 9) so worldserver never sees EOF on stdin.
exec 9<>"$FIFO"
exec ./worldserver < "$FIFO" >> worldserver-live.log 2>&1
