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

    // TUI-box treatment (same language as the screenshot UI's info panel):
    // an always-visible hairline frame that snaps to amber on hover/active,
    // amber text when the panel is open — instead of soft hover fills.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: BarConfig.buttonRadius
        color: root.active ? Theme.surfaceAlt : "transparent"
        border.width: 1
        border.color: root.active ? Theme.accent
                    : (root.hovered ? Theme.accent : Theme.borderSubtle)

        Text {
            id: labelText
            anchors.centerIn: parent
            text: root.icon
            color: root.active ? Theme.accent : (root.hovered ? Theme.text : Theme.textDim)
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
