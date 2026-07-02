import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// SystemTrayRow — StatusNotifierItem (system tray) icons for the bottom bar.
// Self-contained: drop `SystemTrayRow {}` into the bar's right-hand status
// section. Left-click activates an item, right-click opens its menu.
// ─────────────────────────────────────────────────────────────────────────────
Row {
    id: root
    spacing: 6

    Repeater {
        model: SystemTray.items

        delegate: Item {
            required property var modelData
            width: BarConfig.railIconSize + 8
            height: BarConfig.railIconSize + 8

            IconImage {
                anchors.centerIn: parent
                width: BarConfig.railIconSize
                height: BarConfig.railIconSize
                source: modelData.icon
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.LeftButton)
                        modelData.activate()
                    else if (mouse.button === Qt.MiddleButton)
                        modelData.secondaryActivate()
                    else if (mouse.button === Qt.RightButton && modelData.hasMenu)
                        modelData.display(root, width / 2, height)
                }
            }
        }
    }
}
