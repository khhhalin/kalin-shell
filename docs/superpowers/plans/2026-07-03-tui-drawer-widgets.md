# TUI Drawer Widgets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the flaky WiFi/Bluetooth side-panel drawers with reliable TUI apps (`nmtui`/`bluetuith`) launched from reusable Quickshell widgets, and add a hover tooltip for status.

**Architecture:** Add a generic `TuiLauncherWidget` plus `WifiLauncher`/`BluetoothLauncher` wrappers that update a global tooltip state. Clicking launches `footclient -e nmtui/bluetuith` and clears any pinned panel. Niri floats and sizes the resulting terminal windows.

**Tech Stack:** Quickshell QML, QtQuick, Quickshell.Io/Bluetooth, `foot`/`footclient`, NixOS, niri.

## Global Constraints

- Keep changes inside `/home/kalin/environment/quickshell` and `/home/kalin/home-config`.
- Follow existing bar/drawer visual style (Theme colors, BarConfig sizes).
- All spawned commands must work with the running `foot --server` session.
- Manual test cycle: `qs -p /home/kalin/environment/quickshell` must print `INFO: Configuration Loaded`.
- NixOS changes require `sudo nixos-rebuild switch --flake /home/kalin/home-config#KalinBook`.

---

### Task 1: Add tooltip state to `SystemPanelState`

**Files:**
- Modify: `environment/quickshell/modules/services/SystemPanelState.qml`

**Interfaces:**
- Produces: `SystemPanelState.tooltipTab`, `SystemPanelState.tooltipText`, `SystemPanelState.tooltipCenterX`

- [ ] **Step 1: Add tooltip properties and change default tab**

Replace the file contents with:

```qml
pragma Singleton
import Quickshell

// Tracks which tab is active in the right-side system panel and which
// TUI launcher widget (if any) is currently hovered for a tooltip.
Singleton {
    id: root

    // Side-panel state. Default to "battery" because "wifi" is no longer a panel tab.
    property string currentTab: "battery"

    // Which widget last pinned the right panel ("clock" | "battery" | "volume" | "display" | "stats" | "")
    property string rightOwner: ""

    // Tooltip state for TUI launcher widgets.
    property string tooltipTab: ""
    property string tooltipText: ""
    property int    tooltipCenterX: 0
}
```

- [ ] **Step 2: Verify no other file references `SystemPanelState.currentTab === "wifi"` or `"bluetooth"`**

Run:

```bash
rg 'currentTab.*(wifi|bluetooth)' /home/kalin/environment/quickshell
```

Expected: only this file should match after later tasks remove the old panes.

---

### Task 2: Create the generic `TuiLauncherWidget`

**Files:**
- Create: `environment/quickshell/modules/widgets/TuiLauncherWidget.qml`

**Interfaces:**
- Consumes: `SystemPanelState` singleton, `BarConfig`, `Theme`
- Produces: reusable widget with `tabName`, `icon`, `tooltipText`, `active`, `hovered`, `clicked()`

- [ ] **Step 1: Write `TuiLauncherWidget.qml`**

```qml
import QtQuick
import Quickshell
import "../services"

// Generic bar widget that launches a TUI app on click and exposes a tooltip on hover.
Item {
    id: root

    property string tabName: ""
    property string icon: ""
    property string tooltipText: ""
    property bool active: false

    property bool hovered: false
    readonly property int centerX: root.mapToItem(null, root.width / 2, 0).x

    implicitHeight: BarConfig.barHeight
    implicitWidth: Math.max(labelText.implicitWidth + 20, 48)

    Rectangle {
        anchors.fill: parent
        radius: BarConfig.buttonRadius
        color: root.active ? Theme.surfaceActive : (root.hovered ? Theme.surfaceAlt : "transparent")
        border.width: root.active ? 1 : 0
        border.color: Theme.border

        Text {
            id: labelText
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Theme.textBright : (root.hovered ? Theme.text : Theme.textDim)
            font.pixelSize: BarConfig.clockFontSize
            font.family: "monospace"
        }
    }

    signal clicked()

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered = true
        onExited: root.hovered = false
        onClicked: root.clicked()
    }

    onHoveredChanged: {
        if (root.hovered) {
            SystemPanelState.tooltipTab = root.tabName
            SystemPanelState.tooltipText = root.tooltipText
            SystemPanelState.tooltipCenterX = root.centerX
        } else if (SystemPanelState.tooltipTab === root.tabName) {
            SystemPanelState.tooltipTab = ""
            SystemPanelState.tooltipText = ""
        }
    }

    onTooltipTextChanged: {
        if (root.hovered && SystemPanelState.tooltipTab === root.tabName) {
            SystemPanelState.tooltipText = root.tooltipText
        }
    }
}
```

