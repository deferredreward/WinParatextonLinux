# Paratext 9.5+ on Linux (Fedora) via Wine

Notes and a working recipe for running Windows Paratext 9.5 or newer on Linux, since SIL
dropped native Linux builds after 9.4.

## Status (2026-09-14): runs; usable on one monitor

Paratext 9.5 starts, shows its main menu, downloads and installs resources, and opens OT and
NT texts without crashing — on Fedora 44 with Bottles (Flatpak), a `wine-11.17 (Staging)`
runner, DXVK turned off, and Wine drawing its own window frame. A second monitor under a
Wayland session is still being worked out; see `STATE.md`.

The startup crash everyone hits (`Culture is not supported ... 0 (0x0000) is an invalid
culture identifier`) is not a Paratext problem and not a configuration problem. It is two Wine
bugs in a row in the keyboard-layout path:

1. **Wine bug 40435** — `SystemParametersInfo(SPI_GETDEFAULTINPUTLANG)` returned success
   without writing the layout handle, so .NET built `CultureInfo(0)` and threw. Fixed in
   wine-11.2 (Feb 2026).
2. **Wine bug 47439** — no `HKLM\...\Control\Keyboard Layouts` keys exist upstream, and .NET's
   `InputLanguage.LayoutName` dereferences them unchecked. Fixed only in wine-staging.

So the fix is one thing: **run a wine-staging build of 11.2 or newer.** Bottles' house runners
(Soda 11.0, Caffe 10.0, Vaniglia 10.19) and Fedora's own `wine` package are all too old.
`kron4ek-wine-11.17-staging-amd64`, already in Bottles' runner catalog, clears both.

Nothing in the registry, in `LANG`/`LC_ALL`, in the bottle's language setting, or in Paratext
itself can work around this on an older Wine — on the broken versions the value is never
copied out of Wine in the first place.

## Start here

**`docs/verified-recipe-fedora.md`** — the procedure that was actually run, with the expected
output at each step, how long the slow step takes, and which alarming-looking errors are
harmless.

## Files

- `docs/verified-recipe-fedora.md`: getting it to start. Read this first.
- `docs/display-and-crash-findings-2026-09-14.md`: getting it usable — DXVK, the hidden main
  menu, multi-monitor on Wayland, and the things that made it worse. Read this second.
- `docs/research-2026-09-14-culture-error.md`: the evidence trail — Wine source, the fixing
  commit, the .NET and libpalaso code, and why the obvious workarounds cannot work.
- `docs/fedora-plan.md`: the plan as written before the attempt. Kept for the reasoning;
  superseded by the verified recipe.
- `tools/InputLangCheck.cs`: 46-line .NET probe that reproduces the crash without Paratext.
  Grades any Wine build in seconds — run it before blaming Paratext.
- `tools/keyboard-layouts-00000409.reg`: registry fallback for non-staging Wine builds. Not
  needed on a staging runner.
- `tools/launch-paratext-logged.sh` / `tools/analyze-paratext-log.sh`: launch with Wine's
  stderr captured, then turn a crash log into module + backtrace + .NET stack.
- `STATE.md`: durable gotchas and open questions for anyone picking this up.

## What is not yet known

Opening a text works. Send/Receive on the new runner, plugins, the embedded Firefox panes,
printing, spell check, and non-Latin keyboard/IME input have not been exercised yet. If you
try them, please report what you find.
