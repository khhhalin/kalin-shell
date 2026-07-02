import QtQuick
import Quickshell
import Quickshell.Wayland

import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// Osd — transient overlay that flashes the infinite-canvas camera state
// (zoom %, follow mode) whenever it changes. Driven entirely by KalinViewport,
// so it is inert on niri (where KalinViewport never connects).
// ─────────────────────────────────────────────────────────────────────────────
Variants {
    model: Quickshell.screens

    Scope {
        id: osdScope
        required property ShellScreen modelData

        // Track changes so we only flash on an actual zoom/follow transition,
        // not on every state broadcast (which fires on each printstatus()).
        property real lastZoom: KalinViewport.zoom
        property bool lastFollow: KalinViewport.follow
        property string label: ""

        Connections {
            target: KalinViewport
            function onStateChanged() {
                if (!KalinViewport.available) return
                if (Math.abs(KalinViewport.zoom - osdScope.lastZoom) > 0.001) {
                    osdScope.label = Math.round(KalinViewport.zoom * 100) + "%"
                    osd.flash()
                } else if (KalinViewport.follow !== osdScope.lastFollow) {
                    osdScope.label = "follow " + (KalinViewport.follow ? "on" : "off")
                    osd.flash()
                }
                osdScope.lastZoom = KalinViewport.zoom
                osdScope.lastFollow = KalinViewport.follow
            }
        }

        PanelWindow {
            id: osd
            screen: modelData
            visible: opacityAnim.running || content.opacity > 0.01
            color: "transparent"

            anchors { bottom: true }
            margins.bottom: 120
            implicitWidth: 160
            implicitHeight: 56

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "windows-bar:osd"

            function flash(): void {
                content.opacity = 1
                hideTimer.restart()
            }

            Rectangle {
                id: content
                anchors.centerIn: parent
                width: label.implicitWidth + 36
                height: 40
                radius: 12
                color: Theme.scrim
                border.color: Theme.border
                border.width: 1
                opacity: 0
                Behavior on opacity { NumberAnimation { id: opacityAnim; duration: 180 } }

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: osdScope.label
                    color: Theme.textBright
                    font.pixelSize: 16
                    font.bold: true
                }
            }

            Timer {
                id: hideTimer
                interval: 1100
                repeat: false
                onTriggered: content.opacity = 0
            }
        }
    }
}
