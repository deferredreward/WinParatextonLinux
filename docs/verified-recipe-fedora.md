# Verified recipe: Paratext 9.5 on Fedora 44 via Bottles

Run end to end on 2026-09-14. Paratext 9.5 starts, reaches the project-selection form, and
opens a text. This supersedes the "next steps" in `docs/fedora-plan.md`; the research behind
it is in `docs/research-2026-09-14-culture-error.md`.

## What was wrong

Two Wine bugs, back to back, both in the keyboard-layout path Paratext runs during startup:

1. `SystemParametersInfo(SPI_GETDEFAULTINPUTLANG)` returned TRUE without writing the layout
   handle (Wine bug 40435, fixed in wine-11.2). .NET built `CultureInfo(0)` and threw
   `Culture is not supported ... 0 (0x0000) is an invalid culture identifier`.
2. No `HKLM\SYSTEM\CurrentControlSet\Control\Keyboard Layouts` keys exist upstream, and
   .NET's `InputLanguage.LayoutName` dereferences them unchecked (Wine bug 47439, fixed only
   in wine-staging).

One runner with a recent **staging** build clears both.

## Environment this was verified on

| | |
|---|---|
| OS | Fedora 44, Wayland (KDE), Paratext runs on XWayland |
| Bottles | Flatpak `com.usebottles.bottles` 67.3 |
| Bottle | `Paratext`, `Arch: win64`, `Windows: win10` |
| Dependencies already in the bottle | `dotnet48`, `gdiplus`, `mono`, `gecko`, fonts |
| Runner before | `soda-11.0-10` (wine-11.0) — **broken** |
| Runner after | `kron4ek-wine-11.17-staging-amd64` (wine-11.17 Staging) — **works** |

## Steps

> The startup crash fix below was verified 2026-09-14 and Paratext runs. Getting it *usable*
> needed four more changes found the same afternoon; they are in
> `docs/display-and-crash-findings-2026-09-14.md` and summarised in `STATE.md`. Do those too.

### 1. Confirm the bug before changing anything

Compile and run the probe inside the bottle. `csc.exe` mangles paths passed through
`bottles-cli shell`, so drive the compiler from a `.bat` file instead:

```bash
B=~/.var/app/com.usebottles.bottles/data/bottles/bottles/Paratext
mkdir -p "$B/drive_c/probe"
cp tools/InputLangCheck.cs "$B/drive_c/probe/"
printf '@echo off\r\ncd /d C:\\probe\r\nC:\\windows\\Microsoft.NET\\Framework64\\v4.0.30319\\csc.exe /nologo /r:System.Windows.Forms.dll /out:InputLangCheck.exe InputLangCheck.cs\r\n' > "$B/drive_c/probe/build.bat"
printf '@echo off\r\ncd /d C:\\probe\r\nInputLangCheck.exe\r\n' > "$B/drive_c/probe/run.bat"

flatpak run --command=bottles-cli com.usebottles.bottles shell -b Paratext -i 'cmd /c C:/probe/build.bat'
flatpak run --command=bottles-cli com.usebottles.bottles shell -b Paratext -i 'cmd /c C:/probe/run.bat'
```

On the old runner this printed, exactly as the research predicted:

```
SPI_GETDEFAULTINPUTLANG ok=True hkl=0x0
GetKeyboardLayout(0) hkl=0x4090409
FAIL: CultureNotFoundException: Culture is not supported.
```

`ok=True` with `hkl=0x0` while `GetKeyboardLayout(0)` is correct is the signature of bug 40435.

### 2. Install a wine-staging >= 11.2 runner

Bottles' GUI (Preferences > Runners) can download it. From the CLI, take the URL straight
from Bottles' own component manifest so the runner is byte-identical to what the GUI installs:

```bash
curl -s https://raw.githubusercontent.com/bottlesdevs/components/main/runners/wine/kron4ek-wine-11.17-staging-amd64.yml
```

That manifest gives the URL, the md5, and the `rename` Bottles applies afterwards:

```bash
R=~/.var/app/com.usebottles.bottles/data/bottles/runners
curl -L -o /tmp/wine.tar.xz https://github.com/Kron4ek/Wine-Builds/releases/download/11.17/wine-11.17-staging-amd64.tar.xz
md5sum /tmp/wine.tar.xz     # must be beb1032ccde002ad35197e5a80eff411
tar -xf /tmp/wine.tar.xz -C "$R"
mv "$R/wine-11.17-staging-amd64" "$R/kron4ek-wine-11.17-staging-amd64"
"$R/kron4ek-wine-11.17-staging-amd64/bin/wine" --version     # wine-11.17 (Staging)
```

