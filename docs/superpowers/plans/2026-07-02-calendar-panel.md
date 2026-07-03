# Google Calendar Month-Grid Panel Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the placeholder `CalendarPanel.qml` with a live month-grid view backed by `gcalcli`, including a quick-add input for new Google Calendar events.

**Architecture:** A Python helper shells out to `gcalcli`, returning JSON. A Quickshell singleton exposes the events list and an `addEvent` command. `CalendarPanel.qml` renders the grid, day selection, and quick-add input. `gcalcli` itself is installed via the NixOS config.

**Tech Stack:** Quickshell (QML), Python 3, `gcalcli`, NixOS.

## Global Constraints

- `gcalcli` 4.5.1 does **not** support `--json`; use `--tsv` for machine-readable agenda output.
- First-time authentication requires the user to run `gcalcli list` in a terminal and complete browser OAuth.
- Panel geometry is controlled by `BarConfig.panelWidth` (440) and `BarConfig.panelHeight` (520).
- Follow the existing dark-theme palette: `#1e1e1e` backgrounds, `#e6e6e6` text, `#4fc3f7` accents, `#555555` muted text.

---

## File Structure

| File | Change | Responsibility |
|------|--------|----------------|
| `home-config/desktop.nix` | Modify | Add `pkgs.gcalcli` to system packages. |
| `environment/quickshell/modules/services/CalendarService.py` | Create | Shells out to `gcalcli agenda --tsv` and `gcalcli quick`, prints JSON. |
| `environment/quickshell/modules/services/CalendarService.qml` | Create | Quickshell singleton exposing `events`, `error`, `ready`, `refresh(year, month)`, `addEvent(text)`. |
| `environment/quickshell/modules/services/qmldir` | Modify | Register `CalendarService` as a singleton. |
| `environment/quickshell/modules/CalendarPanel.qml` | Replace | Month-grid UI with header, day grid, selected-day detail, quick-add input. |

---

### Task 1: Install gcalcli via NixOS

**Files:**
- Modify: `home-config/desktop.nix`

**Interfaces:**
- Consumes: existing `environment.systemPackages` list.
- Produces: `gcalcli` binary available in `$PATH` after rebuild.

- [ ] **Step 1: Add `gcalcli` to system packages**

In the `# browsers` or `# file management` section, add `pkgs.gcalcli`:

```nix
    # productivity / monitoring
    obsidian qbittorrent btop gcalcli
```

- [ ] **Step 2: Rebuild the system**

Run:

```bash
sudo nixos-rebuild switch --flake /home/kalin/home-config#KalinBook
```

Expected: build succeeds and `which gcalcli` returns a path.

- [ ] **Step 3: Commit**

```bash
git add home-config/desktop.nix
git commit -m "feat: install gcalcli for calendar panel"
```

---

### Task 2: Create CalendarService.py

**Files:**
- Create: `environment/quickshell/modules/services/CalendarService.py`

**Interfaces:**
- Consumes: `gcalcli` on `$PATH`.
- Produces: JSON lines like `{"events": [...]}` or `{"error": "..."}`.

- [ ] **Step 1: Write the helper**

```python
#!/usr/bin/env python3
"""Calendar backend for Quickshell. Talks to Google Calendar via gcalcli."""

import json
import subprocess
import sys
from datetime import datetime


def _run(cmd, timeout=30):
    try:
        out = subprocess.check_output(cmd, text=True, timeout=timeout, stderr=subprocess.STDOUT)
        return {"ok": True, "output": out}
    except subprocess.CalledProcessError as e:
        return {"ok": False, "error": (e.output or "").strip() or "gcalcli failed"}
    except subprocess.TimeoutExpired:
        return {"ok": False, "error": "gcalcli timed out"}


def fetch_month(year, month):
    start = datetime(year, month, 1)
    end = datetime(year + 1, 1, 1) if month == 12 else datetime(year, month + 1, 1)

    start_str = start.strftime("%Y-%m-%d")
    end_str = end.strftime("%Y-%m-%d")

    result = _run(["gcalcli", "agenda", "--tsv", start_str, end_str])
    if not result["ok"]:
        print(json.dumps({"error": result["error"]}), flush=True)
        return

    events = []
    for line in result["output"].strip().split("\n"):
        if not line.strip():
            continue
        parts = line.split("\t")
        if len(parts) < 6:
            continue
        start_date, start_time, end_date, end_time, link, title = parts[:6]
        events.append({
            "startDate": start_date,
            "startTime": start_time,
            "endDate": end_date,
            "endTime": end_time,
            "title": title,
        })

    print(json.dumps({"events": events}), flush=True)


def add_event(text):
    result = _run(["gcalcli", "quick", text])
    if result["ok"]:
        print(json.dumps({"ok": True}), flush=True)
    else:
        print(json.dumps({"error": result["error"]}), flush=True)


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"error": "missing command"}), flush=True)
        return
    cmd = sys.argv[1]
    if cmd == "fetch" and len(sys.argv) == 4:
        fetch_month(int(sys.argv[2]), int(sys.argv[3]))
    elif cmd == "add" and len(sys.argv) == 3:
        add_event(sys.argv[2])
    else:
        print(json.dumps({"error": "bad arguments"}), flush=True)


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x environment/quickshell/modules/services/CalendarService.py
```

