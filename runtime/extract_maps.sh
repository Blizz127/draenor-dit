#!/usr/bin/env bash
# extract_maps.sh — generate maps/vmaps/mmaps from a WoD 6.2.3 (build 20779) client.
#
# Run this INSIDE the draenor-devbox container, AFTER the tools build produces the
# extractors. Point CLIENT_DIR at the WoD client install (the folder containing
# WoW-64.exe + the Data/ folder). Output lands in OUT_DIR (then symlinked into the
# worldserver run dir).
#
# Memory note: mmap_generator is single-threaded and long (hours on a big client).
# Run it overnight / when the host is otherwise idle.
#
# Usage:  CLIENT_DIR="/path/to/WoD client" ./extract_maps.sh
set -euo pipefail

CLIENT_DIR="${CLIENT_DIR:?Set CLIENT_DIR to the WoD client directory (containing WoW-64.exe)}"
TOOLS_DIR="${TOOLS_DIR:-/home/blizz/Draenor-Core/build-tools/src/tools}"
MMAP_BIN="$TOOLS_DIR/mmaps_generator/mmaps_generator"
MAP_BIN="$TOOLS_DIR/map_extractor/mapextractor"
VEX_BIN="$TOOLS_DIR/vmap4_extractor/vmap4extractor"
VAS_BIN="$TOOLS_DIR/vmap4_assembler/vmap4assembler"
OUT_DIR="${OUT_DIR:-/home/blizz/Draenor-Core/run-world}"

mkdir -p "$OUT_DIR"/{maps,vmaps,mmaps,dbc}
cd "$OUT_DIR"

echo "### 1/4 mapextractor (-> maps/ + dbc/)"
"$MAP_BIN" "$CLIENT_DIR"

echo "### 2/4 vmap4extractor (-> vmaps/*.vmtree + Buildings/)"
"$VEX_BIN" "$CLIENT_DIR"

echo "### 3/4 vmap4assembler (-> vmaps/*.vmtile)"
mkdir -p vmaps; "$VAS_BIN" Buildings vmaps

echo "### 4/4 mmaps_generator (LONG: hours). Off-mesh pathfinding tiles -> mmaps/."
"$MMAP_BIN"           # operates on cwd maps/vmaps

echo "### done. Data now in: $OUT_DIR/{maps,vmaps,mmaps,dbc}"
du -sh maps vmaps mmaps dbc
