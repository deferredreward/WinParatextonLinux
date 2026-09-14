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
| Too small on a 2560x1440 monitor | Wine renders at 96 DPI | `HKCU\Control Panel\Desktop\LogPixels = 168` (**and** `custom_dpi: 168` in `bottle.yml`, or Bottles reverts it). **Takes effect only after every Wine process in the bottle has exited** (`wineserver -k`): Wine caches the system DPI per wineserver session, verified by a probe still reporting 1.75x-scaled monitors after the registry said 96. | Yes |

## Things that made it worse (do not repeat)

- **Splash-screen crash: `AccessViolationException` in `xul.dll` inside
  `Gecko.Xpcom.Initialize -> CreateWindowlessBrowser`.** Seen three times (14:45, 15:08,
  15:49), each the **first launch after a display configuration change** (XWayland scale,
  monitor scale, primary monitor). Each time the **next launch succeeded** (14:52, 15:12,
  15:50 -- the last one 30 s after its crash). In the crashing runs Gecko's first widget
  immediately pulled `opengl32 -> wined3d -> dxgi -> d3d11` and faulted at the same
  instruction; in the good runs it went `xul.dll -> dwrite.dll` and never touched D3D at init.
  Inference (not proven): Gecko re-probes the graphics stack when the display configuration it
  cached has changed, the probe through wined3d dereferences NULL, and the crash leaves state
  that makes the next launch skip the probe. **Rule: after changing monitors, scale or primary,
  expect the first Paratext launch to die at the splash; launch again.** (The first write-up
  blamed a Gecko `user.js`; that was wrong -- the crash recurred with the file gone.)
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
   subwindow dragged there. Side effects: every Wine window on the laptop became ~3x
   (Wine's 1.75x DPI, then KWin's 1.75x upscale), Logos misbehaved, and the maximized
   Paratext window flickered. **Reverted to the default (`true`).** Not worth it.
3. The X primary was the laptop at a non-origin position. Wine maps the X primary to Windows
   (0,0), putting the external at (-400,-1440) in Windows coordinates. Made the external
   primary with `kscreen-doctor output.HDMI-A-1.primary`. **Tested: did not help.** Clicks
   still died on the external, and the window then stayed dead even after being moved back
   to the laptop. Reverted. Not the cause.
4. Also observed with `XwaylandClientsScale=false`: the maximized main window flickers /
   shakes on the laptop panel, where KWin is upscaling the X window 1.75x. Not investigated;
   the X11 session test comes first.

5. Both outputs set to the **same scale (1)** with `kscreen-doctor output.eDP-1.scale.1`:
   X11 sees both monitors at physical pixels (2960x3040 screen, `Xft.dpi=96`, Xwayland
   `Scale=1`), so KWin never rescales a window when it crosses outputs. Paratext launched
   (after the display had settled) and worked on the laptop; **moved fully onto the external
   it stopped taking input again.** Scaling is not the cause.

Conclusion for Wayland (KDE Plasma 6.7.5, this laptop + HDMI monitor): a Wine window on the
external monitor does not take input, in every configuration tried -- default mixed scale,
`XwaylandClientsScale=false`, external as primary, and uniform scale. It works fully on the
laptop panel. **It is Wine, not KDE:** a plain X11 program (`xmessage`) placed on the
external monitor took its button click normally, twice, while a Wine window there did not.
Under uniform scale the Wine window comes back to life when moved back to the laptop (under
the default mixed scale it stayed dead). `tools/ScreenProbe.cs` shows Wine knows both
monitors (`SM_CMONITORS=2`, external at negative coordinates, all sizes divided by the DPI
factor for this DPI-unaware process).

**Dead end, recorded so nobody repeats it:** polling `GetCursorPos`/`GetAsyncKeyState` from a
windowless probe (`tools/CursorProbe.cs`, `tools/ClickProbe.cs`) cannot measure this on a
Wayland session. Rootless XWayland only learns the pointer position while it is over an X11
window; over the (Wayland-native) KDE desktop the X pointer is frozen and clicks are invisible.
The probes therefore reported a frozen pointer and no clicks regardless of the bug. The Wine
X11 driver registry has no pointer-grab settings (`GrabFullscreen`, `GrabPointer` unset;
Bottles `fullscreen_capture`/`take_focus` off), so a configured grab is ruled out.