- [ ] **Step 3: Commit**

```bash
git add environment/quickshell/modules/services/CalendarService.py
git commit -m "feat: add CalendarService.py gcalcli helper"
```

---

### Task 3: Create CalendarService.qml and Register Singleton

**Files:**
- Create: `environment/quickshell/modules/services/CalendarService.qml`
- Modify: `environment/quickshell/modules/services/qmldir`

**Interfaces:**
- Consumes: `CalendarService.py` (resolved next to the QML file).
- Produces: `CalendarService.events`, `CalendarService.error`, `CalendarService.ready`, plus `refresh(year, month)` and `addEvent(text)`.

- [ ] **Step 1: Create the singleton QML wrapper**

```qml
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var events: []
    property string error: ""
    property bool ready: false

    readonly property string scriptPath:
        Qt.resolvedUrl("CalendarService.py").toString().replace("file://", "")

    function refresh(year, month) {
        root.ready = false
        root.error = ""
        fetchProc.command = ["python3", root.scriptPath, "fetch", String(year), String(month)]
        fetchProc.running = true
    }

    function addEvent(text) {
        root.error = ""
        addProc.command = ["python3", root.scriptPath, "add", text]
        addProc.running = true
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    if (data.error) {
                        root.error = data.error
                    } else {
                        root.events = data.events ?? []
                    }
                } catch (_) {
                    root.error = "Failed to parse calendar data"
                }
                root.ready = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("CalendarService:", msg)
            }
        }
    }

    Process {
        id: addProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    if (data.error) {
                        root.error = data.error
                    } else {
                        const now = new Date()
                        root.refresh(now.getFullYear(), now.getMonth() + 1)
                    }
                } catch (_) {
                    root.error = "Failed to add event"
                }
            }
        }
    }
}
```

- [ ] **Step 2: Register in qmldir**

Add this line to `environment/quickshell/modules/services/qmldir`:

```
singleton CalendarService 1.0 CalendarService.qml
```

- [ ] **Step 3: Commit**

```bash
git add environment/quickshell/modules/services/CalendarService.qml
environment/quickshell/modules/services/qmldir
git commit -m "feat: add CalendarService singleton"
```

---

### Task 4: Implement CalendarPanel.qml Month Grid

**Files:**
- Replace: `environment/quickshell/modules/CalendarPanel.qml`

**Interfaces:**
- Consumes: `CalendarService.events/error/ready` and `CalendarService.refresh/addEvent`.
- Produces: Visual month grid, selected day state, quick-add input.

- [ ] **Step 1: Replace placeholder with full implementation**

