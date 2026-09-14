#!/usr/bin/env bash
# Paratext 9.5 on Linux via Bottles: automates every step verified on 2026-09-14 and stops,
# with a clear banner, at the two steps only a human can do (installing Bottles' dotnet48 +
# gdiplus dependencies from its GUI, and running the Paratext installer you downloaded).
# Safe to re-run: each phase checks before it changes anything.
#
#   ./setup-paratext-linux.sh                 # walk through everything
#   ./setup-paratext-linux.sh --check         # only report what is/isn't in place
#   ./setup-paratext-linux.sh --installer ~/Downloads/ParatextInstaller.exe
#   ./setup-paratext-linux.sh --dpi 144       # Wine UI scale (96 = 100%, 144 = 150%, 168 = 175%)
#
# Details, evidence and the dead ends: STATE.md, docs/verified-recipe-fedora.md,
# docs/display-and-crash-findings-2026-09-14.md in this repository.
set -u
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOTTLE="Paratext"; RUNNER="kron4ek-wine-11.17-staging-amd64"; DPI=""; INSTALLER=""; CHECK=0
while [ $# -gt 0 ]; do case "$1" in
  --bottle) BOTTLE="$2"; shift 2;; --runner) RUNNER="$2"; shift 2;; --dpi) DPI="$2"; shift 2;;
  --installer) INSTALLER="$2"; shift 2;; --check) CHECK=1; shift;;
  -h|--help) sed -n '2,14p' "$0"; exit 0;; *) echo "unknown option $1"; exit 2;; esac; done

ROOT="$HOME/.var/app/com.usebottles.bottles/data/bottles"; RUNNERS="$ROOT/runners"; PREFIX="$ROOT/bottles/$BOTTLE"
BC="flatpak run --command=bottles-cli com.usebottles.bottles"
ok(){ printf '  \033[32m[ok]\033[0m %s\n' "$*"; }; todo(){ printf '  \033[33m[..]\033[0m %s\n' "$*"; }; bad(){ printf '  \033[31m[!!]\033[0m %s\n' "$*"; }
manual(){ printf '\n\033[1;33m=== MANUAL STEP: %s ===\033[0m\n%s\n\n' "$1" "$2"; }
bat(){ # run a small batch file inside the bottle and print its output (paths with backslashes get mangled on the CLI; .bat files do not)
  mkdir -p "$PREFIX/drive_c/probe"; printf '@echo off\r\n%s\r\n' "$2" > "$PREFIX/drive_c/probe/$1.bat"
  timeout 300 $BC shell -b "$BOTTLE" -i "cmd /c C:/probe/$1.bat" 2>/dev/null | tr -d '\r' | grep -vE 'lsteamclient|Catalog|winemenubuilder|wineserver:|ifproxy|get_stub_manager|Shell cwd'; }
reg_is(){ bat "q_$2" "reg query \"$1\" /v $2" | grep -qE "$2\s+REG_(SZ|DWORD)\s+$3$"; }
reg_set(){ timeout 300 $BC reg add -b "$BOTTLE" -k "$1" -v "$2" -d "$3" -t "$4" >/dev/null 2>&1; }

echo "Paratext 9.5 on Linux -- setup / check   (bottle: $BOTTLE, runner: $RUNNER)"

# ---- 1. Bottles ---------------------------------------------------------------------------
echo; echo "1. Bottles (Flatpak)"
if flatpak info com.usebottles.bottles >/dev/null 2>&1; then ok "Bottles $(flatpak info com.usebottles.bottles 2>/dev/null | awk '/Version:/{print $2}') installed"
else bad "Bottles is not installed"; [ $CHECK = 1 ] || manual "install Bottles" "  flatpak install flathub com.usebottles.bottles
Then run this script again."; exit 1; fi

