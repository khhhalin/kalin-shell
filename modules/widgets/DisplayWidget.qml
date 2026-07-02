import QtQuick
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// DisplayWidget — opens the Display settings tab in the right system panel.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool hovered: false
    property bool active:  false
    signal clicked()

    readonly property string label: "󰍹"

    implicitWidth:  Math.max(iconText.implicitWidth + 20, 64)
    implicitHeight: BarConfig.barHeight

    Rectangle {
        anchors.fill: parent
        radius:       BarConfig.buttonRadius
        color:        root.active ? "#2f2f2f" : (root.hovered ? "#2a2a2a" : "transparent")
        border.width: root.active ? 1 : 0
        border.color: "#3a3a3a"

        Text {
            id:              iconText
            anchors.centerIn: parent
            text:            root.label
            color:           DisplayService.available ? "#e6e6e6" : "#555555"
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
