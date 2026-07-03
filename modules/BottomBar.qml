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

    property bool leftActive: false
    property bool rightActive: false

    // Provided by controller (still used for pin logic elsewhere).
    property bool leftPinned: false

    // Visual padding on the left edge to keep the menu icon centered
    // between the screen edge and the search box.
    property int leftEdgePadding: BarConfig.edgePadding

    signal leftClicked()
    signal rightClicked()
    signal requestCloseAll()
    // Relays right-click info up to WindowsBarScreen which owns the context menu PanelWindow.
    signal taskbarContextRequested(string appId, int buttonCenterX)
    // Relays hover info up for the live window-peek popup.
    signal taskbarPeekRequested(string appId, int buttonCenterX)
    signal taskbarPeekCleared()
    signal systemTabRequested(string tab)

    // Hovering anywhere in the bar under the left panel keeps it open.
    // Set this to panelWidth from WindowsBarScreen.
    property int panelHoverWidth: BarConfig.panelWidth

    property bool leftHovered: false
    // True when clock or any status widget is hovered — drives right panel open.
    readonly property bool rightHovered: statsBtn.hovered
                                      || rightButton.hovered
                                      || wifiBtn.hovered
                                      || btBtn.hovered
                                      || batBtn.hovered
                                      || volBtn.hovered
                                      || displayBtn.hovered

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
    // Grab the keyboard (Exclusive) ONLY when the launcher is deliberately
    // opened by click (leftPinned) — hovering the panel open must NOT steal
    // keyboard focus from application windows. Use None (not OnDemand) at idle:
    // Quickshell 0.3.0 sends OnDemand to the compositor as an EXCLUSIVE grab,
    // which would starve every window of keyboard input.
    WlrLayershell.keyboardFocus: bar.leftPinned
        ? WlrKeyboardFocus.Exclusive
        : WlrKeyboardFocus.None
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
            opacity: (bar.leftActive || bar.rightActive) ? 0 : 1
        }

        // Left button
        TaskButton {
            id: leftButton
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.leftMargin: bar.leftEdgePadding
            width: implicitHeight

            active: bar.leftActive
            iconSource: Qt.resolvedUrl("../assets/nixos.svg")
            tooltip: "Menu"

            onHoveredChanged: bar.leftHovered = leftButton.hovered || panelZone.hovered

            onClicked: bar.leftClicked()
        }

        // Invisible hover zone spanning the full panel width.
        // Keeps the panel alive when the cursor is in the bar directly below it.
        Item {
            id: panelZone
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: bar.panelHoverWidth

            property bool hovered: false

            HoverHandler {
                onHoveredChanged: {
                    panelZone.hovered = hovered
                    bar.leftHovered = hovered || leftButton.hovered
                }
            }
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

        // Running / pinned app icons — positioned just right of the menu button.
        TaskbarRow {
            id: taskbarRow
            anchors.left:           leftButton.right
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

            SystemStatsWidget {
                id: statsBtn
                anchors.verticalCenter: parent.verticalCenter
                active: bar.rightActive && (statsBtn.hovered || SystemPanelState.rightOwner === "stats")
                onClicked:        bar.systemTabRequested("stats")
                onHoveredChanged: if (hovered) bar.statusHoveredTab = "stats"
                                  else if (bar.statusHoveredTab === "stats") bar.statusHoveredTab = ""
            }

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
            BatteryWidget {
                id: batBtn
                active: bar.rightActive && (batBtn.hovered || SystemPanelState.rightOwner === "battery")
                onClicked:        bar.systemTabRequested("battery")
                onHoveredChanged: if (hovered) bar.statusHoveredTab = "battery"
                                  else if (bar.statusHoveredTab === "battery") bar.statusHoveredTab = ""
            }
            VolumeWidget {
                id: volBtn
                active: bar.rightActive && (volBtn.hovered || SystemPanelState.rightOwner === "volume")
                onClicked:        bar.systemTabRequested("volume")
                onHoveredChanged: if (hovered) bar.statusHoveredTab = "volume"
                                  else if (bar.statusHoveredTab === "volume") bar.statusHoveredTab = ""
            }
            DisplayWidget {
                id: displayBtn
                active: bar.rightActive && (displayBtn.hovered || SystemPanelState.rightOwner === "display")
                onClicked:        bar.systemTabRequested("display")
                onHoveredChanged: if (hovered) bar.statusHoveredTab = "display"
                                  else if (bar.statusHoveredTab === "display") bar.statusHoveredTab = ""
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
