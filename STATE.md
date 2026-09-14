# STATE

What this project is and what anyone picking it up needs to know. Not a log; history lives
in commits.

## Goal

A reproducible recipe for running Windows Paratext 9.5+ on Fedora Linux (Bottles first,
plain Wine as fallback), published here for other Linux users.

## Status (2026-09-14, end of day)

Paratext 9.5 **runs and is usable on one monitor**: starts, main menu present, downloads and
installs resources, opens OT and NT resources, no crashes in a full session. Verified on
Fedora 44 + Bottles 67.3 + `kron4ek-wine-11.17-staging-amd64` under KDE Plasma 6.7.5.

Still open: a second monitor on a **Wayland** session. Two fixes were applied (see
`docs/display-and-crash-findings-2026-09-14.md`); the second one -- making the external
monitor the X primary -- was not yet verified when the session ended. A **Plasma (X11)**
session is installed/being installed as the fallback and is the next thing to test.

Read in this order: `docs/verified-recipe-fedora.md` (get it to start), then
`docs/display-and-crash-findings-2026-09-14.md` (get it usable).

## Gotchas

Startup:
- `Culture is not supported ... 0 (0x0000)` is Wine bug 40435, fixed in Wine 11.2. Nothing in
  the registry, locale env vars or Paratext can work around it on older Wine. Bottles' house
  runners and Fedora's `wine` rpm are all too old. Use a **staging** Kron4ek runner: staging
  also carries the `Keyboard Layouts` registry keys (Wine bug 47439) that .NET reads next.
- Switching the runner on the existing bottle did **not** damage `dotnet48`. No reinstall.
- `wineboot -u` after the switch misbehaved (browser tab, error dialogs, ~35 min wall-clock,
  then exit 0 and a healthy prefix). Do not assume it is working normally; dismiss dialogs,
  let it exit, verify with the probe. An earlier write-up called it normal; it is not.
- `tools/InputLangCheck.cs` reproduces the crash in isolation; grade any Wine build with it.

Usability (each verified with a log, details in the findings doc):
- **Turn DXVK off for this bottle.** Bottles enables it by default; Paratext's embedded
  Firefox renderer composites through D3D11 and crashed hard (`0x80000003`) loading resources.
  `d3d11/dxgi/d3d9/d3d10core = builtin`, `dxvk: false`, `vkd3d: false`.
- **Turn WM decorations off** (`Decorated=N`). Paratext 9 draws its own title bar containing
  the main menu (the hamburger + logo + search strip); a WM title bar covers it. The strip
  renders on black under Wine (no DWM); cosmetic.
- Wine DPI: `LogPixels` **and** Bottles' `custom_dpi` must agree or Bottles reverts it.
- A maximized Paratext window cannot be dragged (no WM title bar). KWin: `Meta+PgUp`,
  `Meta+drag`, `Meta+Shift+Right`, `Alt+F3`.
- Do **not** add a Gecko `user.js` to `AppData\Local\Paratext95` to force software rendering:
  Paratext crashes at the splash screen. Do **not** use Wine's Wayland driver: third
  `InputLanguage` bug (`OverflowException`), unclickable popups.
- On KDE Wayland the X11-app scaling control is `kdeglobals [KScreen] XwaylandClientsScale`,
  applied live with `kwriteconfig6 --notify`; `kwinrc [Xwayland] Scale` is derived and gets
  rewritten. With two monitors at different scales no single Wine DPI fits both.

Tooling:
- `bottles-cli shell -b Paratext -i 'cmd /c C:/probe/x.bat'` is the way to run things in the
  bottle with output; Windows paths with backslashes get eaten on the way in, so use .bat.
- `bottles-cli edit --runner` does not run the prefix update; run `wineboot -u` yourself.
- Hard crashes never reach Paratext's log. `tools/launch-paratext-logged.sh` +
  `tools/analyze-paratext-log.sh`, with the bottle's `WINEDEBUG=+seh,+loaddll` and
  `ShowCrashDialog=0`, give module + backtrace + managed stack without clicking anything.

## Open questions

- Does making the external monitor the X primary fix clicks on it under Wayland?
- Does everything behave under Plasma (X11)? (Expected to sidestep the multi-monitor class.)
- Send/Receive on this runner, plugins, printing, spell check, non-Latin keyboards/IME.
- Whether a non-staging runner plus `tools/keyboard-layouts-00000409.reg` is equivalent.
- Whether a from-scratch install on the staging runner is as smooth as the upgrade path.
- Logos (separate prefix, `LogPixels=168` set): untested after today's changes.

## Human blockers

- Root is needed for `dnf install plasma-workspace-x11`; the agent cannot sudo here.
