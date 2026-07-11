import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "./widgets"
import "./services"

PanelWindow {
    id: bar

    required property ShellScreen screen

    // Caller controls height via this hint.
    property int heightHint: BarConfig.barHeight

    property bool rightActive: false

    signal rightClicked()
    signal requestCloseAll()
    // Relays right-click info up to WindowsBarScreen which owns the context menu PanelWindow.
    signal taskbarContextRequested(string appId, int buttonCenterX)
    // Relays hover info up for the live window-peek popup.
    signal taskbarPeekRequested(string appId, int buttonCenterX)
    signal taskbarPeekCleared()
    signal systemTabRequested(string tab)

    // True when clock or battery is hovered — the only two status widgets
    // still on the old SidePanel/rightOwner drawer system. stats/wifi/
    // bluetooth/volume/display all moved to DockedPanel (real docked TUI
    // apps, own hover/open state) and must NOT appear here: including them
    // made hovering e.g. the wifi button also pop the SidePanel drawer open
    // showing whatever SystemPanelState.rightOwner last was (usually
    // "battery"), visually obstructing the real docked panel underneath.
    readonly property bool rightHovered: rightButton.hovered
                                      || batBtn.hovered

    // Which status widget is currently hovered ("stats"|"wifi"|"bluetooth"|"battery"|"volume"|"display"|"clock"|"")
    property string statusHoveredTab: ""

    implicitHeight: heightHint
    color: "transparent"

    anchors {
        left: true
        right: true
        bottom: true
    }

    // Reserve space like a taskbar
    exclusiveZone: implicitHeight
    exclusionMode: ExclusionMode.Auto

    WlrLayershell.layer: WlrLayer.Top
    // Never steal keyboard focus; the bar is purely informational.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "windows-bar:bar"

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Theme.bar

        Rectangle {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            height: 1
            color: Theme.surface
            // When a drawer is open, hiding this avoids a visible seam
            // between the bar and the roll-up panel.
            opacity: bar.rightActive ? 0 : 1
        }

        // Close panels when right-clicking empty bar area.
        // Declared first so it sits below all buttons in z-order and only fires
        // when no button's own MouseArea consumed the event.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            propagateComposedEvents: true
            onClicked: function(mouse) {
                bar.requestCloseAll()
                mouse.accepted = false
            }
        }

        // Running / pinned app icons — starts at the left edge.
        TaskbarRow {
            id: taskbarRow
            anchors.left:           parent.left
            anchors.leftMargin:     BarConfig.edgePadding
            anchors.verticalCenter: parent.verticalCenter
            onContextRequested: (appId, x) => bar.taskbarContextRequested(appId, x)
            onPeekRequested:    (appId, x) => bar.taskbarPeekRequested(appId, x)
            onPeekCleared:      bar.taskbarPeekCleared()
        }

        // Center: workspaces
        WorkspaceIndicator {
            id: workspaces
            anchors.centerIn: parent
        }

        // Right: status indicators (WiFi · BT · Battery) + clock
        Row {
            id: statusRow
            anchors.right:         rightButton.left
            anchors.rightMargin:   BarConfig.edgePadding
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            // Now-playing (MPRIS), collapses when nothing is playing.
            MediaWidget {
                anchors.verticalCenter: parent.verticalCenter
            }

            // StatusNotifier (system tray) icons, left of the status widgets.
            SystemTrayRow {
                anchors.verticalCenter: parent.verticalCenter
            }

            // Real, riced TUI apps docked into the bar's own layout (kalin-wm
            // only; inert elsewhere) via DockedPanel.qml, independent of the
            // right-side SidePanel/rightOwner system the QML-rendered panels
            // below still use (BatteryWidget, DisplayWidget's placeholder).
            SystemStatsWidget {
                id: statsBtn
                anchors.verticalCenter: parent.verticalCenter
                active: statsPanel.open
                onHoveredChanged: statsPanel.buttonHover = hovered
                onClicked: statsPanel.togglePin()
            }
            DockedPanel {
                id: statsPanel
                // Per-monitor app_id (one bar per screen now — see
                // WindowsBar.qml) so each monitor docks/spawns its own real
                // btop instead of every monitor's bar fighting over the same
                // client_find_by_appid() match in the compositor.
                appId: "kalin-stats-panel-" + bar.screen.name
                command: ["foot", "--app-id=" + statsPanel.appId, "-e", "btop"]
                screen: bar.screen
                barHeight: bar.heightHint
            }

            WifiLauncher {
                id: wifiBtn
                active: wifiPanel.open
                onHoveredChanged: wifiPanel.buttonHover = hovered
                onClicked: wifiPanel.togglePin()
            }
            DockedPanel {
                id: wifiPanel
                appId: "kalin-wifi-panel-" + bar.screen.name
                command: ["foot", "--app-id=" + wifiPanel.appId, "-e", "nmtui"]
                screen: bar.screen
                barHeight: bar.heightHint
            }

            BluetoothLauncher {
                id: btBtn
                active: btPanel.open
                onHoveredChanged: btPanel.buttonHover = hovered
                onClicked: btPanel.togglePin()
            }
            DockedPanel {
                id: btPanel
                appId: "kalin-bt-panel-" + bar.screen.name
                command: ["foot", "--app-id=" + btPanel.appId, "-e", "bluetuith"]
                screen: bar.screen
                barHeight: bar.heightHint
            }

            BatteryWidget {
                id: batBtn
                active: bar.rightActive && (batBtn.hovered || SystemPanelState.rightOwner === "battery")
                onClicked:        bar.systemTabRequested("battery")
                onHoveredChanged: if (hovered) bar.statusHoveredTab = "battery"
                                  else if (bar.statusHoveredTab === "battery") bar.statusHoveredTab = ""
            }

            VolumeWidget {
                id: volBtn
                active: volPanel.open
                onHoveredChanged: volPanel.buttonHover = hovered
                onClicked: volPanel.togglePin()
            }
            DockedPanel {
                id: volPanel
                appId: "kalin-volume-panel-" + bar.screen.name
                command: ["foot", "--app-id=" + volPanel.appId, "-e", "wiremix"]
                screen: bar.screen
                barHeight: bar.heightHint
            }

            DisplayWidget {
                id: displayBtn
                active: displayPanel.open
                onHoveredChanged: displayPanel.buttonHover = hovered
                onClicked: displayPanel.togglePin()
            }
            DockedPanel {
                id: displayPanel
                appId: "kalin-display-panel-" + bar.screen.name
                // Note: the executable is also literally named
                // kalin-display-panel (a home-config-provided script) — only
                // the --app-id= argument gets the per-monitor suffix.
                command: ["foot", "--app-id=" + displayPanel.appId, "-e", "kalin-display-panel"]
                screen: bar.screen
                barHeight: bar.heightHint
            }

            ClipboardButton {
                id: clipBtn
                active: clipPanel.open
                onHoveredChanged: clipPanel.buttonHover = hovered
                onClicked: clipPanel.togglePin()
            }
            DockedPanel {
                id: clipPanel
                appId: "kalin-clip-panel-" + bar.screen.name
                command: ["foot", "--app-id=" + clipPanel.appId, "-e", "kalin-clip-picker-loop"]
                screen: bar.screen
                barHeight: bar.heightHint
            }
        }

        // Right: clock button
        ClockButton {
            id: rightButton
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.rightMargin: BarConfig.clockRightMargin
            width: BarConfig.clockWidth

            active: bar.rightActive && (rightButton.hovered
                    || (bar.statusHoveredTab === "" && SystemPanelState.rightOwner === "clock"))

            onHoveredChanged: {
                if (hovered) bar.statusHoveredTab = "clock"
                else if (bar.statusHoveredTab === "clock") bar.statusHoveredTab = ""
            }

            onClicked: bar.rightClicked()
        }
    }
}
