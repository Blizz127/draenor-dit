#!/usr/bin/env bash
# launch-wow-lutris.sh — Launch the WoD client with Wine Staging (direct, no umu/pressure-vessel).
#
# This launcher uses Wine Staging directly and sets raw-input-related Wine keys.
# It is useful for local testing, but it does not by itself prove the movement
# issue is fixed; movement still needs a real-input matrix against server logs.
#
# This script:
#   1. Uses the system Wine Staging (~/.local/bin/wine) directly
#   2. Uses a dedicated Wine prefix (separate from umu)
#   3. Sets registry keys for raw input
#   4. Runs in a virtual desktop (windowed) for stability under Wayland
#   5. Cleans up on exit (no freeze)
set -uo pipefail

WOD_DIR="/var/home/blizz/Projects/draenor-dit/wod"
WINE_EXE="/var/home/blizz/.local/bin/wine"
WINEPREFIX_DIR="/var/home/blizz/Games/wow-wod-staging"
SERVER_IP="${DRAENOR_SERVER_IP:-100.111.220.11}"

# Use a dedicated prefix (copy from umu if it doesn't exist, to get the .auth modules)
if [ ! -d "$WINEPREFIX_DIR" ]; then
    echo "## Creating new Wine prefix at $WINEPREFIX_DIR ..."
    export WINEPREFIX="$WINEPREFIX_DIR"
    WINEDEBUG=-all "$WINE_EXE" wineboot --init 2>/dev/null
    # Copy the bnet auth modules from the umu prefix
    SRC_CACHE="/var/home/blizz/Games/umu/umu-default/pfx/drive_c/ProgramData/Blizzard Entertainment/Battle.net/Cache"
    DST_CACHE="$WINEPREFIX_DIR/drive_c/ProgramData/Blizzard Entertainment/Battle.net/Cache"
    if [ -d "$SRC_CACHE" ]; then
        mkdir -p "$DST_CACHE"
        cp -r "$SRC_CACHE"/* "$DST_CACHE/" 2>/dev/null
        echo "## Copied .auth modules"
    fi
else
    echo "## Using existing prefix at $WINEPREFIX_DIR"
fi

export WINEPREFIX="$WINEPREFIX_DIR"
export WINEDEBUG=-all
export DISPLAY="${DISPLAY:-:0}"

# Set registry keys for raw input compatibility under Wine/Wayland.
echo "## Setting raw input registry keys..."
"$WINE_EXE" reg add "HKCU\\Software\\Wine\\DirectInput" /v MouseButtons /t REG_SZ /d "0" /f 2>/dev/null
"$WINE_EXE" reg add "HKCU\\Software\\Wine\\DirectInput" /v UseRawInput /t REG_DWORD /d 1 /f 2>/dev/null
"$WINE_EXE" reg add "HKCU\\Software\\Wine\\X11 Driver" /v GrabFullscreen /t REG_SZ /d "Y" /f 2>/dev/null

# Also set the WoW registry key for the portal (patched exe uses IP directly,
# but set this just in case)
"$WINE_EXE" reg add "HKCU\\Software\\Blizzard Entertainment\\World of Warcraft" /v LastPortal-enUS /t REG_SZ /d "$SERVER_IP" /f 2>/dev/null

echo "## Launching Wow-64.exe with Wine Staging..."
cd "$WOD_DIR"

# Reset CWD in case the calling shell's working directory no longer exists
# (wine inherits the caller's PWD and will fail with "getcwd: cannot access parent")
cd /

# Run WoW directly with Wine Staging
"$WINE_EXE" "$WOD_DIR/Wow-64.exe" &
WOW_PID=$!

# Wait for WoW to exit
wait $WOW_PID 2>/dev/null
EXIT_CODE=$?

# Clean up any lingering processes
sleep 2
pkill -f "Wow-64.exe" 2>/dev/null
wineserver -k 2>/dev/null
sleep 1

exit $EXIT_CODE
