# Research record: "Culture is not supported ... 0 (0x0000)" at Paratext startup under Wine

Date: 2026-09-14. Researched from a WSL session before the Fedora attempt. Nothing here has
been run on Fedora yet; see `docs/fedora-plan.md` for what to actually do.

## The error

```
Culture is not supported.
Parameter name: culture
0 (0x0000) is an invalid culture identifier.
  at System.Globalization.CultureInfo.InitializeFromCultureId(Int32 culture, Boolean useUserOverride)
  at System.Windows.Forms.InputLanguage.get_Culture()
  at SIL.Windows.Forms.Keyboarding.Windows.InputLanguageWrapper..ctor(InputLanguage lang)
  at SIL.Windows.Forms.Keyboarding.Windows.WindowsKeyboardSwitchingAdapter.get_DefaultKeyboard()
  at Paratext.Base.Keyboarding.KeyboardHelper.Initialize()
  at Paratext.Program.ParatextSetup()
  at Paratext.Program.Main(String[] args)
```

Setup that produced it: Fedora Linux, Bottles (Flatpak), a Soda/Caffe runner (Wine 11.0 / 10.0
based), `dotnet48` + `gdiplus` installed, Paratext 9.5 installed, user registered, projects
downloaded via Send/Receive. Crash happens when the main window starts.

## Root cause (verified in Wine source)

Wine's implementation of `SystemParametersInfo(SPI_GETDEFAULTINPUTLANG)` returned TRUE but
**never wrote the keyboard-layout handle into the caller's buffer**. The .NET Framework's
`InputLanguage.DefaultInputLanguage` does not check the return value and does not fall back to
`GetKeyboardLayout(0)`, so it wraps a zero handle. `InputLanguage.Culture` is
`new CultureInfo((int)handle & 0xFFFF)` = `new CultureInfo(0)`, and `CultureInfo` hard-codes
LCID 0 (`LOCALE_NEUTRAL`) to throw `CultureNotFoundException`. That is the exact message above.

The registry (`HKCU\Keyboard Layout\Preload`, `Control Panel\International`), the bottle's
language setting, `LANG`/`LC_ALL`, and X11 vs Wayland are all irrelevant: the value is never
copied out, so nothing upstream of that line can change the result. This is why the earlier
registry checks looked correct and still did nothing.

### Evidence

- Wine 10.0 and 11.1, `dlls/win32u/sysparams.c` (`NtUserSystemParametersInfo`), fetched and
  diffed 2026-09-14:
  ```c
  case SPI_GETDEFAULTINPUTLANG:
      ret = NtUserGetKeyboardLayout(0) != 0;
      break;
  ```
  https://raw.githubusercontent.com/wine-mirror/wine/wine-11.1/dlls/win32u/sysparams.c (line ~6591)
- Fix: commit `3d3a95f474` "win32u: Actually return HKL for SPI_GETDEFAULTINPUTLANG."
  (2026-02-03, Wine-Bug 40435, MR !10015). First release tag containing it: **wine-11.2**.
  https://github.com/wine-mirror/wine/commit/3d3a95f474
  https://gitlab.winehq.org/wine/wine/-/merge_requests/10015
  ```c
  case SPI_GETDEFAULTINPUTLANG:
      if (ptr)
      {
          HKL layout = NtUserGetKeyboardLayout(0);
          *(HKL*)ptr = layout;
          ret = layout != 0;
      }
      break;
  ```
- Companion fix for 32-bit apps on new-WoW64 builds: `3b7bf0647c` "wow64win:
  SPI_GETDEFAULTINPUTLANG result is pointer-sized." (Wine-Bug 59404, MR !10135), first in
  **wine-11.3**. Paratext 9.5 is 64-bit only (paratext.org system requirements: only 9.0 and 8
  run on 32-bit Windows), so 11.2 is sufficient; any current build is well past both.
