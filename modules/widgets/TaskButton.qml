import QtQuick
import QtQuick.Effects
import "../services"

Item {
    id: root

    property bool active: false
    property bool hovered: false

    property url iconSource: ""
    property string tooltip: ""

    signal clicked()

    implicitWidth:  BarConfig.barHeight
    implicitHeight: BarConfig.barHeight

    Rectangle {
        anchors.fill: parent
        radius: BarConfig.buttonRadius
        color: root.active ? "#2f2f2f" : (root.hovered ? "#2a2a2a" : "transparent")
        border.width: root.active ? 1 : 0
        border.color: "#3a3a3a"

        Image {
            anchors.centerIn: parent
            width:  BarConfig.railIconSize
            height: BarConfig.railIconSize
            source: root.iconSource
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true
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
