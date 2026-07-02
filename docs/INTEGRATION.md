# kalin-wm ↔ quickshell integration

This shell runs on **niri** today and on **kalin-wm** once that compositor is
the session. The window/workspace source is abstracted so the same shell works
on both, and a set of overlays light up automatically on kalin-wm.

## Backends

`modules/services/CompositorService.qml` is a singleton facade exposing a
normalized window list (`windows`) and actions (`activate`, `close`). It picks
its backend from the environment:

- **kalin-wm** — when `$KALIN_IPC_SOCKET` is set, windows come from
  `wlr-foreign-toplevel-management` via Quickshell's `ToplevelManager`, and
  control goes through the foreign-toplevel handles.
- **niri** — otherwise, it delegates to the existing `niri msg` integration
  (`NiriIpc.qml`).

Existing bar widgets still talk to `NiriIpc` directly (unchanged); new overlays
use `CompositorService` so they are backend-agnostic.

`modules/services/KalinViewport.qml` connects to the kalin-wm IPC socket
(`$KALIN_IPC_SOCKET`, see `kalin-wm/code/src/modules/ipc.c`) and exposes the
infinite-canvas camera state (`x/y/zoom/follow`) plus commands (`pan`, `zoomBy`,
`zoomReset`, `toggleFollow`). Inert on niri.

## Overlays (new)

| File | What |
|------|------|
| `modules/Overview.qml` | Full-screen exposé: every window as a live `ScreencopyView` thumbnail; click to focus. Visible while `OverviewState.visible`. |
| `modules/Osd.qml` | Transient camera OSD: flashes zoom % / follow state on change (from `KalinViewport`). |
| `modules/widgets/SystemTrayRow.qml` | StatusNotifier (system tray) icons; wired into the bottom bar's status row. |

`modules/widgets/WindowPeek.qml`-style live peek can be added the same way the
overview tiles work (`ScreencopyView { captureSource: <toplevel> }`).

## Triggering the overview

The overlay is toggled over Quickshell IPC, so bind a key in the compositor to:

```sh
qs ipc call windows-bar toggleOverview      # also: showOverview / hideOverview
```

Example kalin-wm keybinding (in `code/config/config.h`):

```c
static const char *overviewcmd[] = { "qs", "ipc", "call", "windows-bar", "toggleOverview", NULL };
/* ... */
{ MODKEY, XKB_KEY_o, spawn, {.v = overviewcmd} },
```

(Or the equivalent `spawn` line in `~/.config/niri/config.kdl` while on niri.)

## Testing end-to-end

Requires Quickshell **0.3.0** (`sudo nixos-rebuild switch` after the home-config
pin) and a kalin-wm session.

1. Start kalin-wm; confirm `$KALIN_IPC_SOCKET` is set in spawned clients.
2. `qs -p ~/environment/quickshell` — the bar loads; `CompositorService.backend`
   should be `"kalin"`.
3. Open a few windows; verify the taskbar/overview list them (foreign-toplevel).
4. `qs ipc call windows-bar toggleOverview` — exposé grid with live thumbnails;
   click one to focus.
5. Zoom the canvas (`Super+=` / `Super+-`) — the OSD flashes the zoom %.
6. Regression: run under niri and confirm the bar still works (backend `"niri"`,
   overlays inert).