# ---- 2. Runner: a wine-staging build >= 11.2 ----------------------------------------------
echo; echo "2. Wine runner"
case "$RUNNER" in *staging*) ;; *) bad "$RUNNER is not a staging build; the Keyboard Layouts registry keys will be missing (the .reg fallback is applied later)";; esac
if [ -x "$RUNNERS/$RUNNER/bin/wine" ]; then ok "$($RUNNERS/$RUNNER/bin/wine --version) present"
elif [ $CHECK = 1 ]; then todo "runner not downloaded"
else
  todo "downloading $RUNNER via Bottles' own component manifest"
  M=$(curl -sfL --max-time 60 "https://raw.githubusercontent.com/bottlesdevs/components/main/runners/wine/$RUNNER.yml") || { bad "could not fetch the manifest; download it in Bottles > Preferences > Runners instead"; exit 1; }
  URL=$(echo "$M" | awk '/url:/{print $2}' | head -1); SUM=$(echo "$M" | awk '/file_checksum:/{print $2}' | head -1); SRC=$(echo "$M" | awk '/source:/{print $2}' | head -1)
  T=$(mktemp -d); curl -L --max-time 900 -o "$T/r.tar.xz" "$URL" || { bad "download failed"; exit 1; }
  echo "$SUM  $T/r.tar.xz" | md5sum -c --quiet || { bad "checksum mismatch, refusing to install"; exit 1; }
  mkdir -p "$RUNNERS" && tar -xf "$T/r.tar.xz" -C "$RUNNERS" && [ -n "$SRC" ] && [ "$SRC" != "$RUNNER" ] && mv "$RUNNERS/$SRC" "$RUNNERS/$RUNNER"
  rm -rf "$T"; [ -x "$RUNNERS/$RUNNER/bin/wine" ] && ok "$($RUNNERS/$RUNNER/bin/wine --version) installed" || { bad "runner did not land in $RUNNERS/$RUNNER"; exit 1; }
fi

# ---- 3. Bottle -----------------------------------------------------------------------------
echo; echo "3. Bottle '$BOTTLE' (win64, application)"
if [ -f "$PREFIX/bottle.yml" ]; then ok "exists (runner: $(awk '/^Runner:/{print $2}' "$PREFIX/bottle.yml"))"
  CUR=$(awk '/^Runner:/{print $2}' "$PREFIX/bottle.yml"); [ "$CUR" = "$RUNNER" ] || { [ $CHECK = 1 ] && todo "runner is $CUR, want $RUNNER" || { todo "switching runner to $RUNNER, then updating the prefix (this can hang and open error dialogs; dismiss them, it exits 0 in the end)"; timeout 600 $BC edit -b "$BOTTLE" --runner "$RUNNER" >/dev/null 2>&1; timeout 3600 $BC shell -b "$BOTTLE" -i 'wineboot -u' >/dev/null 2>&1; ok "runner switched"; }; }
elif [ $CHECK = 1 ]; then todo "bottle not created"
else timeout 900 $BC new --bottle-name "$BOTTLE" --environment application --arch win64 --runner "$RUNNER" >/dev/null 2>&1; [ -f "$PREFIX/bottle.yml" ] && ok "created" || { bad "bottle creation failed; create it in Bottles (Application, win64, runner $RUNNER) and re-run"; exit 1; }; fi

