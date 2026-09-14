# STATE

What this project is and what anyone picking it up needs to know. Not a log; history lives
in commits.

## Goal

A reproducible recipe for running Windows Paratext 9.5+ on Fedora Linux (Bottles first,
plain Wine as fallback), published here for other Linux users.

## Gotchas

- The startup crash `Culture is not supported ... 0 (0x0000)` is a Wine bug, fixed in Wine
  11.2 (commit 3d3a95f474). Nothing in the registry, locale env vars, or Paratext settings
  can work around it on older Wine. Do not spend time on `Keyboard Layout\Preload` or
  DLL patching again.
- Bottles' house runners (soda/caffe/vaniglia) lag upstream Wine badly and all predate the
  fix as of 2026-09-14. Use a `kron4ek-wine-11.x-staging` runner from Bottles' catalog
  (stable channel), or WineHQ's `winehq-staging` Fedora package.
- Second trap right behind the first: upstream Wine has no
  `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts` keys and .NET's
  `InputLanguage.LayoutName` dereferences that key unchecked (Wine bug 47439, fixed only in
  wine-staging). Staging builds create the keys; on plain builds import
  `tools/keyboard-layouts-00000409.reg`.
- Nobody has published a working Paratext-under-Wine recipe (paratext.org says Wine and
  CrossOver do not work; CodeWeavers rates it "Installs, Will Not Run"). Expect more gaps
  after the keyboard ones.
- Fedora's own `wine` rpm is 11.0 on every branch as of 2026-09-14; also too old.
- Paratext 9.5 is 64-bit only; use a win64 prefix.
- `tools/InputLangCheck.cs` reproduces the crash in isolation; run it before blaming Paratext.

## Open questions

- Does switching the runner on an existing bottle keep dotnet48 working, or is a fresh
  bottle needed?
- What is the next failure after the keyboard crash? Unknown until tried.

## Human blockers

- Testing needs the Fedora machine (Bottles + the existing Paratext bottle); the WSL side
  can only research.
