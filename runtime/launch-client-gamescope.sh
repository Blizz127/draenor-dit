#!/usr/bin/env bash
# Launch the WoD client inside gamescope (fixes Wayland/XWayland input + fullscreen focus).
cd /var/home/blizz/Projects/draenor-dit/wod
export WINEPREFIX=/var/home/blizz/Games/umu/umu-default/pfx
export STEAM_COMPAT_DATA_PATH=/var/home/blizz/Games/umu/umu-default
export PROTONPATH=/var/home/blizz/.local/share/Steam/compatibilitytools.d/GE-Proton10-34
export GAMEID=umu-default STORE=none
exec gamescope -W 1920 -H 1080 -f --force-grab-cursor -- \
  umu-run /var/home/blizz/Projects/draenor-dit/wod/Wow-64.exe
