# Wine bug: no mouse input to windows on a monitor at negative virtual-screen coordinates

**This is already reported: WineHQ bug #51166** (2021-05-22, `winex11.drv`, still UNCONFIRMED as of
2026-09-14): "wine doesn't handle multiple monitors correctly" -- the reporter switched primary
monitor, moved windows to the other screen with the keyboard, "and they became mouse-insensitive
... even ... winecfg and taskmgr". Same bug. Do **not** file a new one; add the confirming comment
below to https://bugs.winehq.org/show_bug.cgi?id=51166, attach `tools/TinyWin.cs` and
`docs/attachments/tinywin-event-excerpt.log`, and set the version field to 11.17 if allowed.

Filing requires a WineHQ Bugzilla account (https://bugs.winehq.org/createaccount.cgi). The text
below contains no personal information: versions, hardware model, and the reproduction only.

---

## Comment to paste on bug #51166

Still present in wine-11.17 (Staging) on XWayland, and reproducible on demand. Mechanism
narrowed down: it is about the monitor having **negative coordinates in Wine's virtual screen**
(i.e. sitting above or left of the X primary monitor), not about switching monitors as such.

Environment: Fedora 44, KDE Plasma/KWin 6.7.5 Wayland session, Xwayland 24.1.13, Mesa 26.1.8,
Intel Arc 130V/140V (Lunar Lake). Wine 11.17 Staging (Kron4ek build) in a Bottles prefix,
win64, `Decorated=N` (also reproduced with decorations on). Two monitors: laptop 2560x1600 at
X position +400+1440 (X primary), external 2560x1440 at +0+0 (above it). Both outputs at
compositor scale 1 in the decisive runs; also reproduced with mixed scales, and with Wine
`LogPixels` 96 and 168 -- neither DPI nor compositor scaling affects it.

Reproducer (attached TinyWin.cs, ~40 lines, .NET Framework WinForms; build with
`csc.exe /target:exe /r:System.Windows.Forms.dll /r:System.Drawing.dll TinyWin.cs`): a window
that logs every click (with `Screen.FromControl`) and every WM_MOVE.

1. Laptop = X primary (`xrandr`: `eDP-1 ... primary 2560x1600+400+1440`,
   `HDMI-A-1 ... 2560x1440+0+0`). Wine reports the external as `\\.\DISPLAY2` at negative Y.
2. Click inside the window on the laptop: clicks logged.
3. Drag the window onto the external monitor and click: **no clicks logged, window stops
   repainting.** WM_MOVE shows a sane rect there, e.g. `{X=60,Y=-472,W=700,H=300}` on DISPLAY2.
4. `WINEDEBUG=+event`: `ButtonPress`/`ButtonRelease`/`MotionNotify` for the window's X id keep
   arriving (10 presses, 536 motions in one run) and `X11DRV_ProcessEvents` keeps running on the
   app thread. No ConfigureNotify storm (none after the drag ends). So X delivers the input to
   Wine and Wine does not dispatch it to the window.
5. Control, same wineserver session: make the external the X primary
   (`kscreen-doctor output.HDMI-A-1.primary`), nothing else changed -> all coordinates
   non-negative -> the same window logs clicks on **both** monitors, moved back and forth (9/9).
   Revert the primary -> fails again on the external (3 clicks on the laptop, 0 on the external,
   78 WM_MOVE at negative Y). A plain Xt client (`xmessage`) on the external takes clicks in both
   configurations.

Real-world impact: Paratext 9.5 (.NET 4.8 WinForms) is unusable on the second monitor in this
layout (menus and toolbar dead). Workaround: make the top-left-most monitor the X primary.

Suspect: position-based hardware-message routing (`WindowFromPoint` at dispatch) or the
root-to-virtual-screen mapping for negative coordinates in win32u/winex11. Happy to test patches.

---

## Fallback: fields for a NEW bug (only if maintainers ask for one)

- Product: Wine -- Component: winex11.drv -- Version: 11.17 -- Hardware: x86-64 -- OS: Linux
- Summary: `No mouse input to windows on a monitor at negative virtual-screen coordinates
  (monitor above/left of X primary), XWayland`
- Description: the comment above. Attachments: `tools/TinyWin.cs`,
  `docs/attachments/tinywin-event-excerpt.log`.
