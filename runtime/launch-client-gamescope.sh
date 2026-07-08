#!/usr/bin/env bash
# Launch the WoD client inside gamescope (fixes Wayland/XWayland input + fullscreen focus).
# On exit, kills the entire process tree so the game doesn't freeze/hang on close.
cd /var/home/blizz/Projects/draenor-dit/wod
export WINEPREFIX=/var/home/blizz/Games/umu/umu-default/pfx
export STEAM_COMPAT_DATA_PATH=/var/home/blizz/Games/umu/umu-default
export PROTONPATH=/var/home/blizz/.local/share/Steam/compatibilitytools.d/GE-Proton10-34
export GAMEID=umu-default STORE=none

# Launch gamescope + umu-run in the background (not exec) so we can clean up.
gamescope -W 1920 -H 1080 -f --force-grab-cursor -- \
  umu-run /var/home/blizz/Projects/draenor-dit/wod/Wow-64.exe &
GAMESCOPE_PID=$!

# Wait for gamescope to exit (user closed the game, or it crashed).
wait $GAMESCOPE_PID 2>/dev/null
EXIT_CODE=$?

# Clean up any lingering WoW/Wine/umu processes that cause the freeze.
# This is the key fix: without this, the process tree hangs on close.
sleep 2
pkill -f "Wow-64.exe" 2>/dev/null
pkill -f "umu-run.*Wow-64" 2>/dev/null
pkill -f "proton waitforexitandrun.*Wow-64" 2>/dev/null
sleep 1
# Force-kill anything still alive (gamescope, pressure-vessel, etc.)
kill -9 $GAMESCOPE_PID 2>/dev/null
pkill -9 -f "gamescope.*Wow-64" 2>/dev/null

exit $EXIT_CODE