- .NET Framework `InputLanguage` (4.8 sources as imported into dotnet/winforms first commit):
  https://raw.githubusercontent.com/dotnet/winforms/195f89af79d550c2da1711c45c379efd63519ac1/src/System.Windows.Forms/src/System/Windows/Forms/InputLanguage.cs
  ```csharp
  public CultureInfo Culture { get { return new CultureInfo((int)handle & 0xFFFF); } }
  public static InputLanguage DefaultInputLanguage { get {
      IntPtr[] data = new IntPtr[1];
      UnsafeNativeMethods.SystemParametersInfo(NativeMethods.SPI_GETDEFAULTINPUTLANG, 0, data, 0);
      return new InputLanguage(data[0]); } }
  ```
- mscorlib `CultureInfo.InitializeFromCultureId`: LCID 0 is in the list that throws
  `Argument_CultureNotSupported`. (`LOCALE_INVARIANT` is 0x007F, not 0, so there is no way to
  make culture 0 succeed.)
  https://raw.githubusercontent.com/microsoft/referencesource/main/mscorlib/system/globalization/cultureinfo.cs
- libpalaso `WindowsKeyboardSwitchingAdapter.DefaultKeyboard` (unchanged since 2018, unguarded
  on every tag through master):
  ```csharp
  public KeyboardDescription DefaultKeyboard =>
      WinKeyboardUtils.GetKeyboardDescription(InputLanguage.DefaultInputLanguage.Interface());
  ```
  https://raw.githubusercontent.com/sillsdev/libpalaso/master/SIL.Windows.Forms.Keyboarding/Windows/WindowsKeyboardSwitchingAdapter.cs
  libpalaso has no Wine detection and no env/registry switch that changes keyboard adaptor
  selection on Windows. Keyman adaptor is skipped when Keyman is not installed. A newer or
  older libpalaso would not help.
- Paratext's `KeyboardHelper` is closed source; no documented command-line flag, app.config
  setting, or registry value disables keyboard init.
- Wine's `NtUserGetKeyboardLayout(0)` itself always returns `MAKELONG(userLCID, userLCID)`
  when no layout was activated, and the user LCID falls back to en-US (0x0409) when
  `LANG`/`LC_ALL` is unset, `C`, `C.UTF-8`, or unknown (`dlls/ntdll/unix/env.c` `init_locale`).
  So once the value is actually copied out, it is 0x04090409, which .NET accepts.

## Second, adjacent bug: `LayoutName` and the missing `Keyboard Layouts` registry keys

libpalaso's wrapper reads three properties on one line: `Culture`, `Handle`, `LayoutName`.
Once `Culture` stops throwing, .NET evaluates `LayoutName`, which for a plain layout
(device word == language word, e.g. 0x04090409) does:

```csharp
RegistryKey key = Registry.LocalMachine.OpenSubKey(
    "SYSTEM\\CurrentControlSet\\Control\\Keyboard Layouts\\" + keyName);   // "00000409"
layoutName = GetLocalizedKeyboardLayoutName(key.GetValue("Layout Display Name") as string);
```

