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

## C. Paratext <-> Logos verse sync (same Wine prefix) -- evidenced, not yet attempted

**Mechanism (verified from the binaries and registries, 2026-09-14):** Paratext's
`LibronixLinker.dll` talks to Logos through Windows COM automation -- `GetActiveObject` /
`CreateInstance` on `ILogosLauncher` (`Interop.Logos4Lib.dll`) or the legacy
`LibronixDLS.LbxApplication`. Logos 10 (v53) registers its side **per-user in its own prefix**
(`user.reg`): `LogosBibleSoftware.Launcher` -> CLSID `{319A0316-DF84-4B3C-8117-349B7E98E613}`
-> `LocalServer32 = ...\Logos\System\LogosCom.exe` (an out-of-process COM server), and
`LogosBibleSoftware.Application` -> `{FD24A0E8-C3F2-4821-A456-35DA2DC4BB8F}`. That first CLSID
is one of the classes Paratext logged as "not registered" all day: Paratext was looking for
Logos and finding an empty prefix. Under Wine, COM registration, the RPC endpoint mapper and
the Running Object Table are all per wineserver, i.e. **per prefix** -- two prefixes can never
talk. One shared prefix can, if Wine's out-of-process COM handles `LogosCom.exe` (standard
Wine machinery; untested with these two apps).

**Constraints:** Paratext needs Wine >= 11.2 staging (culture bug) and dotnet48 + gdiplus.
Logos 53 is .NET Core self-contained (no Framework in its prefix) and is pinned by oudedetai
4.0.0-beta.14 to `wine-staging_10.8` (AppImage). So the shared prefix must run 11.17 staging,
and the open question is whether Logos runs on it. oudedetai supports `-p <dir with wine,
wineserver>` (the kron4ek runner's `bin/` fits) and persists `wine_binary` in
`~/.config/FaithLife-Community/oudedetai.json`; `--backup/--restore` exist too.

**Cheapest safe path (Option 1, reuse the 14 GB Logos install):**
1. Logos closed. Back up what a Wine-version bump touches: the prefix's `*.reg` files and
   `drive_c/windows` (~1.1 GB together; the 13 GB of Logos resources are not touched).
   `cp -a .../wine64_bottle/{system.reg,user.reg,userdef.reg} .../wine64_bottle/drive_c/windows  <backup>/`
2. Test Logos on the new Wine: `oudedetai -p ~/.var/app/com.usebottles.bottles/data/bottles/runners/kron4ek-wine-11.17-staging-amd64/bin --run-installed-app`
   (or set `wine_binary` to that `wine`). Wine will update the prefix once. If Logos misbehaves:
   stop it, restore the backup, set `wine_binary` back -- done, nothing lost.
3. If Logos is fine on 11.17: in that prefix, `winetricks -q dotnet48 gdiplus` (unverified
   step -- Bottles used its own recipe), install Paratext, then apply the Paratext fixes
   **per-app** so Logos is untouched:
   `HKCU\Software\Wine\AppDefaults\Paratext.exe\X11 Driver` -> `Decorated=N`, `UseTakeFocus=N`;
   `HKCU\Software\Wine\AppDefaults\Paratext.exe\DllOverrides` -> `d3d11/dxgi/d3d9/d3d10core=builtin`
   (the Logos prefix has no DXVK, so this is belt-and-braces); `LogPixels` as wanted.
4. Run both; in Paratext enable sending references to Logos (setting `ContextToLogos`, already
   `True` here); change verse; watch Logos follow. Check Wine's stderr for `err:ole:` lines
   naming `{319A0316-...}` or `LogosCom.exe` if it does not.
5. Bottles then only manages the old Paratext bottle; the shared prefix is oudedetai's. A
   `.desktop` launcher for Paratext in that prefix replaces the Bottles entry.

Option 2 (Logos into the Bottles prefix) needs a full Logos re-download and resource copy --
21 GB free makes that tight; only if Option 1 fails for reasons other than Wine 11.17 itself.
