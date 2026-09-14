# Forum post (draft to adapt)

**Paratext 9.5 on Linux — it works, here's the recipe**

Since SIL dropped Linux builds after Paratext 9.4, running 9.5+ on Linux has meant a Windows
VM. Over one long day we got Paratext 9.5 running natively-ish through Wine (via Bottles) on
Fedora 44 / KDE: starts, main menu, downloading and installing resources, opening OT and NT
texts, two monitors, alongside Logos. It is not one trick; it was five separate problems, and
every one of them is written up with the evidence, so you do not have to rediscover them:

- the startup "Culture is not supported" crash is a Wine bug fixed in Wine 11.2 -- Bottles'
  default runners are too old, you need a recent **wine-staging** runner;
- Bottles' default DXVK crashes Paratext's embedded browser -- turn it off;
- the main menu is hidden under the window manager's title bar -- let Wine draw its own;
- on two monitors, Wine ignores the mouse on any monitor above/left of the primary
  (a 2021 Wine bug nobody had pinned down; now reproduced, WineHQ #51166) -- make the top-left
  monitor the primary;
- Paratext steals focus from other Wine apps -- one Wine setting.

Repo with the recipe, a setup script, a prompt you can hand to an AI agent, the tools that
found the bugs, and the dead ends we hit so you can skip them:
https://github.com/deferredreward/WinParatextonLinux

Two ways in:
1. `./setup-paratext-linux.sh` -- automates everything except two clicks you have to make
   yourself (Bottles' dotnet48 + gdiplus dependencies, and running the Paratext installer).
2. `docs/ai-agent-prompt.md` -- paste it into Claude Code or a similar agent and let it drive.

Verified on Fedora 44 + KDE Plasma 6.7 (Wayland). Other distros/desktops should work with the
same settings but are untested -- please report back, especially Send/Receive, plugins,
printing, and non-Latin keyboards, which we have not exercised yet. Not affiliated with SIL or
Paratext; please do not send Paratext support your Wine problems.
