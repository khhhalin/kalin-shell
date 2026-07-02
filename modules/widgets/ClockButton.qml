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

    Rectangle {
        anchors.fill: parent
        radius: BarConfig.buttonRadius
        color: root.active ? "#2f2f2f" : (root.hovered ? "#2a2a2a" : "transparent")
        border.width: root.active ? 1 : 0
        border.color: "#3a3a3a"

        Text {
            id: timeText
            anchors.centerIn: parent
            text: Qt.formatDateTime(new Date(), "HH:mm")
            color: "#e6e6e6"
            font.pixelSize: BarConfig.clockFontSize
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
