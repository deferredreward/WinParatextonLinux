# Draft: Wine bug report — no mouse input to windows on a monitor at negative virtual-screen coordinates (XWayland)

Status: DRAFT, not yet filed. Fill in the `[ ]` items, attach `tools/TinyWin.cs`, then file at
https://bugs.winehq.org (product Wine, component winex11.drv). Check for duplicates first:
search "negative coordinates" "secondary monitor" "no mouse input" xwayland.

## Summary

With two monitors where the X primary is not the top-left-most (so the other monitor has
negative coordinates in Wine's virtual screen), a Wine window moved onto that monitor stops
receiving mouse input and stops repainting. X delivers the events to Wine (`+event` shows
`ButtonPress`/`MotionNotify` for the window, and Wine keeps processing events on the app
thread), and the app's own `WM_MOVE` shows a correct window rectangle at negative Y, but the
app never receives `WM_LBUTTONDOWN`/`WM_MOUSEMOVE`. Making the top-left monitor the primary
(all coordinates non-negative) fixes it immediately, with no other change.

## Environment

- Wine 11.17 (Staging), Kron4ek build `wine-11.17-staging-amd64`, via Bottles 67.3 (Flatpak)
- Fedora 44, KDE Plasma 6.7.5 Wayland session, XWayland (`Xwayland :0 -rootless`), KWin
- Monitors: laptop eDP-1 2560x1600 at X position +400+1440 (X primary in the failing case);
  external HDMI-A-1 2560x1440 at +0+0 (above the laptop)
- Both outputs at compositor scale 1 during the decisive runs (`XwaylandClientsScale` default;
  `Xft.dpi 96`). Wine `LogPixels` 168 (also seen at default 96 earlier in the day).
- `HKCU\Software\Wine\X11 Driver\Decorated=N` (also reproduced earlier with decorations on)
- Intel Arc 130V/140V (Lunar Lake), Mesa; irrelevant (no D3D involved, WinForms window)
- [ ] `wine --version` exact string; [ ] Xwayland version (`Xwayland -version`)

## Steps to reproduce

1. Arrange two monitors so the primary is NOT top-left (e.g. external above the laptop, laptop
   primary). `xrandr` shows the primary at a positive offset, e.g. `eDP-1 ... 2560x1600+400+1440`.
2. Build and run the attached `TinyWin.cs` (.NET Framework WinForms; `csc.exe /target:exe
   /r:System.Windows.Forms.dll /r:System.Drawing.dll TinyWin.cs`). It logs every click with
   `Screen.FromControl` and every `WM_MOVE`.
3. Click inside the window on the primary monitor: clicks are logged.
4. Drag the window onto the other monitor; click inside it.

## Result

No clicks logged on the non-primary monitor; the window also stops repainting. `WM_MOVE` shows
the window rect there with negative Y (e.g. `{X=60,Y=-472,W=700,H=300}` on `\\.\DISPLAY2`).
`WINEDEBUG=+event`: `ButtonPress`/`ButtonRelease`/`MotionNotify` for the window's X id keep
arriving and `X11DRV_ProcessEvents` keeps running on the same thread. No `ConfigureNotify`
storm (none after the drag ends).

## Expected

Clicks delivered regardless of which monitor is primary.

## Control

`kscreen-doctor output.HDMI-A-1.primary` (make the top-left monitor primary, nothing else
changed, same wineserver session): the same window logs clicks on both monitors, moved back
and forth. Reverting the primary makes it fail again. A plain Xt client (`xmessage`) placed on
the non-primary monitor takes clicks in both configurations.

## Notes

- Real-world impact: Paratext 9.5 (.NET 4.8 WinForms + embedded Gecko) is unusable on the
  second monitor in this layout; menus and toolbar go dead.
- Not DPI-related: reproduced with `LogPixels` 96 and 168.
- Not scale-related: reproduced with the compositor at uniform scale and with mixed scale.
- Suspect: position-based hardware-message routing (`WindowFromPoint` at dispatch) or the
  X-root-to-virtual-screen mapping for negative coordinates in winex11/win32u.

## Attachments

- `tools/TinyWin.cs` (reproducer, ~40 lines)
- [ ] `+event` trace excerpt around the move (`paratext-wine-logs/tinywin*.log`)
