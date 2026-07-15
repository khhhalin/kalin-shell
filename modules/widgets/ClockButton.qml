import QtQuick
import "../services"

Item {
    id: root

    property bool active: false
    property bool hovered: false

    signal clicked()

    implicitWidth:  BarConfig.clockWidth
    implicitHeight: BarConfig.barHeight

    Timer {
        id: tick
        interval: 1000
        running: true
        repeat: true
        onTriggered: timeText.text = Qt.formatDateTime(new Date(), "HH:mm")
    }

    // TUI-box treatment, same as TuiLauncherWidget (pre-rice grays replaced
    // with Theme tokens).
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: BarConfig.buttonRadius
        color: root.active ? Theme.surfaceAlt : "transparent"
        border.width: 1
        border.color: root.active ? Theme.accent
                    : (root.hovered ? Theme.accent : Theme.borderSubtle)

        Text {
            id: timeText
            anchors.centerIn: parent
            text: Qt.formatDateTime(new Date(), "HH:mm")
            color: root.active ? Theme.accent : (root.hovered ? Theme.text : Theme.textDim)
            font.pixelSize: BarConfig.clockFontSize
            font.family: "monospace"
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

        onEntered: {
            root.hovered = true
        }
        onExited: {
            root.hovered = false
        }

        onClicked: root.clicked()
    }
}
