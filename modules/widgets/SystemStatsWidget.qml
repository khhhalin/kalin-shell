import QtQuick
import Quickshell

import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// SystemStatsWidget — compact CPU / RAM / GPU readout for the status row.
// Data comes from the SystemStats singleton, which polls every 2 s.
// Click/hover opens a detailed stats drawer, same as the other status widgets.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool active: false
    property bool hovered: false

    signal clicked()

    readonly property string label: {
        const c = SystemStats.ready ? Math.round(SystemStats.cpu) : "--"
        const r = SystemStats.ready ? Math.round(SystemStats.ram) : "--"
        const g = SystemStats.ready ? Math.round(SystemStats.gpu) : "--"
        return "󰻠 " + c + "%  󰍛 " + r + "%  󰢮 " + g + "%"
    }

    implicitWidth:  Math.max(statsText.implicitWidth + 20, 140)
    implicitHeight: BarConfig.barHeight

    Rectangle {
        anchors.fill: parent
        radius:       BarConfig.buttonRadius
        color:        root.active ? Theme.surfaceAlt : (root.hovered ? Theme.surface : "transparent")
        border.width: 0

        Text {
            id:              statsText
            anchors.centerIn: parent
            text:            root.label
            color:           Theme.text
            font.pixelSize:  BarConfig.clockFontSize
            font.family:     "monospace"
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
