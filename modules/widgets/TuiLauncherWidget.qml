import QtQuick
import Quickshell
import "../services"

// Generic bar widget that launches a TUI app on click.
Item {
    id: root

    property string tabName: ""
    property string icon: ""
    property bool active: false

    property bool hovered: false

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
}