`key` is used with no null check. Upstream Wine's registry template (`loader/wine.inf.in`,
checked at tag wine-11.17) contains **no** `Keyboard Layouts` keys, so this is a
`NullReferenceException` on every upstream-based Wine. This is Wine bug 47439
(https://bugs.winehq.org/show_bug.cgi?id=47439, 2019, status STAGED): "Multiple .NET 4.x
applications using System.Windows.Forms.InputLanguage.get_LayoutName() crash due to
missing registry data." The fix lives only in wine-staging's `loader-KeyboardLayouts`
patchset (https://github.com/wine-staging/wine-staging/tree/master/patches/loader-KeyboardLayouts),
which creates ~200 empty `Keyboard Layouts\0000xxxx` keys. With the key present but empty,
.NET's helpers tolerate the nulls and return "Unknown", which is fine.

Consequences:
- Prefer a **wine-staging based** build >= 11.2 (Bottles: `kron4ek-wine-11.17-staging-amd64`).
- On a plain build, import `tools/keyboard-layouts-00000409.reg` first (creates the
  `00000409` key with `Layout Text`/`Layout File`). Soda/Caffe do not carry the staging
  patch either, but that never mattered because they crash one property earlier.

## Field reports (what other people have hit)

- No public report pairs this exact stack with a fix under Wine. That is consistent with
  the fix only landing in Wine 11.2 (February 2026).
- One WineHQ forum thread shows the identical message for a different .NET app
  (SpaceClaim): https://forum.winehq.org/viewtopic.php?t=27634 (Cloudflare-walled to
  fetchers; unread).
- Same exception text on native Windows comes from odd layout ids (4096/3072), e.g.
  dotnet/winforms #9191; not applicable.
- Paratext's own position: Linux support ended after 9.3
  (https://paratext.org/download/download-paratext-for-linux/); the Mac FAQ says they found
  no CrossOver/Wine setup that works and recommend a Windows VM
  (https://paratext.org/ufaqs/paratext-on-a-mac/, 2023). CodeWeavers' compatibility entry
  rates Paratext "Installs, Will Not Run" on Mac (CrossOver 21.2, outdated) and unrated on
  Linux, no recipe (https://www.codeweavers.com/compatibility/crossover/paratext). So there
  is no vendor-supported Wine path to copy from; this repo would be the first write-up.
- Bloom (another libpalaso app) under CrossOver Mac, 2022: "launches briefly, then
  disappears", unresolved
  (https://community.software.sil.org/t/run-bloom-with-crossover-wine/6241). Plausibly the
  same bug.
- Bottles facts (from bottlesdevs/Bottles source): bottle "Language" = System sets nothing,
  any other value sets `LC_ALL=<lang>.UTF-8`; native Wayland is off per bottle by default
  (Wine runs on XWayland, so winex11.drv); env vars and registry are editable per bottle.

## Why the earlier approaches did not work

- Registry keyboard-layout keys: not consulted on the failing path (see above).
- DLL patching: would have needed to skip `DefaultKeyboard` in a strong-named/signed SIL
  assembly; not pursued further.

## Fix options, ranked

1. **Use a wine-staging based Wine >= 11.2 runner in Bottles.** Bottles' component catalog
   already lists `kron4ek-wine-11.17-amd64`, `kron4ek-wine-11.17-staging-amd64`, and
   `kron4ek-wine-11.17-staging-tkg-amd64`, all on the `stable` channel (checked in
   https://raw.githubusercontent.com/bottlesdevs/components/main/index.yml on 2026-09-14), so
   they show up in Bottles > Preferences > Runners without any toggle. Pick the
   `-staging-amd64` one: it also carries the `Keyboard Layouts` registry fix (second bug
   above). Every Bottles house
   runner is behind the fix: `soda-11.0-10` (2026-09-07) builds from Valve's
   experimental 11.0 tree, `caffe-10.0` is Wine 10.0, `vaniglia-10.19` is Wine 10.19. Fedora's
   own `wine` package is 11.0 on f42/f43/f44/rawhide (spec checked 2026-09-14).
2. **System Wine from WineHQ's repo, no Bottles.** `winehq-staging` 11.17 for Fedora 43/44,
   11.8 for Fedora 42 (https://dl.winehq.org/wine-builds/fedora/); `winehq-devel` exists too
   but needs the .reg fallback. Use plain `winetricks dotnet48 gdiplus` in a fresh 64-bit
   prefix. Fallback if Bottles misbehaves.
3. Patch the one-liner into a wine-tkg/Soda build. Only if 1 and 2 fail; not expected.

## Not verified yet (do on Fedora)

- That switching an existing bottle's runner keeps the `dotnet48` install healthy. If not,
  make a new bottle with the Kron4ek runner and reinstall dotnet48 + gdiplus + Paratext.
- What breaks *after* this crash. Keyboard init was the first thing on the main path; there
  may be more Wine gaps behind it (TSF/text-services interop in `WinKeyboardAdaptor`, IME,
  fonts, WebView-based panes).
- The stack trace names `SIL.Windows.Forms.Keyboarding.Windows.InputLanguageWrapper`; public
  libpalaso puts that class in `SIL.Windows.Forms.Keyboarding`. Cosmetic; Paratext may ship a
  private build. Does not change the analysis.
- Wine bug 40435's page could not be fetched (anti-bot 403); the commit message is the source.
