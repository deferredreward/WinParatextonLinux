# After the startup crash: display, menu, and crash findings (2026-09-14, afternoon)

Everything here was observed on the Fedora 44 / Bottles 67.3 / kron4ek-wine-11.17-staging
setup from `docs/verified-recipe-fedora.md`, with logs. Each item says what was seen, what
was changed, and whether the result was verified. Unverified items are marked.

## Summary of what it took to make Paratext usable

| Symptom | Cause | Fix | Verified |
|---|---|---|---|
| Hard crash loading a resource (no .NET exception, `0x80000003` after DXVK swapchain churn) | Bottles enables DXVK by default; Paratext's embedded Firefox/Gecko renderer composites through D3D11 | `d3d11`, `dxgi`, `d3d9`, `d3d10core` = `builtin` (Wine's wined3d); `dxvk: false`, `vkd3d: false` | Yes: OT resources load, 0 exceptions in a full session |
| No main menu (the ☰ / logo / "Search menus/help" strip) | Paratext 9 draws a custom title bar; with WM decorations on, KWin's title bar covers it | `HKCU\Software\Wine\X11 Driver\Decorated = N` (`decorated: false` in Bottles) | Yes: strip appears. Its background is black (no DWM glass); cosmetic |
| Menu bar / popups dead after moving a window to the second monitor | Wayland compositor scaling of XWayland clients with two monitors at different scales, plus (probably) the X primary monitor not being at the origin | See "Multi-monitor" below | Partially; see below |
| Main window cannot be moved or resized | It is maximized (Paratext restores its saved state) and there is no WM title bar | KWin: `Meta+PgUp` un-maximize, `Meta+drag` move, `Meta+Shift+Right` next screen, `Alt+F3` menu | Yes |
| Too small on a 2560x1440 monitor | Wine renders at 96 DPI | `HKCU\Control Panel\Desktop\LogPixels = 168` (**and** `custom_dpi: 168` in `bottle.yml`, or Bottles reverts it) | Yes |

## Things that made it worse (do not repeat)

- **Gecko `user.js` with `layers.acceleration.disabled` / `gfx.webrender.software` etc.** in
  `AppData\Local\Paratext95\` -> `AccessViolationException` in `xul.dll` inside
  `Gecko.Xpcom.Initialize -> CreateWindowlessBrowser` while building the splash screen.
  Paratext never starts. The pref names exist in that Gecko; the values kill it.
- **Wine's Wayland driver (`Graphics = wayland`).** The main menu strip *did* appear (which is
  how the decoration cause was found), but: `System.OverflowException` in
  `InputLanguage.get_Culture()` from `WM_INPUTLANGCHANGEREQUEST` (a third bug in the same .NET
  path as the original crash), list popups cannot be clicked, and text scaling compounds to
  ~1.94x. Not usable.
- **Editing `kwinrc [Xwayland] Scale`.** It is a derived value KWin rewrites on startup.
  The control is `kdeglobals [KScreen] XwaylandClientsScale` (from KWin source,
  `Workspace::updateXwaylandScale`), and it applies live when written with
  `kwriteconfig6 --notify`.
- **Paratext's own "DisableHardwareAcceleration" setting** does not stop the Gecko D3D11
  swapchains. Not the lever.

## Multi-monitor on Wayland (KDE Plasma 6.7.5)

Setup: laptop eDP-1 2560x1600 at scale 1.75 (primary, placed at +400,+1440); external HDMI-A-1
2560x1440 at scale 1 at +0,+0.

1. Default KDE (`XwaylandClientsScale=true`): X11 apps see the external as 4480x2520 and
   `Xft.dpi=168`. Wine windows on it are drawn 1.75x and shrunk; menus and popups on that
   monitor do not respond. On the laptop everything works.
2. `kwriteconfig6 --file kdeglobals --group KScreen --key XwaylandClientsScale --type bool --notify false`
   -> X11 sees the external at its real 2560x1440, `Xft.dpi=96`, laptop presented at its
   logical 1463x914 and upscaled. **Clicks on the external still died** for a Paratext
   subwindow dragged there. So scaling alone was not the whole story.
3. The X primary was the laptop at a non-origin position. Wine maps the X primary to Windows
   (0,0), putting the external at (-400,-1440) in Windows coordinates. Made the external
   primary with `kscreen-doctor output.HDMI-A-1.primary`. **Result not yet verified** at the
   time of writing.

Note the trade-off of item 2: with two monitors at different scales there is no single Wine
`LogPixels` that is right on both; 168 fits the external, is oversized on the laptop.

Fallback that avoids the whole class: a **Plasma (X11) session** (`dnf install
plasma-workspace-x11`), being tested next. X11 has one desktop scale for all monitors.

## Getting evidence instead of guessing

- `tools/launch-paratext-logged.sh` launches through Bottles with Wine's stderr captured to
  `~/paratext-wine-logs/`, and a header recording runner, overrides, DPI and X geometry.
- The bottle has `WINEDEBUG=+seh,+loaddll,err+all,fixme-all` in its environment variables
  (honoured by Bottles) and `ShowCrashDialog=0` with the default `winedbg --auto`, so a hard
  crash prints the module and a text backtrace with no clicking.
- `tools/analyze-paratext-log.sh` summarises a log: D3D path in use, unhandled exceptions with
  the module they landed in, the managed .NET stack Wine's eventlog captured, last UI events.
- `bottles-cli shell -b Paratext -i 'cmd /c C:/probe/x.bat'` is the reliable way to run
  something inside the bottle and see its output; `bottles-cli run` was not verified to
  stream anything back.
- Paratext's own log: `drive_c/users/<you>/AppData/Local/Paratext95/ParatextLog.log`. Hard
  crashes never reach it; only Wine's stderr sees those.

## Not yet known

- Whether making the external the primary monitor fixes clicks on it under Wayland.
- How Paratext behaves under Plasma (X11).
- Whether `Decorated=N` breaks anything else (dialog placement looked fine).
- Whether Logos (separate prefix, `LogPixels=168` set) is affected by any of the above.
