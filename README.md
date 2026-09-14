# Paratext 9.5+ on Linux (Fedora) via Wine

Notes and a working recipe for running Windows Paratext 9.5 or newer on Linux, since SIL
dropped native Linux builds after 9.4. Work in progress; nothing here is verified end to end
yet.

## Status (2026-09-14)

- Paratext 9.5 installs and registers under Bottles (Flatpak) on Fedora with `dotnet48` and
  `gdiplus`; Send/Receive works.
- Startup then dies with `Culture is not supported ... 0 (0x0000) is an invalid culture
  identifier` from the keyboard-layout code.
- Root cause found: a Wine bug (fixed in Wine 11.2, February 2026) where
  `SystemParametersInfo(SPI_GETDEFAULTINPUTLANG)` never returned the layout handle. Every
  Bottles house runner (Soda 11.0, Caffe 10.0, Vaniglia 10.19) and Fedora's own `wine` 11.0
  package still have the bug. Kron4ek 11.17 runners in Bottles' catalog, and WineHQ's
  `wine-staging`/`wine-devel` packages for Fedora, have the fix.
- A second, adjacent bug (Wine bug 47439, missing `Keyboard Layouts` registry keys) is
  fixed only in wine-staging builds, so the staging flavour of those runners is the one to
  use.
- Next: switch the bottle's runner and confirm. See `docs/fedora-plan.md`.

## Files

- `docs/research-2026-09-14-culture-error.md`: the evidence trail for the crash and the fix.
- `docs/fedora-plan.md`: step-by-step plan with a pass/fail check per step.
- `tools/InputLangCheck.cs`: 40-line .NET probe that reproduces the crash without Paratext,
  so a Wine build can be checked in seconds.
- `tools/keyboard-layouts-00000409.reg`: registry fallback for non-staging Wine builds.
- `STATE.md`: durable gotchas and open questions for anyone (human or agent) picking this up.
