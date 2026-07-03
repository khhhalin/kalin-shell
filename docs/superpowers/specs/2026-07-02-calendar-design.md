# Quickshell Google Calendar Month-Grid Panel

## Goal

Clicking the clock in the bottom bar opens a calendar tab in the right-side system panel. The tab shows a month-grid view of the user’s Google Calendar events and provides a quick-add input for creating new events.

## Context

- The bar lives in `environment/quickshell/modules/BottomBar.qml`.
- The right system panel is `environment/quickshell/modules/SystemPanel.qml` and is driven by `SystemPanelState.currentTab`.
- The clock widget is `environment/quickshell/modules/widgets/ClockButton.qml`; it currently emits `clicked()` and the panel opens the clock tab.
- The user wants Google Calendar specifically, with read and write access.

## Architecture

Use `gcalcli` as the Google Calendar backend. It is already packaged in nixpkgs, supports JSON output for reading and natural-language adding for writing, and handles OAuth out of the box.

A Quickshell service wraps the CLI calls so the UI stays declarative. The service exposes the current month’s events to QML and provides commands to add events and refresh data.

## Components

| File | Purpose |
|------|---------|
| `modules/services/CalendarService.py` | Python helper that shells out to `gcalcli`, parses JSON, and exposes typed properties. |
| `modules/services/CalendarService.qml` | Quickshell singleton wrapping the Python helper, exposing `events` and `addEvent(text)` / `refresh(year, month)`. |
| `modules/services/qmldir` | Registers `CalendarService` as a singleton. |
| `modules/CalendarPanel.qml` | Existing placeholder to replace with month-grid UI, event dots, selected-day detail, and quick-add input. |
| `modules/BottomBar.qml` | Clock click already opens the calendar panel; no change needed. |
| `home-config/desktop.nix` | Add `pkgs.gcalcli` to `environment.systemPackages`. |

## Data Flow

1. User clicks the clock.
2. `BottomBar` sets `SystemPanelState.currentTab = "calendar"`.
3. `CalendarWidget` becomes visible and calls `CalendarService.refresh(year, month)`.
4. Service runs `gcalcli --json --calendar default agenda <start> <end>`.
5. JSON is parsed into a list of `{ id, summary, start, end, allDay }` objects exposed as `events`.
6. `CalendarWidget` maps events onto the correct grid days.
7. User types into the quick-add input (e.g. `dinner tomorrow 7pm`) and presses Enter.
8. Service runs `gcalcli add "<text>"`, then refreshes the month view.

## Authentication

`gcalcli` stores OAuth tokens in the user’s home directory after the first run.

- Add `pkgs.gcalcli` to the NixOS system packages.
- The user runs `gcalcli list` once in a terminal to complete browser OAuth.
- The Quickshell service uses the stored token automatically.

If the service detects an authentication error (exit code + stderr mentioning OAuth), the UI shows a message: `Run “gcalcli list” in a terminal to authenticate.`

## UI Design

The calendar pane reuses the existing panel styling (dark background, `#e6e6e6` text, `#4fc3f7` accents).

- **Header**: month/year centered, left/right arrows to change month.
- **Day labels**: Su Mo Tu We Th Fr Sa row.
- **Grid**: 6 rows × 7 columns. Days outside the current month shown dimmed.
- **Events**: small colored dot under the day number; 1–3 dots stacked, overflow hidden.
- **Selected day**: highlighted cell; detail list below the grid shows event titles and times.
- **Quick-add input**: single text field at the bottom with placeholder `Add event…`. Enter submits.

## Error Handling

- `gcalcli` not authenticated → show auth instructions in the panel.
- Network/offline → show cached events if available, otherwise "Can't reach Google Calendar".
- Add failed → show the stderr snippet briefly in the quick-add area.

## Dependencies

- `pkgs.gcalcli` in the NixOS config.
- Internet access for OAuth setup and ongoing sync.

## Future / Out of Scope

- Multiple calendars (use `gcalcli --calendar` per calendar and merge).
- Editing or deleting existing events.
- Drag-to-create or calendar-style event resizing.
- Offline mode beyond whatever `gcalcli` caches locally.
