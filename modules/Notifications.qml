import QtQuick
import Quickshell
import Quickshell.Wayland

import "./services"
import "./widgets"

// ─────────────────────────────────────────────────────────────────────────────
// Notifications — top-right popup stack, one per screen. Masked to the cards so
// the rest of the surface is click-through. Cards self-dismiss on timeout.
// ─────────────────────────────────────────────────────────────────────────────
Variants {
    model: Quickshell.screens

    Scope {
        required property ShellScreen modelData

        PanelWindow {
            id: win
            screen: modelData
            visible: NotificationService.popups.length > 0
            color: "transparent"

            anchors { top: true; right: true; bottom: true }
            implicitWidth: 380

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer:         WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace:     "windows-bar:notifications"

            // Only the cards intercept input; the rest is click-through.
            mask: Region { item: col }

            Column {
                id: col
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.rightMargin: 10
                width: 360
                spacing: 8

                Repeater {
                    model: NotificationService.popups

                    delegate: NotificationCard {
                        required property var modelData
                        width: col.width
                        notif: modelData

                        opacity: 0
                        Component.onCompleted: opacity = 1
                        Behavior on opacity { NumberAnimation { duration: 140 } }
                    }
                }
            }
        }
    }
}
