#!/usr/bin/env bash
# End every Wine process in a Bottles bottle so the next launch starts a fresh
# wineserver session (needed for LogPixels/DPI changes to take effect).
# `bottles-cli stop` hung for >2 minutes on 2026-09-14; this talks to wineserver directly.
# Usage: tools/bottle-wineserver-kill.sh [BottleName]
set -u
B="${1:-Paratext}"
ROOT="$HOME/.var/app/com.usebottles.bottles/data/bottles"
PREFIX="$ROOT/bottles/$B"
RUNNER=$(grep -E '^Runner:' "$PREFIX/bottle.yml" | awk '{print $2}')
WS="$ROOT/runners/$RUNNER/bin/wineserver"
[ -x "$WS" ] || { echo "no wineserver at $WS"; exit 1; }
echo "killing wine session for bottle '$B' (runner $RUNNER)"
WINEPREFIX="$PREFIX" "$WS" -k
for i in $(seq 1 20); do pgrep -f "$ROOT/runners/$RUNNER" >/dev/null || { echo "all Wine processes gone after ${i}s"; exit 0; }; sleep 1; done
echo "some Wine processes still alive:"; pgrep -af "$ROOT/runners/$RUNNER" | grep -v 'bash -c' | head -5; exit 2
