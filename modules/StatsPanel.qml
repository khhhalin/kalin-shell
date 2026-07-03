import QtQuick
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// StatsPanel — detailed CPU / RAM / GPU usage drawer.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    Column {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 18

        Text {
            text: "System Stats"
            color: "#e6e6e6"
            font.pixelSize: 15
            font.weight: Font.Medium
        }

        // CPU
        StatRow {
            width: parent.width
            label: "CPU"
            value: SystemStats.ready ? Math.round(SystemStats.cpu) + "%" : "--"
            percent: SystemStats.ready ? SystemStats.cpu : 0
            icon: "󰻠"
        }

        // RAM
        StatRow {
            width: parent.width
            label: "RAM"
            value: SystemStats.ready ? Math.round(SystemStats.ram) + "%" : "--"
            percent: SystemStats.ready ? SystemStats.ram : 0
            icon: "󰍛"
        }

        // GPU
        StatRow {
            width: parent.width
            label: SystemStats.gpuName || "GPU"
            value: SystemStats.ready ? Math.round(SystemStats.gpu) + "%" : "--"
            percent: SystemStats.ready ? SystemStats.gpu : 0
            icon: "󰢮"
        }
    }

    component StatRow: Column {
        property string label: ""
        property string value: "--"
        property real percent: 0
        property string icon: ""

        spacing: 6

        Row {
            width: parent.width
            spacing: 8

            Text {
                text: parent.parent.icon
                color: "#4fc3f7"
                font.pixelSize: 14
                font.family: "monospace"
                width: 20
            }

            Text {
                text: parent.parent.label
                color: "#e6e6e6"
                font.pixelSize: 13
            }

            Item { width: parent.width - parent.children[0].width - parent.children[1].width - parent.children[3].implicitWidth - 16; height: 1 }

            Text {
                text: parent.parent.value
                color: "#e6e6e6"
                font.pixelSize: 13
                font.family: "monospace"
            }
        }

        Rectangle {
            width: parent.width
            height: 6
            radius: 3
            color: "#2a2a2a"

            Rectangle {
                width: parent.width * (Math.max(0, Math.min(100, parent.parent.percent)) / 100)
                height: parent.height
                radius: parent.radius
                color: parent.parent.percent > 80 ? "#ff6b6b" : (parent.parent.percent > 50 ? "#ffd060" : "#4fc3f7")
            }
        }
    }
}