- [ ] **Step 2: Sanity-check the file with `qs -p`**

This file alone will not fail load because it is not yet imported.

---

### Task 3: Create `WifiLauncher.qml`

**Files:**
- Create: `environment/quickshell/modules/widgets/WifiLauncher.qml`

**Interfaces:**
- Consumes: `TuiLauncherWidget`, `SystemActions`, `SystemPanelState`
- Produces: widget with `active` and `hovered` properties for `BottomBar`

- [ ] **Step 1: Write `WifiLauncher.qml`**

```qml
import QtQuick
import Quickshell.Io
import "./widgets"
import "../services"

// Launches nmtui on click; shows connected SSID/strength in a hover tooltip.
Item {
    id: root

    property bool active: false
    property alias hovered: tui.hovered

    property string ssid: ""
    property int strength: 0
    readonly property bool online: ssid.length > 0

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: nmcliProc.running = true
    }

    Process {
        id: nmcliProc
        command: ["nmcli", "-t", "-f", "active,ssid,signal", "dev", "wifi"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                root.ssid = ""
                root.strength = 0
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    if (parts[0] === "yes" && parts.length >= 3) {
                        root.ssid = parts[1]
                        root.strength = parseInt(parts[2]) || 0
                        break
                    }
                }
            }
        }

        stderr: StdioCollector {}
    }

    readonly property string wifiIcon: {
        if (!online)          return "󰤭"
        if (strength >= 75)   return "󰤨"
        if (strength >= 50)   return "󰤥"
        if (strength >= 25)   return "󰤢"
        return "󰤟"
    }

    readonly property string tooltip: online
        ? "WiFi: " + ssid + " (" + strength + "%)"
        : "WiFi disconnected"

    TuiLauncherWidget {
        id: tui
        anchors.fill: parent
        tabName: "wifi"
        icon: root.wifiIcon
        tooltipText: root.tooltip
        active: root.active

        onClicked: {
            SystemActions.run(["sh", "-lc", "exec footclient -e nmtui || exec foot -e nmtui"])
            SystemPanelState.rightOwner = ""
        }
    }
}
```

---

### Task 4: Create `BluetoothLauncher.qml`

**Files:**
- Create: `environment/quickshell/modules/widgets/BluetoothLauncher.qml`

**Interfaces:**
- Consumes: `Quickshell.Bluetooth`, `TuiLauncherWidget`, `SystemActions`, `SystemPanelState`
- Produces: widget with `active` and `hovered` properties for `BottomBar`

- [ ] **Step 1: Write `BluetoothLauncher.qml`**

```qml
import QtQuick
import Quickshell.Bluetooth
import "./widgets"
import "../services"

// Launches bluetuith on click; shows adapter state + connected count in tooltip.
Item {
    id: root

    property bool active: false
    property alias hovered: tui.hovered

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false

    readonly property var connectedDevices: {
        if (!adapter) return []
        var result = []
        var devs = adapter.devices
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].connected) result.push(devs[i])
        }
        return result
    }

    readonly property int connectedCount: connectedDevices.length

    readonly property string btIcon: enabled ? "󰂯" : "󰂲"

    readonly property string tooltip: {
        if (!enabled) return "Bluetooth off"
        if (connectedCount === 0) return "Bluetooth on, no devices connected"
        if (connectedCount === 1) {
            var name = connectedDevices[0].name || connectedDevices[0].address || "device"
            return "Bluetooth: " + name
        }
        return "Bluetooth: " + connectedCount + " devices connected"
    }

    TuiLauncherWidget {
        id: tui
        anchors.fill: parent
        tabName: "bluetooth"
        icon: root.btIcon
        tooltipText: root.tooltip
        active: root.active

        onClicked: {
            SystemActions.run(["sh", "-lc", "exec footclient -e bluetuith || exec foot -e bluetuith"])
            SystemPanelState.rightOwner = ""
        }
    }
}
```

---

### Task 5: Create `TooltipPopup.qml`

**Files:**
- Create: `environment/quickshell/modules/widgets/TooltipPopup.qml`

**Interfaces:**
- Consumes: `SystemPanelState`, `BarConfig`, `Theme`, `ShellScreen`
- Produces: global tooltip popup positioned above the hovered widget

- [ ] **Step 1: Write `TooltipPopup.qml`**

