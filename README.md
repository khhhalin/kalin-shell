# kalin-shell

[![License: GPLv3](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)
![Language: QML](https://img.shields.io/badge/language-QML-41cd52.svg)
![Quickshell](https://img.shields.io/badge/Quickshell-0.3.0-blueviolet.svg)

The overlay shell for [kalin-wm](https://github.com/khhhalin/kalin-wm), built on
[Quickshell](https://git.outfoxxed.me/outfoxxed/quickshell) 0.3.0. It draws the
things a terminal cannot: the exposé overview, notification popups, the OSD, the
hold-Super window menu, and the connection-graph lines over the canvas.

**It deliberately does not draw the bar.** Since the 2026-07-17 TUI-bar cutover
the bar is a real terminal — a kitty window running
[`kalin-bar-tui bar`](https://github.com/khhhalin/kalin-wm/tree/main/tools/bar-tuis)
— and this shell's `BarHost.qml` only reserves the strip (layer-shell exclusive
zone, empty input mask) and supervises that process. The whole previous QML bar
surface (bar widgets, docked panels, side drawers, taskbar, tray) was deleted at
the cutover; git history has it.

**Part of the kalin rice:** [kalin-wm](https://github.com/khhhalin/kalin-wm)
(compositor) · **kalin-shell** (this repo) ·
[kalin-tools](https://github.com/khhhalin/kalin-tools) (wrapper family) ·
[kalin-tuis](https://github.com/khhhalin/kalin-tuis) (rust TUIs) ·
[test-vm](https://github.com/khhhalin/test-vm) (test harness)

## Run

From inside a running compositor session:

```sh
qs -p ~/environment/kalin-shell
```

The kalin-wm login session sets `QS_CONFIG_PATH` to this directory, so its
wrapper just runs `qs`. Smoke test: `timeout 5s qs -p ~/environment/kalin-shell`.

## What it renders

- **Overview / exposé** (`Super+O`): live thumbnails of every window on the
  infinite canvas; click a tile or arrow-keys + Enter to jump.
- **Window menu** (`WindowActions.qml`, hold Super): TUI-styled action chips
  flowing out of the focused window, plus the papyrus (paper-mode yellowness)
  gauge. Informational — the key hints fire compositor binds.
- **Connection lines** (`ConnectionLines.qml`): kalin-wm's window-connection
  edges drawn over the desktop, with drag-to-cut.
- **Notifications** (freedesktop server) and the camera/volume **OSD**.
- **BarHost**: strip reservation + supervision for the terminal bar
  (dockprep-before-spawn, respawn on exit, re-dock on geometry change).

## Compositor coupling

`CompositorService` picks the kalin-wm backend when `$KALIN_IPC_SOCKET` is set
(IPC socket + foreign-toplevel), otherwise a niri backend. The niri path still
works for the overlays but is no longer the target — kalin-wm is.

`Theme.bar` is exactly foot's background (`#1e1915`) because both foot and kitty
apply transparency only to cells matching the default background — one digit off
and every docked terminal turns into an opaque slab against the shell.

This is intentionally a skeleton: no settings system, no plugin API — one
person's desktop, hardcoded.
