# TUI Drawer Widgets Design

## Goal

Replace the flaky WiFi and Bluetooth drawer panels with reliable terminal-based apps:
- WiFi → `nmtui`
- Bluetooth → `bluetuith`

Introduce a reusable `TuiLauncherWidget` so adding another TUI launcher later is a one-line change.

## Context

The current right-side popup drawer is controlled by `WindowsBarScreen.qml`:
- Hovering a status widget sets `BottomBar.statusHoveredTab`.
- `WindowsBarScreen` uses that tab to decide which panel (`SystemPanel`, `MixerPanel`, `CalendarPanel`, `StatsPanel`) to show.
- `SystemPanel` contains the WiFi and Bluetooth panes, which rely on `nmcli` polling and the `Quickshell.Bluetooth` plugin respectively. Both are flaky: `nmcli` parsing breaks on unusual SSIDs, rescan fails silently, and the Bluetooth plugin misses devices or mishandles pairing.

The session already runs `foot --server`, so `footclient -e <app>` is the fastest way to open a terminal.

## Design

### Components

#### 1. `TuiLauncherWidget.qml` (new)

A generic bar widget that launches a TUI app on click and exposes a tooltip on hover.

Properties:
- `string icon` — icon name or unicode glyph shown in the bar.
- `string tabName` — identifier used for tooltip tracking (e.g. `"wifi"`, `"bluetooth"`).
- `var launchCommand` — command array passed to `SystemActions.run`/`spawn`.
- `string tooltipText` — text shown while hovered.
- `bool active` — `true` when a related state is active (e.g. WiFi connected, Bluetooth on).
- `bool hovered` — `true` while the mouse is over the widget.

Behavior:
- On hover, set `SystemPanelState.tooltipTab = tabName`.
- On hover exit, clear `SystemPanelState.tooltipTab` if it still equals this widget’s `tabName`.
- On click, spawn `launchCommand` and clear `SystemPanelState.rightOwner` so any open side panel closes.
- Visuals match the existing rounded status widgets in `BottomBar.qml`.

#### 2. `TooltipPopup.qml` (new)

A small popup window that follows the hovered widget.

- Watches `SystemPanelState.tooltipTab` and `SystemPanelState.tooltipText`.
- Appears just above the bar when a tooltip tab is set.
- Hidden immediately when the tab is cleared.
- Styled to match the bar/drawer theme.

#### 3. `SystemPanelState.qml` (update)

Add tooltip state:
- `property string tooltipTab: ""`
- `property string tooltipText: ""`

`rightOwner` continues to track the pinned side panel. WiFi and Bluetooth will no longer write to it.

#### 4. `BottomBar.qml` (update)

Replace `WifiWidget` and `BluetoothWidget` with `TuiLauncherWidget` instances.

WiFi instance:
- `icon`: existing WiFi icon.
- `tabName`: `"wifi"`.
- `launchCommand`: `["footclient", "-e", "nmtui"]`.
- `tooltipText`: connected SSID or `"WiFi disconnected"`, refreshed by a lightweight `nmcli` poller.

Bluetooth instance:
- `icon`: existing Bluetooth icon.
- `tabName`: `"bluetooth"`.
- `launchCommand`: `["footclient", "-e", "bluetuith"]`.
- `tooltipText`: adapter state + connected/paired device count from `Quickshell.Bluetooth`.

Keep Volume, Display, Clock, Stats, Battery, Media, and SystemTray as existing panel widgets.

#### 5. `WindowsBarScreen.qml` (update)

Ensure the side panel only opens for tabs that have panel content. WiFi and Bluetooth will be excluded from the panel owner logic because they no longer set `SystemPanelState.rightOwner` and are not in the panel switch list.

#### 6. `SystemPanel.qml` (update)

Remove the WiFi and Bluetooth panes. Keep Battery, Display, and any other system rows.

#### 7. NixOS / niri configuration

- Add `pkgs.bluetuith` to `environment.systemPackages` in `home-config/desktop.nix`.
- Add niri window rules in `~/.config/niri/conf.d/40-window-rules.kdl`:
  - Match windows whose title is `nmtui` or `bluetuith`.
  - `open-floating true`.
  - Set `default-column-width` and `default-window-height` to fixed sizes so the terminal lands centered.

## Data Flow

1. User hovers the WiFi icon.
2. `TuiLauncherWidget` sets `SystemPanelState.tooltipTab = "wifi"` and updates `tooltipText`.
3. `TooltipPopup` becomes visible above the bar with the SSID/status.
4. User clicks the WiFi icon.
5. `TuiLauncherWidget` calls `SystemActions.run(["footclient", "-e", "nmtui"])`.
6. The widget clears `SystemPanelState.rightOwner`, closing any open side panel.
7. Niri matches the new `nmtui` window and opens it floating, sized, and centered.

Same flow for Bluetooth with `bluetuith`.

## Error Handling and Edge Cases

- If `footclient` is unavailable (foot server not running), fall back to `foot -e <app>`.
- Tooltip is hidden immediately on mouse exit.
- Only one tooltip is visible at a time; the last-hovered widget wins.
- Clicking WiFi/Bluetooth while another panel is pinned closes the pinned panel.
- If the TUI app exits immediately (e.g. command not found), the terminal window shows the error and the user sees it.

## Testing

- Run `qs -p /home/kalin/environment/quickshell`; expect `INFO: Configuration Loaded`.
- Hover WiFi: tooltip appears, no side panel opens.
- Click WiFi: a floating `nmtui` window opens, centered.
- Hover Bluetooth: tooltip appears, no side panel opens.
- Click Bluetooth: a floating `bluetuith` window opens, centered.
- Click Volume/Display/Clock: their existing side panels still open and close correctly.
- Run `sudo nixos-rebuild switch --flake /home/kalin/home-config#KalinBook` and confirm `bluetuith` is on `PATH`.

## Files to Change

- `environment/quickshell/modules/widgets/TuiLauncherWidget.qml` — new
- `environment/quickshell/modules/widgets/TooltipPopup.qml` — new
- `environment/quickshell/modules/services/SystemPanelState.qml` — add tooltip state
- `environment/quickshell/modules/BottomBar.qml` — replace WiFi/Bluetooth widgets
- `environment/quickshell/modules/WindowsBarScreen.qml` — exclude WiFi/Bluetooth from panel logic
- `environment/quickshell/modules/SystemPanel.qml` — remove WiFi/Bluetooth panes
- `home-config/desktop.nix` — add `bluetuith`
- `~/.config/niri/conf.d/40-window-rules.kdl` — float and size nmtui/bluetuith windows
