# Gruvbox Bar Redesign

## Goal

Give the Quickshell bottom bar a cleaner, retro-terminal look using the Gruvbox dark palette: low-contrast grouped segments, icon+label status widgets, and no per-widget button boxes.

## Visual Design

### Palette (Gruvbox Dark)

| Token | Hex | Use |
|-------|-----|-----|
| `bg0` | `#282828` | Bar background |
| `bg1` | `#3c3836` | Group backgrounds (taskbar, workspaces, status) |
| `bg2` | `#504945` | Hover / active item background |
| `fg0` | `#ebdbb2` | Primary text (clock, active workspace) |
| `fg1` | `#d5c4a1` | Status labels |
| `yellow` | `#fabd2f` | Active workspace, warnings |
| `green` | `#b8bb26` | Taskbar icons, good battery |
| `blue` | `#458588` | WiFi / Bluetooth icons |
| `brightBlue` | `#83a598` | Volume icon |
| `red` | `#fb4934` | Critical battery |
| `orange` | `#fe8019` | Low battery / warnings |

### Layout

- Bar height: **30 px** (down from 44 px).
- 6 px margin from left/right screen edges.
- Bar background `#282828` with 4 px corner radius.
- Three internal groups, each with `#3c3836` background and 4 px radius:
  1. **Left:** taskbar (pinned/running app icon + name).
  2. **Center:** workspace numbers.
  3. **Right:** status widgets (icon + label) and clock.
- 6 px gap between groups.
- Group internal padding: 0 px vertical, 8–10 px horizontal.
- Widget spacing inside a group: 10–12 px.

### Typography

- All text monospaced.
- Status labels and taskbar app names: 12 px, `#d5c4a1`.
- Clock and active workspace: 12 px, `#ebdbb2` (bright).
- Icons: 12–14 px Nerd Font / monospace glyphs, colored per role.

### Interaction

- **No individual widget backgrounds by default.**
- **Hover / active item:** subtle `#504945` rounded rectangle (2 px radius).
- **Active workspace:** yellow foreground, optional `#504945` background.
- **Panel widgets** (Battery, Volume, Display, Clock, Stats) keep their existing panel behavior; only their bar appearance changes.
- **WiFi / Bluetooth** keep the small TUI hover panel from the previous implementation; their bar items get the same icon+label treatment.

## Components

### `Theme.qml`

Replace the current dark grey palette with Gruvbox roles. New tokens:
- `bar` → `#282828`
- `surface` → `#3c3836`
- `surfaceAlt` → `#504945`
- `surfaceActive` → `#504945`
- `text` → `#ebdbb2`
- `textDim` → `#d5c4a1`
- `textSecondary` → `#a89984`
- `textMuted` → `#665c54`
- `accent` → `#fabd2f`
- `accentBlue` → `#83a598`
- `accentGreen` → `#b8bb26`
- `accentPurple` → `#b16286`
- `border` → `#504945`
- `borderSubtle` → `#3c3836`

Keep helper functions (`withAlpha`) and add status-specific colors if useful.

### `BarConfig.qml`

- `barHeight` → 30
- `buttonRadius` → 2 (for hover/active item highlight)
- Add `groupRadius` → 4
- Add `barMargin` → 6
- Adjust `edgePadding`, `clockWidthRatio`, `clockFontSize` to fit the smaller bar.

### `BottomBar.qml`

- Change the root `Rectangle` background to `Theme.bar` and add 4 px radius.
- Add 6 px left/right margins.
- Wrap the left taskbar group, center workspaces group, and right status group in rounded `Rectangle`s (`Theme.surface`, radius 4).
- Remove per-widget `active`/`hovered` boxy backgrounds; instead the group children use a shared hover/active highlight.
- Keep the 1 px top border removed.

### Widget updates

- `ClockButton`: use `Theme.text` color, remove border/background except on hover (use `Theme.surfaceAlt`).
- `TaskbarButton` / `TaskbarRow`: show icon + app name, no box background; hover uses `Theme.surfaceAlt`.
- `WorkspaceIndicator`: show plain numbers, active in `Theme.accent`; hover uses `Theme.surfaceAlt`.
- `SystemStatsWidget`, `WifiLauncher`, `BluetoothLauncher`, `BatteryWidget`, `VolumeWidget`, `DisplayWidget`, `MediaWidget`, `SystemTrayRow`:
  - Use icon + label where applicable.
  - Remove boxy backgrounds.
  - Use Gruvbox colors for icons.
  - Hover/active uses `Theme.surfaceAlt`.

### `WindowsBarScreen.qml` / `SidePanel.qml`

- Keep current panel system.
- Panel background should follow `Theme.surface` or `Theme.bar` for consistency.
- Drawer animations unchanged.

## Behavior

1. Bar renders as a short, rounded Gruvbox strip with three groups.
2. Hovering any status widget highlights only that item; panel drawers still open for widgets that have them.
3. Clicking a taskbar app focuses/launches it as before.
4. Workspaces switch on click.
5. Clock pins the calendar panel.

## Files to Change

- `environment/quickshell/modules/services/Theme.qml`
- `environment/quickshell/modules/services/BarConfig.qml`
- `environment/quickshell/modules/BottomBar.qml`
- `environment/quickshell/modules/widgets/ClockButton.qml`
- `environment/quickshell/modules/widgets/TaskbarButton.qml`
- `environment/quickshell/modules/widgets/TaskbarRow.qml`
- `environment/quickshell/modules/widgets/WorkspaceIndicator.qml`
- `environment/quickshell/modules/widgets/SystemStatsWidget.qml`
- `environment/quickshell/modules/widgets/WifiLauncher.qml`
- `environment/quickshell/modules/widgets/BluetoothLauncher.qml`
- `environment/quickshell/modules/widgets/BatteryWidget.qml`
- `environment/quickshell/modules/widgets/VolumeWidget.qml`
- `environment/quickshell/modules/widgets/DisplayWidget.qml`
- `environment/quickshell/modules/widgets/MediaWidget.qml`
- `environment/quickshell/modules/widgets/SystemTrayRow.qml`
- `environment/quickshell/modules/SidePanel.qml` (background color only)

## Testing

- `qs -p /home/kalin/environment/quickshell` reports `INFO: Configuration Loaded`.
- Bar height is visibly smaller and rounded.
- Status icons use Gruvbox colors.
- Hovering items shows subtle highlight, not boxy buttons.
- Panels (Battery, Volume, Display, Calendar, WiFi/Bluetooth mini-panel) still open and close correctly.
