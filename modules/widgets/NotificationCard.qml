import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import "../services"

// A single notification popup card. Auto-dismisses after its timeout; click ✕
// (or an action) to dismiss early.
Rectangle {
    id: card

    property var notif: null

    radius: 10
    color: Theme.surface
    border.color: notif && notif.urgency === 2 ? Theme.error : Theme.border
    border.width: 1
    implicitHeight: layout.implicitHeight + 20

    // Auto-dismiss. urgency 2 (critical) ignores the timeout and stays.
    Timer {
        interval: card.notif && card.notif.expireTimeout > 0 ? card.notif.expireTimeout : 5000
        running: card.notif ? card.notif.urgency !== 2 : false
        onTriggered: NotificationService.dismiss(card.notif)
    }

    RowLayout {
        id: layout
        anchors.fill: parent
        anchors.margins: 10
        spacing: 10

        IconImage {
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            Layout.alignment: Qt.AlignTop
            source: card.notif ? (card.notif.appIcon || "") : ""
            visible: source.toString().length > 0
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 3

            Text {
                Layout.fillWidth: true
                text: card.notif ? (card.notif.summary || card.notif.appName || "") : ""
                color: Theme.text
                font.bold: true
                font.pixelSize: 13
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: text.length > 0
                text: card.notif ? (card.notif.body || "") : ""
                color: Theme.textSecondary
                font.pixelSize: 12
                wrapMode: Text.WordWrap
                maximumLineCount: 4
                elide: Text.ElideRight
                textFormat: Text.PlainText
            }

            Row {
                spacing: 6
                visible: card.notif && card.notif.actions && card.notif.actions.length > 0
                Repeater {
                    model: card.notif ? card.notif.actions : []
                    delegate: Rectangle {
                        required property var modelData
                        width: aLabel.implicitWidth + 16
                        height: 24
                        radius: 6
                        color: Theme.surfaceActive
                        Text {
                            id: aLabel
                            anchors.centerIn: parent
                            text: modelData.text || ""
                            color: Theme.text
                            font.pixelSize: 11
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                modelData.invoke()
                                NotificationService.dismiss(card.notif)
                            }
                        }
                    }
                }
            }
        }

        Text {
            Layout.alignment: Qt.AlignTop
            text: "✕"
            color: Theme.textSecondary
            font.pixelSize: 12
            MouseArea {
                anchors.fill: parent
                anchors.margins: -6
                cursorShape: Qt.PointingHandCursor
                onClicked: NotificationService.dismiss(card.notif)
            }
        }
    }
}
