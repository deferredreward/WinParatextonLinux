# Fedora session plan: get past the keyboard/culture crash

Written 2026-09-14 from research only (see `docs/research-2026-09-14-culture-error.md`).
Each step says how we know it worked. Do them in order; stop at the first one that passes.

## Step 0: orient (2 min)

Record what is actually installed, so the write-up is accurate.

```bash
cat /etc/fedora-release
echo "session=$XDG_SESSION_TYPE display=$DISPLAY wayland=$WAYLAND_DISPLAY"
flatpak info com.usebottles.bottles | grep -E 'Version|Branch'
ls ~/.var/app/com.usebottles.bottles/data/bottles/runners/
ls ~/.var/app/com.usebottles.bottles/data/bottles/bottles/
```

Then, for the Paratext bottle (substitute its name):

```bash
grep -E '^(Runner|Arch|Environment):' ~/.var/app/com.usebottles.bottles/data/bottles/bottles/<BottleName>/bottle.yml
```

Expected: Runner is `soda-11.0-*` or `caffe-10.0`. Both have the bug.

## Step 1: prove the bug with the probe (5 min)

Compile and run `tools/InputLangCheck.cs` in the existing bottle. `bottles-cli shell` runs
one command through the bottle's Wine and prints its output (verified against
`bottles/frontend/cli/cli.py` on main, 2026-09-14: `shell -b NAME -i "<command>"` wraps it
in `WineCommand(..., communicate=True)`). Copy the .cs file somewhere the bottle can see
(the Flatpak can read your home directory):

```bash
cp /path/to/WinParatextonLinux/tools/InputLangCheck.cs ~/InputLangCheck.cs
B="<BottleName>"
flatpak run --command=bottles-cli com.usebottles.bottles shell -b "$B" \
  -i 'C:\windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /nologo /r:System.Windows.Forms.dll /out:Z:\home\bmw\InputLangCheck.exe Z:\home\bmw\InputLangCheck.cs'
flatpak run --command=bottles-cli com.usebottles.bottles shell -b "$B" -i 'Z:\home\bmw\InputLangCheck.exe'
```

(Bottle names are the display names shown in Bottles; list them with
`flatpak run --command=bottles-cli com.usebottles.bottles list bottles`. If `shell` swallows
the console output, `run -b "$B" -e ~/InputLangCheck.exe` launches it too, and the header of
the .cs file has plain `wine ...` forms for a non-Bottles prefix.)

Expected on the current runner: `hkl=0x0` and `FAIL: CultureNotFoundException`. That
confirms the diagnosis before changing anything. If it PASSes on the current runner, the
diagnosis is wrong; stop and re-read the research file.

## Step 2: switch the bottle to a Wine >= 11.2 runner (10 min)

1. Bottles > Preferences (hamburger menu) > Runners > find
   `kron4ek-wine-11.17-staging-amd64` and click the download icon. Staging matters: it
   carries the `Keyboard Layouts` registry keys that .NET reads right after the culture
   (Wine bug 47439); the plain `kron4ek-wine-11.17-amd64` would fix the culture crash and
   then throw a NullReferenceException on the next property. The runner is on the stable
   channel, so no "release candidates" toggle is needed. If the list looks stale, quit and
   reopen Bottles or check the network; the catalog is fetched from bottlesdevs/components.
2. Open the Paratext bottle > Settings > Runner > pick that runner. Bottles runs a prefix
   update when the runner changes; let it finish.
3. Re-run the probe from Step 1. Expected: `hkl=0x4090409`, `culture=en-US`, a `layout=`
   value (either `US` or `Unknown` is fine), then `PASS`. If it prints
   `FAIL: NullReferenceException`, the runner lacks the registry keys: import
   `tools/keyboard-layouts-00000409.reg` (bottle > Tools > Registry editor > Import, or
   `bottles-cli shell -b "$B" -i 'regedit Z:\home\bmw\keyboard-layouts-00000409.reg'` after
   copying it to `~`), then re-run the probe.
4. Launch Paratext. Expected: no culture dialog; main window opens.

Verify: probe PASS, then Paratext main window with a project open. Screenshot it for the
README.

If the runner switch damages the .NET install (Paratext or the probe now fails with
mscoree/.NET errors): make a NEW bottle with the Kron4ek runner selected at creation, install
`dotnet48` and `gdiplus` from Dependencies, reinstall Paratext, register, Send/Receive. That
is the same path that already worked, on a fixed Wine.

## Step 3 (fallback): system Wine from WineHQ, no Bottles

Only if Bottles refuses to cooperate. These need root (dnf); run them yourself.

```bash
sudo dnf config-manager addrepo --from-repofile=https://dl.winehq.org/wine-builds/fedora/$(rpm -E %fedora)/winehq.repo
sudo dnf install winehq-staging winetricks     # 11.17 on F43/F44, 11.8 on F42; all >= 11.2
export WINEPREFIX=~/.wine-paratext WINEARCH=win64
wineboot -u
winetricks -q dotnet48 gdiplus
wine /path/to/ParatextInstaller.exe
```

Verify with the probe (`wine csc.exe ...` lines in the .cs header), then run Paratext. If
you installed `winehq-devel` instead of staging, import the .reg file first:
`wine regedit tools/keyboard-layouts-00000409.reg`.

## Step 4: record what happens next

Whatever blocks after the culture crash is the next research item. Capture the dialog text
or the Wine console output (run from a terminal so stderr is visible) into `docs/` and
update `STATE.md`.

## Not tried, deliberately

- Registry keyboard-layout edits, bottle Language setting, `LANG`/`LC_ALL`: cannot affect
  this crash (value is never copied out of Wine on the broken versions).
- DLL patching: no longer needed.
- Wayland vs X11 driver: not involved; Bottles under XWayland uses winex11.drv by default.
