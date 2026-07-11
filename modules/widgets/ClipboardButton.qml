import QtQuick
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// ClipboardButton — hover/click trigger for the docked clipboard-history
// terminal panel (see ../DockedPanel.qml, instantiated in BottomBar.qml).
// Static icon, no polling — unlike VolumeWidget/BatteryWidget there's no
// live status to reflect, the panel is either open or not.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool hovered: false
    property bool active:  false
    signal clicked()

    implicitWidth:  BarConfig.barHeight
    implicitHeight: BarConfig.barHeight

    Rectangle {
        anchors.fill: parent
        radius:       BarConfig.buttonRadius
        color:        root.active ? "#2f2f2f" : (root.hovered ? "#2a2a2a" : "transparent")
        border.width: root.active ? 1 : 0
        border.color: "#3a3a3a"

        Text {
            anchors.centerIn: parent
            text:            "📋"
            color:           "#e6e6e6"
            font.pixelSize:  BarConfig.railIconSize
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered:    root.hovered = true
        onExited:     root.hovered = false
        onClicked:    root.clicked()
    }
}
