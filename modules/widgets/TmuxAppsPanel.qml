import QtQuick
import Quickshell.Io

import "../services"

// List of tmux app windows in the single session.
FocusScope {
    id: root

    // When true, refresh periodically.
    property bool active: false

    // Edit mode controls
    property bool editMode: false
    property real fontScale: 1.0

    signal toggleEditRequested()
    signal fontScaleDelta(int delta)

    // Track selection for keyboard delete.
    property int selectedIndex: -1

    Component.onCompleted: TmuxService.refresh()
    onActiveChanged: if (active) TmuxService.refresh()

    // Allow Delete/Backspace to kill the selected window.
    focus: true
    Keys.onPressed: event => {
        if (!root.active) return
        if (event.key === Qt.Key_E) {
            root.toggleEditRequested()
            event.accepted = true
            return
        }
        if (root.editMode && (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.text === "+")) {
            root.fontScaleDelta(1)
            event.accepted = true
            return
        }
        if (root.editMode && (event.key === Qt.Key_Minus || event.text === "-")) {
            root.fontScaleDelta(-1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            const idx = root.selectedIndex
            if (idx >= 0 && idx < TmuxService.windows.length) {
                const win = TmuxService.windows[idx]
                if (win) TmuxService.killWindow(win.index)
            }
            event.accepted = true
        }
    }

    Timer {
        interval: 5000
        running: root.active
        repeat: true
        onTriggered: TmuxService.refresh()
    }

    function _scale(px) { return Math.max(8, Math.round(px * root.fontScale)) }

    Item {
        id: editBar
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: 16; rightMargin: 16; topMargin: 10 }
        height: 30

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Edit mode"
                color: "#8d8d8d"
                font.pixelSize: root._scale(11)
                font.capitalization: Font.AllUppercase
            }

            Rectangle {
                width: 54; height: 22; radius: 6
                color: root.editMode ? "#2f3a2f" : "#2a2a2a"

                Text {
                    anchors.centerIn: parent
                    text: root.editMode ? "ON" : "OFF"
                    color: root.editMode ? "#9be29b" : "#a0a0a0"
                    font.pixelSize: root._scale(10)
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.toggleEditRequested()
                }
            }
        }

        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Rectangle {
                width: 28; height: 22; radius: 6
                color: "#2a2a2a"
                Text { anchors.centerIn: parent; text: "–"; color: "#e6e6e6"; font.pixelSize: root._scale(12) }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fontScaleDelta(-1)
                }
            }

            Rectangle {
                width: 28; height: 22; radius: 6
                color: "#2a2a2a"
                Text { anchors.centerIn: parent; text: "+"; color: "#e6e6e6"; font.pixelSize: root._scale(12) }
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fontScaleDelta(1)
                }
            }
        }
    }

    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: editBar.bottom
                  leftMargin: 16; rightMargin: 16; topMargin: 8 }
        height: 28

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "Tmux Apps"
            color: "#888888"
            font.pixelSize: root._scale(11)
            font.capitalization: Font.AllUppercase
        }

        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 60; height: 26; radius: 6
            color: refreshMa.containsMouse ? "#3a3a3a" : "#2a2a2a"

            Text { anchors.centerIn: parent; text: "Refresh"; color: "#e6e6e6"; font.pixelSize: root._scale(11) }

            MouseArea {
                id: refreshMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: TmuxService.refresh()
            }
        }
    }

    Rectangle {
        anchors { left: parent.left; right: parent.right; top: header.bottom; bottom: parent.bottom
                  leftMargin: 0; rightMargin: 0; topMargin: 6 }
        radius: 10
        color: "#2a2a2a"
        clip: true

        ListView {
            id: list
            anchors.fill: parent
            anchors.margins: 6
            spacing: 2
            model: TmuxService.windows
            currentIndex: root.selectedIndex

            delegate: Rectangle {
                id: row
                required property var modelData

                width: list.width
                height: 36
                radius: 8
                color: (ListView.isCurrentItem || rowMa.containsMouse) ? "#252525" : "transparent"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.active ? "•" : " "
                        color: modelData.active ? "#4fc3f7" : "#888888"
                        font.pixelSize: root._scale(18)
                        width: 10
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.name
                        color: "#e6e6e6"
                        font.pixelSize: root._scale(12)
                        elide: Text.ElideRight
                        width: list.width - 120
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "#" + modelData.index
                        color: "#888888"
                        font.pixelSize: root._scale(11)
                    }

                    // Trash icon button
                    Rectangle {
                        id: trashBtn
                        width: 24; height: 24; radius: 6
                        color: trashMa.containsMouse ? "#3b2a2a" : "#262626"

                        Text { anchors.centerIn: parent; text: "🗑"; color: "#e6e6e6"; font.pixelSize: root._scale(13) }

                        MouseArea {
                            id: trashMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                TmuxService.killWindow(modelData.index)
                            }
                        }
                    }
                }

                MouseArea {
                    id: rowMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    z: -1
                    onClicked: {
                        const idx = list.indexAt(row.x + row.width / 2, row.y + row.height / 2)
                        if (idx >= 0) root.selectedIndex = idx
                        TmuxService.attachWindow(modelData.index)
                    }
                }
            }
        }

        Text {
            anchors.centerIn: parent
            visible: TmuxService.windows.length === 0
            text: "No tmux app windows"
            color: "#9a9a9a"
            font.pixelSize: root._scale(12)
        }
    }
}
