# STATE

What this project is and what anyone picking it up needs to know. Not a log; history lives
in commits.

## Goal

A reproducible recipe for running Windows Paratext 9.5+ on Fedora Linux (Bottles first,
plain Wine as fallback), published here for other Linux users.

## Status: working

As of 2026-09-14, Paratext 9.5 starts and opens a text on Fedora 44 + Bottles 67.3 with the
`kron4ek-wine-11.17-staging-amd64` runner. The full verified procedure is
`docs/verified-recipe-fedora.md`. The startup crash is solved; what remains is breadth of
testing, not a known blocker.

## Gotchas

- The startup crash `Culture is not supported ... 0 (0x0000)` is a Wine bug, fixed in Wine
  11.2 (commit 3d3a95f474). Nothing in the registry, locale env vars, or Paratext settings
  can work around it on older Wine. Do not spend time on `Keyboard Layout\Preload` or
  DLL patching again.
- Bottles' house runners (soda/caffe/vaniglia) lag upstream Wine badly and all predate the
  fix. Fedora's own `wine` rpm is 11.0 on every branch. Use a staging Kron4ek runner.
- Second trap right behind the first: upstream Wine has no
  `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts` keys and .NET's
  `InputLanguage.LayoutName` dereferences that key unchecked (Wine bug 47439). The staging
  runner creates ~200 empty keys and that is enough; `tools/keyboard-layouts-00000409.reg`
  is only needed on a non-staging build. Confirmed unnecessary on staging.
- **`wineboot -u` after a runner switch took ~35 minutes** (.NET `mscorsvw` rebuilding native
  images). It is not hung. Do not interrupt it.
- During that update a browser tab opens on Microsoft's "application not started" page for
  `processName=rundll32.exe`. It is the 32-bit WoW64 wine.inf step; Paratext is 64-bit only
  and this is harmless. `wineboot -u` still exits 0.
- Switching the runner on the existing bottle **did not** damage `dotnet48`. A fresh bottle
  was not needed. (This was the main open question; now answered.)
- `bottles-cli shell -i` eats backslashes in Windows paths, and `csc.exe` mis-parses forward
  slashes. Drive the compiler from a `.bat` file.
- `bottles-cli edit --runner` does not itself run the prefix update. Run `wineboot -u` after.
- Paratext 9.5 is 64-bit only; use a win64 prefix.
- `tools/InputLangCheck.cs` reproduces the crash in isolation; run it before blaming Paratext.
  It is the fastest way to grade any new Wine build.
- Nobody else has published a working Paratext-under-Wine recipe (paratext.org says Wine and
  CrossOver do not work; CodeWeavers rates it "Installs, Will Not Run"). This repo is the
  first write-up, so expect to be the one finding the next gap.

## Open questions

- How much of Paratext actually works beyond opening a text: Send/Receive on the new runner,
  plugins, the embedded Firefox panes, printing, spell check, non-Latin keyboards/IME.
- Whether a non-staging runner plus `tools/keyboard-layouts-00000409.reg` is equivalent.
  Untested — staging worked, so it was never needed.
- Whether a from-scratch install on the staging runner works as smoothly as the upgrade path
  did. The verified recipe documents an existing bottle being switched over.

## Human blockers

- None outstanding. Testing happens on the Fedora machine with the `Paratext` bottle.
