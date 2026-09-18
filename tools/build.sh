#!/bin/sh
# Compile a SA-MP Pawn script. Usage: tools/build.sh filterscripts/cheats.pwn
set -e
DIR="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$1"
[ -n "$SRC" ] || { echo "usage: $0 <script.pwn>"; exit 1; }
LD_LIBRARY_PATH="$DIR/tools/pawnc-3.10.10-linux/lib" \
  "$DIR/tools/pawnc-3.10.10-linux/bin/pawncc" "$SRC" \
  -i"$DIR/tools/include" -i"$DIR/include" \
  -o"${SRC%.pwn}.amx" -d0 -O1
echo "built ${SRC%.pwn}.amx"