```qml
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../services"

// Small status tooltip shown when hovering a TUI launcher widget.
PanelWindow {
    id: root

    required property ShellScreen screen

    visible: SystemPanelState.tooltipTab !== ""

    color: "transparent"
    anchors { left: true; right: true; bottom: true }
    implicitHeight: card.height
    margins.bottom: BarConfig.barHeight + 6

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "windows-bar:tooltip"

    mask: Region { item: card }

    readonly property int padX: 12
    readonly property int padY: 6
    readonly property int maxW: root.screen ? root.screen.width - 24 : 400

    Rectangle {
        id: card
        x: root.screen
            ? Math.max(6, Math.min(SystemPanelState.tooltipCenterX - width / 2,
                                   root.screen.width - width - 6))
            : 6
        y: 0
        width: Math.min(label.implicitWidth + root.padX * 2, root.maxW)
        height: label.implicitHeight + root.padY * 2
        radius: BarConfig.buttonRadius
        color: Theme.scrim
        border { width: 1; color: Theme.border }

        Text {
            id: label
            anchors {
                left: parent.left; right: parent.right; top: parent.top
                margins: root.padY
                leftMargin: root.padX
                rightMargin: root.padX
            }
            text: SystemPanelState.tooltipText
            color: Theme.text
            font.pixelSize: 12
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
```

---

### Task 6: Wire launchers and tooltip into `BottomBar.qml`

**Files:**
- Modify: `environment/quickshell/modules/BottomBar.qml`

**Interfaces:**
- Consumes: `WifiLauncher`, `BluetoothLauncher`

- [ ] **Step 1: Update imports**

Change:

```qml
import "./widgets"
import "./services"
```

to:

```qml
import "./widgets"
import "./services"
```

(No new imports needed because `WifiLauncher` and `BluetoothLauncher` live in the same `./widgets` directory.)

- [ ] **Step 2: Remove WiFi/Bluetooth from `rightHovered`**

Replace:

```qml
readonly property bool rightHovered: statsBtn.hovered
                                  || rightButton.hovered
                                  || wifiBtn.hovered
                                  || btBtn.hovered
                                  || batBtn.hovered
                                  || volBtn.hovered
                                  || displayBtn.hovered
```

with:

```qml
readonly property bool rightHovered: statsBtn.hovered
                                  || rightButton.hovered
                                  || batBtn.hovered
                                  || volBtn.hovered
                                  || displayBtn.hovered
```

- [ ] **Step 3: Replace the old WiFi/Bluetooth widgets**

Replace:

```qml
WifiWidget {
    id: wifiBtn
    active: bar.rightActive && (wifiBtn.hovered || SystemPanelState.rightOwner === "wifi")
    onClicked:        bar.systemTabRequested("wifi")
    onHoveredChanged: if (hovered) bar.statusHoveredTab = "wifi"
                      else if (bar.statusHoveredTab === "wifi") bar.statusHoveredTab = ""
}
BluetoothWidget {
    id: btBtn
    active: bar.rightActive && (btBtn.hovered || SystemPanelState.rightOwner === "bluetooth")
    onClicked:        bar.systemTabRequested("bluetooth")
    onHoveredChanged: if (hovered) bar.statusHoveredTab = "bluetooth"
                      else if (bar.statusHoveredTab === "bluetooth") bar.statusHoveredTab = ""
}
```

with:

```qml
WifiLauncher {
    id: wifiBtn
    active: bar.rightActive && wifiBtn.hovered
}
BluetoothLauncher {
    id: btBtn
    active: bar.rightActive && btBtn.hovered
}
```

---

### Task 7: Add `TooltipPopup` to `WindowsBarScreen.qml`

**Files:**
- Modify: `environment/quickshell/modules/WindowsBarScreen.qml`

**Interfaces:**
- Consumes: `TooltipPopup`

- [ ] **Step 1: Add the popup instance near the bottom bar**

Add this block just after the `BottomBar { ... }` block at the end of the file:

```qml
    // ── Hover tooltip for TUI launcher widgets ────────────────────────────────
    TooltipPopup {
        screen: root.screen
    }
```

No other changes are required: because WiFi/Bluetooth no longer set `statusHoveredTab`, `effectiveOwner` will stay empty while hovering them and the side panel will not open.

---

### Task 8: Remove WiFi/Bluetooth panes from `SystemPanel.qml`

**Files:**
- Modify: `environment/quickshell/modules/SystemPanel.qml`

**Interfaces:**
- Produces: `SystemPanel` with only Battery and Display panes

- [ ] **Step 1: Clean up imports**

`Quickshell.Bluetooth` becomes unused after removing the Bluetooth pane. `Quickshell.Io` is still needed for the battery power-profile `Process`. Update imports to:

