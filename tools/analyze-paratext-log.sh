#!/usr/bin/env bash
# Summarize a log from launch-paratext-logged.sh: environment header, which D3D
# path was in use, unhandled exceptions with the module they landed in (via
# +loaddll), the managed .NET stack Wine's eventlog captured, the winedbg
# backtrace, and the last Paratext UI events before the end.
# Usage: tools/analyze-paratext-log.sh [logfile]   (default: newest)
set -u
L="${1:-$(ls -t "$HOME"/paratext-wine-logs/*.log 2>/dev/null | head -1)}"
[ -f "$L" ] || { echo "no log"; exit 1; }
echo "### $L  ($(wc -l < "$L") lines)"
echo; echo "## environment"; grep '^#' "$L" | head -22

echo; echo "## D3D path"
grep -q 'info:  Presenter\|DXVK:' "$L" && echo "DXVK active (Presenter/DXVK lines present)" || echo "no DXVK lines"
grep -qiE 'wined3d|fixme:d3d|err:d3d' "$L" && echo "wined3d lines present" || echo "no wined3d lines"
grep -E 'Loaded L"[^"]*\\\\(d3d11|dxgi|d3d9|wined3d)\.dll"' "$L" | sed 's/.*Loaded /  /' | sort -u | head -6

echo; echo "## unhandled exceptions"
grep -nE 'Unhandled exception|Unhandled page fault|err:seh:NtRaiseException' "$L" | head -10 | cut -c1-160
resolve() {  # $1 = 0x address -> module with largest base <= address (needs +loaddll)
  grep -oE 'Loaded L"[^"]+" at [0-9A-Fa-f]+: (builtin|native)' "$L" | sort -u \
  | awk -v A="$1" 'BEGIN{a=strtonum(A); best=0}
      {match($0,/ at [0-9A-Fa-f]+/); b=strtonum("0x" substr($0,RSTART+4,RLENGTH-4));
       if (b<=a && a-b<67108864 && b>best) {best=b; l=$0}}
      END{ if (l) { sub(/.*\\\\/,"",l); printf("   %s  (+0x%x)\n", l, a-best) } else print "   (no module base below it; +loaddll missing?)" }'
}
for addr in $( { grep -oE 'addr 0x[0-9a-fA-F]+' "$L" | awk '{print $2}'
                 grep -oE 'at address [0-9A-Fa-f]+' "$L" | awk '{print "0x"$3}'; } | sort -u | head -5); do
  echo "-- module containing $addr:"; resolve "$addr"
done

echo; echo "## managed (.NET) stack via eventlog"
grep -F 'err:eventlog:ReportEventW' "$L" | sed -E 's/^.*ReportEventW L"//; s/\\n"$//' | grep -v '^"$' | head -25

echo; echo "## winedbg backtrace"
awk '/starting debugger|Unhandled exception:/{f=1} f' "$L" \
  | grep -E 'Unhandled|Backtrace|^=>|^ +[0-9]+ 0x|Modules:|in [A-Za-z0-9_.]+ \(|Exception c' | head -30 | cut -c1-160

echo; echo "## last Paratext UI events"
grep -E 'Usage:  (Form|Button|ToolBarButton|Menu)|Loading text for|GetText ' "$L" | tail -10 | cut -c1-150

echo; echo "## tail (non-noise)"
grep -vE 'lsteamclient|ifproxy_release|get_stub_manager|trace:loaddll|trace:seh|^info:|winemenubuilder|Paratext.exe Information' "$L" | tail -12 | cut -c1-170