The valid experiment is a Wine *window* (`tools/TinyWin.cs`) dragged to the external monitor
and clicked, run with `WINEDEBUG=+event`. **Result (168 DPI session, laptop primary, uniform
scale):** after the move Wine received 10 `ButtonPress`, 10 `ButtonRelease` and 536
`MotionNotify` for the window and kept processing events on the app's thread; the user saw the
window stop responding. (The first version of the test window could not see clicks at all --
its fill label swallowed them and only the form was listening -- so its "0 clicks" figure is
**not evidence**. v2 listens on both.) There was no `ConfigureNotify` storm (all 236
came during the drag, none after). Wine's own record of the window was sane: `WM_MOVE` reported
`{X=316,Y=-339,W=700,H=300}` on `\\.\DISPLAY2`. So the X server delivers input to Wine and Wine
knows where the window is; whether Wine dispatches the input to the app is what the v2 test
window measures. Suspects: position-based routing (`WindowFromPoint`) for a window on a monitor
at negative coordinates, and DPI virtualization (168/96).

**Re-run in a fresh wineserver session, intended as a 96 DPI test, turned out to still be
at 168** (the session read `LogPixels=0xa8`; an unverified `reg add 96` had not taken). Same
result as before per the user: window unresponsive on the external; `WM_MOVE` at
`{X=354,Y=-339}` on `DISPLAY2`. (Click count from that v1 window is void, see above.) That is a reproduction at 168, **not** a DPI test. The 96 DPI
test is still pending and needs: `reg add ... LogPixels 96` *verified by `reg query`*, then every
Wine process in the bottle gone (`wineserver -k`), then launch.

**External as primary (all-positive Wine coordinates), same 168 session, v2 test window:**
clicks were delivered on **both** monitors, moved back and forth -- e.g. `CLICK 3 ... window=
{X=0,Y=0} on=DISPLAY1` (external, now primary) and `CLICK 5 ... window={X=523,Y=1020}
on=DISPLAY2` (laptop), nine clicks logged, none lost. **Control, laptop primary again, same
window, same session:** clicks delivered on the laptop, window dead on the external (user
confirmed; window positions there logged at negative Y). One variable, opposite result.

### Conclusion (verified)

**Wine (11.17 staging, winex11 on XWayland) does not route mouse input to a window on a
monitor whose virtual-screen coordinates are negative.** Wine puts the X primary monitor at
(0,0); a monitor above or to the left of it gets negative coordinates and its windows go dead
(X still delivers the events; Wine does not dispatch them; the window stops repainting).
Everything else tried today -- XWayland scale settings, uniform monitor scale, DPI -- was a
red herring for this symptom.

**Fix on Wayland:** make the top-left-most monitor the primary so every monitor has
non-negative coordinates: `kscreen-doctor output.HDMI-A-1.primary` (System Settings >
Display > Primary). Applied and persisted here. **Paratext confirmed by the user on both
monitors** (menu, toolbar, resource list, dragging text windows between screens). Laptop scale
then restored to 1.75 with the external primary; Paratext under that mixed scale not yet re-tested.

This is a Wine bug worth reporting with `tools/TinyWin.cs` + this layout as the reproducer. Workable answer on Wayland today:
keep Paratext on one monitor. Likely better: a Plasma (X11) session.

Side notes from the same session: a maximized Paratext window cannot be dragged (no WM title
bar) -- KWin `Meta+PgUp` un-maximizes, `Meta+Shift+Right`/`Left` (arrow keys) sends a window
to the next screen, `Meta+drag` moves; KWin zoom is `Meta+=` / `Meta+-` / `Meta+0` (easy to hit
by accident). Paratext's black title strip can be left painted on the old monitor after a
move; repaint artifact only.

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

- How Paratext behaves under Plasma (X11).
- Whether `Decorated=N` breaks anything else (dialog placement looked fine).
- Logos (separate prefix): `LogPixels=168` verified to enlarge it as intended; nothing else tested.