# ---- 4. Dependencies: dotnet48 + gdiplus (Bottles GUI only) --------------------------------
echo; echo "4. .NET Framework 4.8 and gdiplus"
DEPS_OK=1; for d in dotnet48 gdiplus; do grep -qE "^- $d$" "$PREFIX/bottle.yml" 2>/dev/null && ok "$d installed" || { todo "$d not installed"; DEPS_OK=0; }; done
[ $DEPS_OK = 1 ] || [ $CHECK = 1 ] || { manual "install dependencies in Bottles" "  Open Bottles -> bottle '$BOTTLE' -> Dependencies -> install  dotnet48  then  gdiplus.
  (bottles-cli cannot do this.) Takes a while. Then run this script again."; exit 0; }

# ---- 5. Paratext installer ------------------------------------------------------------------
echo; echo "5. Paratext 9.5"
PT="$PREFIX/drive_c/Program Files/Paratext 9/Paratext.exe"
if [ -f "$PT" ]; then ok "installed: $(cat "$PREFIX/drive_c/Program Files/Paratext 9/CurrentVersion.number" 2>/dev/null || echo present)"
elif [ $CHECK = 1 ]; then todo "Paratext not installed"
elif [ -n "$INSTALLER" ] && [ -f "$INSTALLER" ]; then todo "running the installer in the bottle -- complete it in the window that opens"; timeout 3600 $BC run -b "$BOTTLE" -e "$INSTALLER" >/dev/null 2>&1; [ -f "$PT" ] && ok "installed" || { bad "Paratext.exe not found after the installer"; exit 1; }
else manual "install Paratext" "  Download the Paratext 9.5 installer for Windows from https://paratext.org/download/ , then:
    $0 --installer /path/to/the/downloaded/installer.exe
  (or run it from Bottles: bottle '$BOTTLE' -> Run executable). Register with your Paratext account when it asks."; exit 0; fi

# ---- 6. Fixes (all verified 2026-09-14) -----------------------------------------------------
echo; echo "6. Bottle configuration for Paratext"
[ $CHECK = 1 ] || cp "$PREFIX/bottle.yml" "$PREFIX/bottle.yml.bak-$(date +%Y%m%d-%H%M%S)"
K='HKEY_CURRENT_USER\Software\Wine\X11 Driver'; D='HKEY_CURRENT_USER\Software\Wine\DllOverrides'
fix_reg(){ # key value data type label
  if reg_is "$1" "$2" "$3"; then ok "$5"; elif [ $CHECK = 1 ]; then todo "$5"; else reg_set "$1" "$2" "$3" "$4"; reg_is "$1" "$2" "$3" && ok "$5 (set)" || bad "$5: could not set"; fi; }
fix_reg "$K" Decorated N REG_SZ "Wine draws its own window frame (shows Paratext's hamburger main menu)"
fix_reg "$K" UseTakeFocus N REG_SZ "Wine does not grab X focus itself (no focus stealing from other Wine apps)"
for dll in d3d11 dxgi d3d9 d3d10core; do fix_reg "$D" $dll builtin REG_SZ "$dll = Wine builtin (no DXVK; DXVK crashes Paratext's embedded Firefox renderer)"; done
if [ -n "$DPI" ]; then HEX=$(printf '0x%x' "$DPI"); fix_reg 'HKEY_CURRENT_USER\Control Panel\Desktop' LogPixels "$HEX" REG_DWORD "Wine DPI $DPI (takes effect after every Wine process in the bottle has exited)"; fi
case "$RUNNER" in *staging*) ok "Keyboard Layouts registry keys come with wine-staging";; *) [ $CHECK = 1 ] || { cp "$HERE/tools/keyboard-layouts-00000409.reg" "$PREFIX/drive_c/probe/kl.reg"; bat kl 'regedit C:\probe\kl.reg' >/dev/null; }; ok "Keyboard Layouts fallback .reg imported";; esac
python3 - "$PREFIX/bottle.yml" "$CHECK" "$DPI" <<'PY'
import re,sys; p,check,dpi=sys.argv[1],sys.argv[2]=='1',sys.argv[3]; s=open(p).read(); o=s
for k in ('dxvk','vkd3d','decorated','take_focus'): s=re.sub(rf'^(\s+){k}: true$', rf'\1{k}: false', s, flags=re.M)
if 'DLL_Overrides: {}' in s: s=s.replace('DLL_Overrides: {}','DLL_Overrides:\n    d3d11: builtin\n    dxgi: builtin\n    d3d9: builtin\n    d3d10core: builtin',1)
if dpi: s=re.sub(r'^(\s+)custom_dpi: \d+$', rf'\1custom_dpi: {dpi}', s, flags=re.M)
if s!=o and not check: open(p,'w').write(s)
print(('  \033[32m[ok]\033[0m' if (s==o or not check) else '  \033[33m[..]\033[0m')+' bottle.yml: dxvk/vkd3d/decorated/take_focus false, DLL overrides, custom_dpi' + (' (updated)' if s!=o and not check else ''))
PY
if grep -q 'executable: Paratext.exe' "$PREFIX/bottle.yml"; then ok "'Paratext 9' registered as a program in Bottles"; elif [ $CHECK = 1 ]; then todo "program not registered"; else timeout 120 $BC add -b "$BOTTLE" -n "Paratext 9" -p "$PT" >/dev/null 2>&1 && ok "'Paratext 9' registered as a program in Bottles"; fi

