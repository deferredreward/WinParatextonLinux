#!/usr/bin/env bash
# Launch Paratext through Bottles with Wine's stderr captured to a timestamped
# file, so a hard crash (one Paratext's own log never sees) leaves evidence.
#
# Uses `bottles-cli shell -i 'cmd /c ...'`, the one invocation form verified to
# stream Wine's stderr back (2026-09-14). `bottles-cli run` was not verified to.
# Side effect: a cmd.exe + bwrap wrapper lingers after Paratext exits; harmless.
#
# Usage: tools/launch-paratext-logged.sh [BottleName]
set -u
B="${1:-Paratext}"
LOGDIR="${HOME}/paratext-wine-logs"
mkdir -p "$LOGDIR"
LOG="$LOGDIR/paratext-$(date +%Y%m%d-%H%M%S).log"
{
  echo "# $(date -Is)  bottle=$B"
  grep -E '^Runner:' "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$B/bottle.yml" | sed 's/^/# /'
  echo "# kwinrc [Xwayland] $(grep -A1 '^\[Xwayland\]' "$HOME/.config/kwinrc" | tail -1)"
  echo "# Xwayland pid/start: $(ps -o pid=,lstart= -p "$(pgrep -x Xwayland | head -1)" 2>/dev/null)"
  DISPLAY=:0 xrandr 2>/dev/null | grep -E 'Screen| connected' | sed 's/^/# /'
  DISPLAY=:0 xrdb -query 2>/dev/null | grep -i dpi | sed 's/^/# /'
  grep -E '^\s+(dxvk|vkd3d|wayland|custom_dpi):' "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$B/bottle.yml" | sed 's/^/# /'
  python3 -c "import yaml,sys;d=yaml.safe_load(open(sys.argv[1]));print('# DLL_Overrides:',d.get('DLL_Overrides'));print('# WINEDEBUG:',d.get('Environment_Variables',{}).get('WINEDEBUG'))" "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$B/bottle.yml" 2>/dev/null
  [ -f "$HOME/.var/app/com.usebottles.bottles/data/bottles/bottles/$B/drive_c/users/$USER/AppData/Local/Paratext95/user.js" ] && echo "# gecko user.js: present"
  echo "# ---- wine output follows ----"
} > "$LOG"
echo "logging to $LOG"
exec flatpak run --command=bottles-cli com.usebottles.bottles shell -b "$B" \
  -i 'cmd /c "C:\Program Files\Paratext 9\Paratext.exe"' >> "$LOG" 2>&1
