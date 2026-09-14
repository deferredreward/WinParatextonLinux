# Prompt: have an AI agent get Paratext 9.5 running on your Linux machine

Copy everything below the line into an AI coding agent that can run commands on your computer
(Claude Code, Codex CLI, Cursor's agent, Aider, etc.), started in an empty folder. It works
best on Fedora or another distribution with Flatpak; KDE Plasma is what this was verified on.
You will still have to do two things yourself: click through Bottles' dependency installer, and
run the Paratext installer you downloaded from paratext.org.

---

I want Paratext 9.5 (the Windows Bible-translation editor; SIL stopped making Linux builds after
9.4) running on this Linux machine, using Wine through Bottles. Someone already worked out a
verified recipe and the dead ends; follow it instead of improvising.

1. Clone https://github.com/deferredreward/WinParatextonLinux and read, in this order:
   `STATE.md`, `docs/verified-recipe-fedora.md`, `docs/display-and-crash-findings-2026-09-14.md`.
   The gotchas there are all things that actually happened; do not re-try the listed dead ends
   (Gecko `user.js`, Wine's Wayland driver, KWin focus-stealing rules, editing `kwinrc [Xwayland]
   Scale`, DXVK, WM-drawn decorations).
2. Run `./setup-paratext-linux.sh --check` and tell me what it reports. Then run it without
   `--check` and follow its MANUAL STEP banners: when it stops for the Bottles dependencies or
   the Paratext installer, tell me exactly what to click or download, wait for me to say done,
   and run it again. Prefer the script over hand-typing its steps; if a step of the script fails
   on this machine, read why from the docs and fix the step rather than working around it.
3. Verify, do not assume. The keyboard-layout probe must print PASS before we launch Paratext.
   If it prints FAIL with hkl=0x0, the Wine runner is older than 11.2; if it prints a
   NullReferenceException, the runner is not a staging build. After the fixes, confirm each
   registry value with `reg query` through `bottles-cli shell` and a `.bat` file (Windows paths
   typed directly on the bottles-cli command line get mangled; the script shows the pattern).
4. Wine reads its DPI once per session: a DPI change needs every Wine process in the bottle gone
   (`tools/bottle-wineserver-kill.sh`) before it applies.
5. Launch through `tools/launch-paratext-logged.sh`, never bare, so a crash leaves a log; read
   crashes with `tools/analyze-paratext-log.sh`. Known and harmless: the first launch after any
   monitor/scale change dies at the splash screen; launch again.
6. If I have two monitors: the top-left one must be the X primary (Wine bug, WineHQ #51166),
   otherwise windows on the other monitor ignore the mouse. On KDE: `kscreen-doctor
   output.<name>.primary`. Check this with `xrandr` before blaming anything else.
7. Report at the end: runner version, probe output, each fix and how you verified it, what I
   still have to do (register, Send/Receive), and anything that did not match the docs -- that
   last part is the useful bit for the next person, so be exact and do not smooth it over.

Do not install anything system-wide with sudo without asking me first. Do not send my Paratext
credentials, project names or machine name anywhere. If you are unsure whether a step is safe or
verified, stop and ask rather than guessing.