```qml
import QtQuick
import QtQuick.Layouts
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// CalendarPanel — month grid backed by Google Calendar via gcalcli.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property date viewDate: new Date()
    property int selectedDay: viewDate.getDate()

    readonly property int daysInMonth: {
        const d = new Date(viewDate)
        d.setMonth(d.getMonth() + 1)
        d.setDate(0)
        return d.getDate()
    }

    readonly property int firstWeekday: {
        const d = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1)
        return d.getDay()
    }

    function eventsForDay(day) {
        const dateStr = Qt.formatDate(new Date(viewDate.getFullYear(), viewDate.getMonth(), day), "yyyy-MM-dd")
        return CalendarService.events.filter(e => e.startDate === dateStr)
    }

    Component.onCompleted: {
        const now = new Date()
        CalendarService.refresh(now.getFullYear(), now.getMonth() + 1)
    }

    onViewDateChanged: {
        CalendarService.refresh(viewDate.getFullYear(), viewDate.getMonth() + 1)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ── Header ──────────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 28

            Rectangle {
                anchors.left: parent.left
                width: 28; height: 28; radius: 6
                color: prevMa.containsMouse ? "#2a2a2a" : "#1e1e1e"
                Text { anchors.centerIn: parent; text: "‹"; color: "#e6e6e6"; font.pixelSize: 18 }
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = new Date(root.viewDate)
                        d.setMonth(d.getMonth() - 1)
                        root.viewDate = d
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                color: "#e6e6e6"
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.right: parent.right
                width: 28; height: 28; radius: 6
                color: nextMa.containsMouse ? "#2a2a2a" : "#1e1e1e"
                Text { anchors.centerIn: parent; text: "›"; color: "#e6e6e6"; font.pixelSize: 18 }
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = new Date(root.viewDate)
                        d.setMonth(d.getMonth() + 1)
                        root.viewDate = d
                    }
                }
            }
        }

        // ── Weekday labels ──────────────────────────────────────────────────────
        Row {
            width: parent.width
            height: 18
            spacing: 0
            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                delegate: Text {
                    required property string modelData
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: "#888888"
                    font.pixelSize: 11
                }
            }
        }

        // ── Month grid ──────────────────────────────────────────────────────────
        Grid {
            id: dayGrid
            width: parent.width
            height: parent.width * 0.85
            columns: 7
            rows: 6
            spacing: 4

            Repeater {
                model: 42

                delegate: Rectangle {
                    id: cell
                    required property int index

                    readonly property int dayNumber: index - root.firstWeekday + 1
                    readonly property bool inMonth: dayNumber >= 1 && dayNumber <= root.daysInMonth
                    readonly property bool isSelected: inMonth && dayNumber === root.selectedDay
                    readonly property var dayEvents: inMonth ? root.eventsForDay(dayNumber) : []

                    width: (dayGrid.width - 6 * dayGrid.spacing) / 7
                    height: (dayGrid.height - 5 * dayGrid.spacing) / 6
                    radius: 6
                    color: isSelected ? "#1a3a5a" : (cellMa.containsMouse ? "#252525" : "transparent")
                    border.width: isSelected ? 1 : 0
                    border.color: "#4fc3f7"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.inMonth ? cell.dayNumber : ""
                            color: cell.isSelected ? "#4fc3f7" : "#e6e6e6"
                            font.pixelSize: 12
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            Repeater {
                                model: Math.min(cell.dayEvents.length, 3)
                                delegate: Rectangle {
                                    width: 5; height: 5; radius: 2.5
                                    color: "#4fc3f7"
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (cell.inMonth) root.selectedDay = cell.dayNumber
                    }
                }
            }
        }

        // ── Selected day detail ─────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 90

            Column {
                anchors.fill: parent
                spacing: 6

                Text {
                    text: root.eventsForDay(root.selectedDay).length > 0
                          ? Qt.formatDate(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), root.selectedDay), "dddd, MMMM d")
                          : "No events"
                    color: "#888888"
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                }

                Flickable {
                    width: parent.width
                    height: parent.height - 20
                    contentHeight: detailCol.height
                    clip: true

                    Column {
                        id: detailCol
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: root.eventsForDay(root.selectedDay)

                            delegate: Text {
                                required property var modelData
                                text: (modelData.startTime ? modelData.startTime + "  " : "") + modelData.title
                                color: "#e6e6e6"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }
            }
        }

        // ── Error / auth message ────────────────────────────────────────────────
        Text {
            width: parent.width
            visible: CalendarService.error !== ""
            text: CalendarService.error.includes("auth")
                  ? "Run ‘gcalcli list’ in a terminal to authenticate."
                  : CalendarService.error
            color: "#ff6b6b"
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        // ── Quick-add input ─────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 34
            radius: 8
            color: "#1e1e1e"
            border.width: 1
            border.color: input.activeFocus ? "#4fc3f7" : "#2a2a2a"

            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: 8
                color: "#e6e6e6"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                clip: true

                Keys.onReturnPressed: {
                    if (text.trim().length) {
                        CalendarService.addEvent(text.trim())
                        text = ""
                    }
                }

                Text {
                    anchors.fill: parent
                    text: "Add event…"
                    color: "#555555"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0 && !input.activeFocus
                }
            }
        }
    }
}
```

- [ ] **Step 2: Test parsing without auth**

Temporarily test the Python helper by running it directly to ensure no syntax errors:

```bash
python3 environment/quickshell/modules/services/CalendarService.py
```

Expected: prints `{"error": "missing command"}`.

- [ ] **Step 3: Commit**

```bash
git add environment/quickshell/modules/CalendarPanel.qml
git commit -m "feat: replace CalendarPanel placeholder with month grid"
```

---

### Task 5: Verify Quickshell Loads

**Files:**
- None (validation only).

- [ ] **Step 1: Launch quickshell**

```bash
pkill qs
qs -p /home/kalin/environment/quickshell
```

- [ ] **Step 2: Open the calendar panel**

Click the clock in the bar.

Expected:
- A month grid appears in the right panel.
- Without `gcalcli` auth, the panel shows the red auth message.
- After running `gcalcli list` and authenticating, clicking a month arrow reloads events.

- [ ] **Step 3: Test quick-add**

After auth, type `test event tomorrow 3pm` in the quick-add field and press Enter.

Expected: the event appears in Google Calendar and the grid refreshes.

- [ ] **Step 4: Commit any final fixes**

```bash
git add -A
git commit -m "fix: calendar panel polish"
```

---

## Spec Coverage

| Spec Requirement | Task |
|------------------|------|
| Install `gcalcli` | Task 1 |
| Fetch events via `gcalcli --tsv` | Task 2 |
| Add events via `gcalcli quick` | Task 2 |
| Quickshell singleton service | Task 3 |
| Month-grid UI | Task 4 |
| Quick-add input | Task 4 |
| Auth error handling | Task 4 |
| Click clock to open panel | Already wired in `WindowsBarScreen.qml` |

## Placeholder Scan

No `TBD`, `TODO`, or vague requirements remain. All code blocks are complete.

## Type Consistency

- `CalendarService.refresh(year, month)` expects JS-style month numbers (`1` = January).
- `CalendarService.py` converts these to Python `datetime` months (`1` = January).
- `CalendarService.events` items have fields: `startDate`, `startTime`, `endDate`, `endTime`, `title`.
- `CalendarPanel.qml` filters on `startDate` using `yyyy-MM-dd` strings.
