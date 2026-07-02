import QtQuick
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// CalendarPanel — placeholder for future Google Calendar integration.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    Column {
        anchors.centerIn: parent
        spacing: 14

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:            "󰃭"
            font.pixelSize:  64
            font.family:     "monospace"
            color:           "#4a9eff"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:            Qt.formatDate(new Date(), "dddd, MMMM d")
            color:           "#e6e6e6"
            font.pixelSize:  15
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:            Qt.formatDate(new Date(), "yyyy")
            color:           "#888888"
            font.pixelSize:  12
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 160; height: 1; color: "#2a2a2a"
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text:            "Google Calendar\ncoming soon"
            horizontalAlignment: Text.AlignHCenter
            color:           "#555555"
            font.pixelSize:  12
            lineHeight:      1.5
        }
    }
}