### 3. Switch the bottle and update the prefix

Back up first; `wineboot -u` rewrites the registry.

```bash
B=~/.var/app/com.usebottles.bottles/data/bottles/bottles/Paratext
cp "$B/bottle.yml" "$B"/*.reg /somewhere/safe/

flatpak run --command=bottles-cli com.usebottles.bottles edit -b Paratext \
  --runner kron4ek-wine-11.17-staging-amd64
flatpak run --command=bottles-cli com.usebottles.bottles shell -b Paratext -i 'wineboot -u'
```

**Expect this step to misbehave.** On the run that produced this document it ran for roughly
35 minutes wall-clock, opened a browser tab, and was found with Wine error dialogs on screen
when the user came back; it nonetheless exited 0 and the prefix was fine afterwards. The
first write-up called this "normal, let it finish" -- that was wrong. Treat it as a hang with
an unclear trigger: dismiss any dialogs, let it exit, then verify with the probe below.

Two things seen during the update that are **not** failures:

- A browser tab opens on `learn.microsoft.com/.../application-not-started?...processName=rundll32.exe`.
  That is the .NET shim firing for the **32-bit** `syswow64\rundll32.exe` running wine.inf's
  `Wow64Install` section. Paratext 9.5 is 64-bit only, `wineboot -u` still exits 0, and both
  `Framework\v4.0.30319\mscorlib.dll` and `Framework64\v4.0.30319\mscorlib.dll` survive.
  This is probably also what the update hangs on.
- Streams of `err:ole:ifproxy_release_public_refs` and `err:ole:get_stub_manager_from_ipid`.
  Noise.

### 4. Verify, then launch

```bash
flatpak run --command=bottles-cli com.usebottles.bottles shell -b Paratext -i 'cmd /c C:/probe/run.bat'
```

Expected now:

```
SPI_GETDEFAULTINPUTLANG ok=True hkl=0x4090409
GetKeyboardLayout(0) hkl=0x4090409
DefaultInputLanguage handle=0x4090409 culture=en-US layout=Unknown layout
PASS
```

`layout=Unknown layout` is correct, not a warning: wine-staging creates the ~200
`Keyboard Layouts\0000xxxx` keys **empty**, and .NET's helper returns "Unknown layout" for an
empty key instead of throwing. Confirm the keys landed with:

```bash
grep -c 'Keyboard Layouts' "$B/system.reg"     # 202 here
```

Register Paratext so it launches from the Bottles UI and the desktop:

```bash
flatpak run --command=bottles-cli com.usebottles.bottles add -b Paratext -n "Paratext 9" \
  -p "$B/drive_c/Program Files/Paratext 9/Paratext.exe"
flatpak run --command=bottles-cli com.usebottles.bottles run -b Paratext -p "Paratext 9"
```

## Evidence it works

From `drive_c/users/bmw/AppData/Local/Paratext95/ParatextLog.log` on the first successful run:

```
13:02:57 [Thread=1] Warning: gAvailableDatabaseCount: 5
13:02:57 [Thread=ProjectLicenseUpdate(13)] Information: REST Base Url: https://registry.paratext.org/api8/
13:02:57 [Thread=1] Information: Usage:  Form:  Paratext.Base.CommonForms.SelectScrTextsForm:  Shown
13:02:57 [Thread=ProjectLicenseUpdate(13)] Information: REST GET return [1] (429 ms): length = 4681
```

Dictionaries loaded, licences fetched from the registry, project-selection form shown, and a
text opened. No culture dialog.

## Known-harmless errors in a working run

- `Paratext.Data.HttpException: 404: NotFound` fetching `paratext_survey.json` from the media
  server. Server-side; the survey thread swallows it.
- `err:ole:com_get_class_object class {...} not registered` for several CLSIDs.
- `readMonitorEdidFromKey: Failed to get EDID reg key size` from DXVK.
- `Unable to read VR Path Registry` / `OpenXR: Unable to get required Vulkan ... extensions`.
- `err:wineboot:process_run_key Error running cmd winemenubuilder.exe (126)`.

## Gotchas for anyone repeating this

- Do **not** pass Windows paths with backslashes through `bottles-cli shell -i`; the shell
  eats them (`wine: failed to open "C:windowsMicrosoft.NET..."`). Forward slashes confuse
  `csc.exe` separately. Use a `.bat`.
- `bottles-cli edit --runner` changes `bottle.yml` but does not run the prefix update. Run
  `wineboot -u` yourself, or the staging `Keyboard Layouts` keys never get created.
- Don't wrap a Paratext launch in `timeout`; it will kill the session out from under you.
