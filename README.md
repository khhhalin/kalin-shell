# quickshell

[![License: GPLv3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
![Language: QML](https://img.shields.io/badge/language-QML-41cd52.svg)
![Quickshell](https://img.shields.io/badge/Quickshell-0.3.0-blueviolet.svg)

Bottom bar + docked side panels for the NixOS desktop, built on
[Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell) 0.3.0. It runs on
both **niri** and [kalin-wm](https://github.com/khhhalin/kalin-wm); the same
shell config drives both compositors through one unified `CompositorService`
backend (niri IPC vs. kalin-wm's IPC socket + foreign-toplevel protocol).

**Part of the kalin-wm stack:** [kalin-wm](https://github.com/khhhalin/kalin-wm) (compositor) · **quickshell** (companion shell, this repo) · [test-vm](https://github.com/khhhalin/test-vm) (hardware-accurate test harness)

On **kalin-wm** it is the primary companion shell: bar, overview, docked
panels, notifications, OSD. On **niri** it remains the original native bar,
with a reduced feature set (no docked panels, no overview).

## Run

From inside a running compositor session:

```sh
qs -p ~/environment/quickshell
```

When launched by the kalin-wm login session, `QS_CONFIG_PATH` is set to this
directory and the session wrapper just runs `qs`.

Quick smoke test (runs for 5 seconds, then exits automatically):

```sh
timeout 5s qs -p ~/environment/quickshell
```

## What you get

- Bottom bar: launcher button, taskbar (pinned + running apps on both
  compositors), clock, system tray, media/volume/battery widgets.
- **Docked panels** (`DockedPanel.qml` + `DockedPanelCoordinator.qml`):
  bar-anchored panels — clipboard history, Bluetooth, Wifi, display
  settings, a TUI launcher — that embed a *real* client window via
  kalin-wm's docking IPC (not a rendered texture), with per-screen
  mutual exclusion so only one is open at a time.
- **Overview / exposé** (`Super+O` on kalin-wm): click a tile or use arrow
  keys + Enter to jump.
- **Connection-graph visualization** (`ConnectionLines.qml`): draws
  kalin-wm's window-connection edges over the desktop.
- Window peek: hover a taskbar button for a live thumbnail.
- Notification popups, OSD, calendar panel, and a global password dialog.
- Display settings and brightness control on kalin-wm, via its IPC socket
  (`DisplayService.qml`) — not a placeholder, unlike the niri path which
  shells out to `niri msg`/`brightnessctl`.

## Runtime dependencies

- `niri msg` — used on niri for workspace data and output management.
  Not used on kalin-wm, which reads/writes output state over its own IPC
  socket instead.
- `foot` and `fuzzel` — expected by the kalin-wm keybindings (`Super+T`,
  `Super+P`).
- `cliphist` + `fzf` (via a `foot`-hosted TUI) — clipboard history panel.
- `bluetuith`, `wiremix`, `wlr-randr` — docked-panel TUI backends for
  Bluetooth, audio mixing, and display settings respectively (see
  [kalin-wm/tools/display-panel](https://github.com/khhhalin/kalin-wm/tree/main/tools/display-panel)
  for the display one).

This is intentionally a skeleton: no external settings system, no plugin
API — it's one person's desktop, hardcoded.
