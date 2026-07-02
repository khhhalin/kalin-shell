import QtQuick
import Quickshell

import "../services"

// Center-screen password prompt for Wi-Fi and other secure connections.
FloatingWindow {
    id: root

    visible: PromptState.visible

    title: "Network Password"
    implicitWidth: 360
    implicitHeight: 180
    color: "transparent"

    onVisibleChanged: {
        if (visible) {
            passwordField.text = ""
            Qt.callLater(passwordField.forceActiveFocus)
        }
    }

    Rectangle {
        anchors.fill: parent
        color: "#1f1f1f"
        radius: 12
        border.width: 1
        border.color: "#333333"

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 16

            Text {
                text: PromptState.pendingSsid
                      ? "Enter password for \"" + PromptState.pendingSsid + "\""
                      : "Enter password"
                color: "#e6e6e6"
                font.pixelSize: 15
                elide: Text.ElideRight
                width: parent.width
            }

            Rectangle {
                width: parent.width
                height: 36
                radius: 8
                color: "#2a2a2a"
                border.width: passwordField.activeFocus ? 1 : 0
                border.color: "#4fc3f7"

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.margins: 10
                    color: "#e6e6e6"
                    echoMode: TextInput.Password
                    passwordCharacter: "•"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    clip: true

                    Keys.onReturnPressed: PromptState.submit(text)
                    Keys.onEnterPressed: PromptState.submit(text)
                    Keys.onEscapePressed: PromptState.cancel()
                }
            }

            Row {
                anchors.right: parent.right
                spacing: 10

                Rectangle {
                    width: 80; height: 32; radius: 8
                    color: cancelMa.containsMouse ? "#3a3a3a" : "#2a2a2a"

                    Text {
                        anchors.centerIn: parent
                        text: "Cancel"
                        color: "#cccccc"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: cancelMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PromptState.cancel()
                    }
                }

                Rectangle {
                    width: 80; height: 32; radius: 8
                    color: connectMa.containsMouse ? "#3a4a5a" : "#2a4a6a"

                    Text {
                        anchors.centerIn: parent
                        text: "Connect"
                        color: "#4fc3f7"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: connectMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: PromptState.submit(passwordField.text)
                    }
                }
            }
        }
    }
}