```qml
import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "./services"
```

- [ ] **Step 2: Delete the entire WiFi pane block (`wifiPane`)**

Lines from `// ════════════════════════════════════════════════════════════════════` above `// Wi-Fi pane` through the closing `}` of `wifiPane`.

- [ ] **Step 3: Delete the entire Bluetooth pane block (`btPane`)**

Lines from the second large comment block `// Bluetooth pane` through the closing `}` of `btPane`.

- [ ] **Step 4: Update the file header comment**

Change:

```qml
// SystemPanel — right-side panel with Wi-Fi, Bluetooth, and Battery sections.
```

to:

```qml
// SystemPanel — right-side panel with Battery and Display sections.
```

- [ ] **Step 5: Verify `currentTab === "battery"` and `currentTab === "display"` are the only tab checks**

Run:

```bash
rg 'currentTab ===' /home/kalin/environment/quickshell/modules/SystemPanel.qml
```

Expected output should only show `"battery"` and `"display"`.

---

### Task 9: Add `bluetuith` to the system packages

**Files:**
- Modify: `home-config/desktop.nix`

- [ ] **Step 1: Add `bluetuith` to `environment.systemPackages`**

In the `# connectivity` section (around line 289), change:

```nix
    # connectivity
    openconnect
```

to:

```nix
    # connectivity
    openconnect
    bluetuith
```

---

### Task 10: Add niri window rules for floating TUI terminals

**Files:**
- Modify: `~/.config/niri/conf.d/40-window-rules.kdl`

- [ ] **Step 1: Add rules for `nmtui` and `bluetuith`**

Append to the end of the file:

```kdl
// NetworkManager / Bluetooth TUI apps launched from Quickshell
window-rule {
    match title="^nmtui$"
    open-floating true
    default-column-width { fixed 900; }
    default-window-height { fixed 580; }
}

window-rule {
    match title="^bluetuith$"
    open-floating true
    default-column-width { fixed 900; }
    default-window-height { fixed 580; }
}
```

- [ ] **Step 2: Validate niri config (optional)**

If `niri` is running:

```bash
niri msg action reload-config
```

Check `journalctl --user -u niri -n 20` for parse errors.

---

### Task 11: Delete the old WiFi/Bluetooth widgets

**Files:**
- Delete: `environment/quickshell/modules/widgets/WifiWidget.qml`
- Delete: `environment/quickshell/modules/widgets/BluetoothWidget.qml`

- [ ] **Step 1: Remove the files**

```bash
rm /home/kalin/environment/quickshell/modules/widgets/WifiWidget.qml
rm /home/kalin/environment/quickshell/modules/widgets/BluetoothWidget.qml
```

- [ ] **Step 2: Verify nothing imports them**

```bash
rg 'WifiWidget|BluetoothWidget' /home/kalin/environment/quickshell
```

Expected: no matches.

---

### Task 12: Test Quickshell load

**Files:**
- All modified QML files

- [ ] **Step 1: Load the config**

```bash
qs -p /home/kalin/environment/quickshell
```

Expected output contains:

```
INFO: Configuration Loaded
```

- [ ] **Step 2: Kill the test shell so it does not stay on screen**

```bash
pkill -f "qs -p /home/kalin/environment/quickshell"
```

---

### Task 13: Rebuild NixOS and reload niri

**Files:**
- `home-config/desktop.nix`
- `~/.config/niri/conf.d/40-window-rules.kdl`

- [ ] **Step 1: Rebuild**

```bash
sudo nixos-rebuild switch --flake /home/kalin/home-config#KalinBook
```

- [ ] **Step 2: Reload niri config**

```bash
niri msg action reload-config
```

- [ ] **Step 3: Verify `bluetuith` is on PATH**

```bash
command -v bluetuith
```

Expected: prints a store path like `/run/current-system/sw/bin/bluetuith`.

---

### Task 14: Manual runtime verification

- [ ] **Hover WiFi icon**
  - A small tooltip appears above the bar showing SSID/strength or "WiFi disconnected".
  - No side panel opens.

- [ ] **Click WiFi icon**
  - `nmtui` opens in a floating, centered `foot` window.
  - Any previously pinned side panel closes.

- [ ] **Hover Bluetooth icon**
  - Tooltip shows Bluetooth state + connected count.
  - No side panel opens.

- [ ] **Click Bluetooth icon**
  - `bluetuith` opens in a floating, centered `foot` window.

- [ ] **Verify remaining drawers**
  - Volume, Display, Clock, Stats, Battery panels still open/close normally.
