# quickshell

Bottom bar + expandable side panels for the NixOS desktop. It runs on both
**niri** and **kalin-wm**; the same shell config is used for both compositors.

On **kalin-wm** it is the companion desktop shell (bar, overview, notifications,
OSD). On **niri** it remains the original native bar.

## Run

From inside a running compositor session:

```sh
qs -p ~/environment/quickshell
```

When launched by the kalin-wm login session, `QS_CONFIG_PATH` is set to
`~/environment/quickshell` and the wrapper simply runs `qs`.

Quick smoke test (runs for 5 seconds, then exits automatically):

```sh
timeout 5s qs -p ~/environment/quickshell
```

## What you get

- Bottom bar (Win10-ish): left NixOS button, centered workspaces (hidden on
  kalin-wm), right clock button.
- Left + right slide-out panels (open on hover, pin on click).
- Taskbar that lists pinned and running apps on both compositors, using the
  unified `CompositorService` backend.
- Overview / exposé toggle bound to `Super+O` on kalin-wm.
- Notification popups, OSD, and a global password dialog.

## Runtime dependencies

- `niri msg` — used on niri for workspace data and the **Display** tab
  (reordering outputs, cycling resolutions/scales). Not used on kalin-wm, where
  the Display tab is a placeholder.
- `brightnessctl` — used on niri for display brightness control.
- `foot` and `fuzzel` — expected by the kalin-wm keybindings (`Super+T`,
  `Super+P`).

This is intentionally a skeleton: no external settings system, no extra widgets.
