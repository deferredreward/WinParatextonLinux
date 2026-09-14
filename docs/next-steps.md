# Next steps (written 2026-09-14 evening, for whoever opens the next session)

Two follow-ups were discussed; neither has been started. Both are independent of the working
Bottles setup, which stays as-is.

## A. Plain Wine, no Bottles (untested, expected to work)

Nothing in the fix is Bottles-specific: it is a Wine prefix, a Wine >= 11.2 *staging* build,
`dotnet48` + `gdiplus`, and registry values. Bottles contributed runner downloads, its own
dotnet48 recipe, a GUI -- and DXVK, which then had to be turned off. Wine's native "per-app
config" is `HKCU\Software\Wine\AppDefaults\Paratext.exe\...` (X11 Driver values and
DllOverrides can be scoped to Paratext.exe alone).

Plan, all testable on this machine without root by using the Kron4ek tarball standalone:
```bash
W=~/.var/app/com.usebottles.bottles/data/bottles/runners/kron4ek-wine-11.17-staging-amd64/bin
export WINEPREFIX=~/.wine-paratext WINEARCH=win64 PATH="$W:$PATH"
wineboot -u
curl -LO https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks && chmod +x winetricks
./winetricks -q dotnet48 gdiplus            # slow; the unverified step -- Bottles used its own recipe
wine /path/to/ParatextInstaller.exe
wine reg add 'HKCU\Software\Wine\X11 Driver' /v Decorated /t REG_SZ /d N /f
wine reg add 'HKCU\Software\Wine\X11 Driver' /v UseTakeFocus /t REG_SZ /d N /f
for d in d3d11 dxgi d3d9 d3d10core; do wine reg add 'HKCU\Software\Wine\DllOverrides' /v $d /t REG_SZ /d builtin /f; done
wine reg add 'HKCU\Control Panel\Desktop' /v LogPixels /t REG_DWORD /d 168 /f   # optional
```
Then the probe (`tools/InputLangCheck.cs` header has the plain-wine commands) and a `.desktop`
launcher. Unknowns: winetricks' dotnet48 on wine-11.17-staging; WineHQ's Fedora
`winehq-staging` package as an alternative to the tarball. Outcome would turn
`setup-paratext-linux.sh` into two variants. Budget: an hour plus dotnet48 install time.

## B. Fixing the Wine bug (WineHQ #51166) ourselves

Sizing, honestly:
- **Diagnosis is cheap (~1-2 h, no build):** run `tools/TinyWin.cs` on the dead monitor with
  `WINEDEBUG=+event,+msg,+win` and see whether `WM_LBUTTONDOWN` is queued and to which hwnd, or
  where it is dropped. Code to read: `dlls/winex11.drv/mouse.c` (event -> `send_mouse_input`,
  coordinate mapping), `dlls/win32u/message.c` (hardware message routing,
  `find_hardware_message_window`), `dlls/win32u/sysparams.c` (virtual screen / monitor rects,
  `map_dpi_*`). The symptom (works iff every monitor has non-negative coordinates) smells like
  a sign/clamp bug on the point or a rect -- often a one- or two-line fix once found.
- **Building Wine is the cost:** `sudo dnf builddep wine` (~1-2 GB of -devel packages), a
  ~1 GB clone of https://gitlab.winehq.org/wine/wine, and a first 64-bit build of 30-60+ min
  on this laptop; rebuilding just `win32u`/`winex11.drv` afterwards takes minutes. ~10 GB disk.
  The Kron4ek runner is *staging*; reproduce on a plain upstream build first so the patch is
  against upstream.
- **Submitting:** merge request on gitlab.winehq.org (account needed), referencing #51166,
  with the reproducer. Review can take weeks; effort is small once the patch exists.

Recommendation: do the diagnosis first; commit to the build only if the fix looks small. The
hard part -- a controlled reproducer with a single toggle -- is already done.