# ---- 7. Probe: prove the keyboard-layout bug is gone ---------------------------------------
echo; echo "7. Startup-crash probe (tools/InputLangCheck.cs)"
if [ -f "$HERE/tools/InputLangCheck.cs" ]; then mkdir -p "$PREFIX/drive_c/probe"; cp "$HERE/tools/InputLangCheck.cs" "$PREFIX/drive_c/probe/"
  bat build 'cd /d C:\probe && C:\windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /r:System.Windows.Forms.dll /out:InputLangCheck.exe InputLangCheck.cs' >/dev/null
  R=$(bat run 'cd /d C:\probe && InputLangCheck.exe'); echo "$R" | grep -q '^PASS' && ok "PASS: $(echo "$R" | grep DefaultInputLanguage)" || bad "probe did not pass -- Paratext will crash at startup. Output: $(echo "$R" | tr '\n' ' ')"
else todo "probe source not found next to this script; skipped"; fi

# ---- 8. Monitors --------------------------------------------------------------------------
echo; echo "8. Monitor layout (Wine kills mouse input on any monitor above/left of the X primary)"
if [ -n "${DISPLAY:-}" ] && command -v xrandr >/dev/null 2>&1; then
  X=$(DISPLAY=${DISPLAY} xrandr 2>/dev/null | grep ' connected'); N=$(echo "$X" | wc -l)
  if [ "$N" -le 1 ]; then ok "single monitor"; else
    P=$(echo "$X" | grep primary | grep -oE '[0-9]+x[0-9]+\+[0-9]+\+[0-9]+'); PX=${P##*+}; PY=$(echo "$P" | cut -d+ -f2)
    MINX=$(echo "$X" | grep -oE '\+[0-9]+\+[0-9]+ ' | tr -d ' ' | cut -d+ -f2 | sort -n | head -1); MINY=$(echo "$X" | grep -oE '\+[0-9]+\+[0-9]+ ' | tr -d ' ' | cut -d+ -f3 | sort -n | head -1)
    if [ "$PY" = "$MINX" ] && [ "$PX" = "$MINY" ]; then ok "primary monitor is top-left; all monitors at non-negative Wine coordinates"
    else bad "primary monitor is NOT top-left: Paratext windows on the other monitor will not take clicks (Wine bug, WineHQ #51166)"; command -v kscreen-doctor >/dev/null && echo "       KDE fix: kscreen-doctor output.<TOP-LEFT-OUTPUT-NAME>.primary   (names: $(echo "$X" | awk '{print $1}' | tr '\n' ' '))" || echo "       fix: make the top-left monitor the primary in your display settings"; fi; fi
else todo "no X display in this shell; check that your top-left monitor is the primary"; fi

echo; echo "Done. Launch: Bottles -> $BOTTLE -> Paratext 9   (or: $BC run -b $BOTTLE -p 'Paratext 9')"
echo "If it dies at the splash screen right after a display change, launch it again (known, harmless)."
echo "With problems, launch via tools/launch-paratext-logged.sh and read the log with tools/analyze-paratext-log.sh."
