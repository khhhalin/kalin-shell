import QtQuick
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// MediaWidget — compact now-playing indicator for the bar's status row.
//   left-click  → play/pause      right-click → next
//   wheel       → previous / next
// Collapses to zero width when no MPRIS player is present.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    readonly property bool show: MediaService.hasPlayer
    visible: show
    implicitHeight: BarConfig.barHeight
    implicitWidth: show ? content.implicitWidth + 16 : 0

    Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 7
        anchors.bottomMargin: 7
        radius: BarConfig.buttonRadius
        color: hover.hovered ? Theme.surfaceAlt : "transparent"
    }

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 7

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:  MediaService.isPlaying ? "⏸" : "▶"
            color: Theme.accent
            font.pixelSize: 13
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text:  MediaService.artist.length > 0
                   ? MediaService.title + " — " + MediaService.artist
                   : MediaService.title
            color: Theme.textSecondary
            font.pixelSize: 12
            elide:  Text.ElideRight
            width:  Math.min(implicitWidth, 200)
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        anchors.fill: parent
        cursorShape:  Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) MediaService.next()
            else MediaService.toggle()
        }
        onWheel: wheel => {
            if (wheel.angleDelta.y > 0) MediaService.next()
            else MediaService.prev()
        }
    }
}
