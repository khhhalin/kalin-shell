import QtQuick
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// DisplayPanel — right-side panel that lists connected outputs and lets the
// user reorder them left-to-right, change brightness, cycle resolution modes,
// and cycle scale under niri.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    // ── Header with reset button ──────────────────────────────────────────────
    Item {
        id: header
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: 16; rightMargin: 16; topMargin: 14 }
        height: 28

        Text {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            text: "Displays"
            color: "#e6e6e6"
            font.pixelSize: 15
        }

        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            width: 80; height: 26; radius: 6
            color: resetMa.containsMouse ? "#2a4a2a" : "#2a2a2a"
            visible: DisplayService.available && DisplayService.outputs.length > 0

            Text {
                anchors.centerIn: parent
                text: "Reset"
                color: "#cccccc"
                font.pixelSize: 11
            }

            MouseArea {
                id: resetMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: DisplayService.resetToAuto()
            }
        }
    }

    // ── Unavailable / kalin-wm placeholder ────────────────────────────────────
    Text {
        anchors.centerIn: parent
        visible: !DisplayService.available
        text: DisplayService.unavailableReason || "Display configuration unavailable"
        color: "#555555"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
    }

    // ── Output list ───────────────────────────────────────────────────────────
    Flickable {
        anchors { left: parent.left; right: parent.right
                  top: header.bottom; bottom: parent.bottom; topMargin: 6 }
        contentHeight: displayCol.height
        clip: true
        visible: DisplayService.available

        Column {
            id: displayCol
            width: parent.width
            spacing: 2

            Repeater {
                model: DisplayService.outputs

                delegate: Rectangle {
                    required property var modelData
                    required property int index

                    width: displayCol.width
                    height: content.implicitHeight + 24
                    radius: 8
                    color: rowMa.containsMouse ? "#252525" : "transparent"

                    Column {
                        id: content
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 12; bottomMargin: 12 }
                        spacing: 10

                        // ── Name + reorder ──────────────────────────────────
                        Item {
                            width: parent.width
                            height: 28

                            Row {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                spacing: 10

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "󰍹"
                                    color: "#4fc3f7"
                                    font.pixelSize: 20
                                    font.family: "monospace"
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.name
                                    color: "#e6e6e6"
                                    font.pixelSize: 13
                                    font.weight: Font.Medium
                                }
                            }

                            Row {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 4

                                Rectangle {
                                    width: 28; height: 28; radius: 6
                                    color: upMa.containsMouse ? "#2a2a2a" : "transparent"
                                    visible: index > 0

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅿"
                                        color: "#cccccc"
                                        font.pixelSize: 14
                                        font.family: "monospace"
                                    }

                                    MouseArea {
                                        id: upMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DisplayService.moveOutput(index, index - 1)
                                    }
                                }

                                Rectangle {
                                    width: 28; height: 28; radius: 6
                                    color: downMa.containsMouse ? "#2a2a2a" : "transparent"
                                    visible: index < DisplayService.outputs.length - 1

                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅀"
                                        color: "#cccccc"
                                        font.pixelSize: 14
                                        font.family: "monospace"
                                    }

                                    MouseArea {
                                        id: downMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DisplayService.moveOutput(index, index + 1)
                                    }
                                }
                            }
                        }

                        // ── Make / model / resolution ───────────────────────
                        Text {
                            width: parent.width
                            text: {
                                const make = modelData.make || ""
                                const model = modelData.model || ""
                                const label = (make + " " + model).trim()
                                const mode = modelData.currentMode
                                const res = mode ? (mode.width + "×" + mode.height) : ""
                                const sep = label && res ? " · " : ""
                                return (label || res) ? (label + sep + res) : "Unknown display"
                            }
                            color: "#888888"
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }

                        // ── Brightness slider ───────────────────────────────
                        Item {
                            width: parent.width
                            height: 22
                            visible: modelData.brightnessControllable

                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "󰃞"
                                color: "#aaaaaa"
                                font.pixelSize: 14
                                font.family: "monospace"
                                width: 24
                            }

                            Item {
                                id: brightnessSlider
                                anchors { left: parent.left; right: parent.right
                                          leftMargin: 30; rightMargin: 44 }
                                height: parent.height

                                property real value: modelData.brightness
                                property real dragValue: -1
                                readonly property real effectiveValue: dragValue >= 0 ? dragValue : value

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width
                                    height: 4
                                    radius: 2
                                    color: "#3a3a3a"

                                    Rectangle {
                                        width: parent.width * brightnessSlider.effectiveValue
                                        height: parent.height
                                        radius: 2
                                        color: "#4fc3f7"
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    onPressed: {
                                        brightnessSlider.dragValue = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                    onPositionChanged: {
                                        if (pressed)
                                            brightnessSlider.dragValue = Math.max(0, Math.min(1, mouse.x / width))
                                    }
                                    onReleased: {
                                        DisplayService.setBrightness(modelData.name, brightnessSlider.dragValue)
                                        brightnessSlider.dragValue = -1
                                    }
                                }
                            }

                            Text {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                text: Math.round((brightnessSlider.effectiveValue || 0) * 100) + "%"
                                color: "#cccccc"
                                font.pixelSize: 11
                                width: 38
                                horizontalAlignment: Text.AlignRight
                            }
                        }

                        // ── Mode cycle ──────────────────────────────────────
                        Item {
                            width: parent.width
                            height: 26
                            visible: modelData.modes && modelData.modes.length > 0

                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "Mode"
                                color: "#888888"
                                font.pixelSize: 11
                                width: 46
                            }

                            Rectangle {
                                anchors { left: parent.left; right: parent.right
                                          leftMargin: 54; rightMargin: 64 }
                                height: 26
                                radius: 6
                                color: modeMa.containsMouse ? "#2a2a2a" : "#252525"

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        const m = modelData.currentMode
                                        if (!m) return "--"
                                        const hz = (m.refresh_rate / 1000.0).toFixed(3)
                                        return m.width + "×" + m.height + " @ " + hz + " Hz"
                                    }
                                    color: "#cccccc"
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: modeMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: DisplayService.cycleMode(modelData.name, 1)
                                }
                            }

                            Row {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 4

                                Rectangle {
                                    width: 26; height: 26; radius: 6
                                    color: modePrevMa.containsMouse ? "#2a2a2a" : "transparent"
                                    Text { anchors.centerIn: parent; text: "‹"; color: "#cccccc"; font.pixelSize: 16 }
                                    MouseArea {
                                        id: modePrevMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DisplayService.cycleMode(modelData.name, -1)
                                    }
                                }
                                Rectangle {
                                    width: 26; height: 26; radius: 6
                                    color: modeNextMa.containsMouse ? "#2a2a2a" : "transparent"
                                    Text { anchors.centerIn: parent; text: "›"; color: "#cccccc"; font.pixelSize: 16 }
                                    MouseArea {
                                        id: modeNextMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DisplayService.cycleMode(modelData.name, 1)
                                    }
                                }
                            }
                        }

                        // ── Scale cycle ─────────────────────────────────────
                        Item {
                            width: parent.width
                            height: 26

                            Text {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                text: "Scale"
                                color: "#888888"
                                font.pixelSize: 11
                                width: 46
                            }

                            Rectangle {
                                anchors { left: parent.left; right: parent.right
                                          leftMargin: 54; rightMargin: 64 }
                                height: 26
                                radius: 6
                                color: scaleMa.containsMouse ? "#2a2a2a" : "#252525"

                                Text {
                                    anchors.centerIn: parent
                                    text: (modelData.logical && modelData.logical.scale)
                                          ? (modelData.logical.scale + "×") : "--"
                                    color: "#cccccc"
                                    font.pixelSize: 11
                                }

                                MouseArea {
                                    id: scaleMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: DisplayService.cycleScale(modelData.name, 1)
                                }
                            }

                            Row {
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                spacing: 4

                                Rectangle {
                                    width: 26; height: 26; radius: 6
                                    color: scalePrevMa.containsMouse ? "#2a2a2a" : "transparent"
                                    Text { anchors.centerIn: parent; text: "‹"; color: "#cccccc"; font.pixelSize: 16 }
                                    MouseArea {
                                        id: scalePrevMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DisplayService.cycleScale(modelData.name, -1)
                                    }
                                }
                                Rectangle {
                                    width: 26; height: 26; radius: 6
                                    color: scaleNextMa.containsMouse ? "#2a2a2a" : "transparent"
                                    Text { anchors.centerIn: parent; text: "›"; color: "#cccccc"; font.pixelSize: 16 }
                                    MouseArea {
                                        id: scaleNextMa
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: DisplayService.cycleScale(modelData.name, 1)
                                    }
                                }
                            }
                        }

                        // ── Position / order footer ─────────────────────────
                        Text {
                            width: parent.width
                            text: "Position " + (modelData.logical ? modelData.logical.x : 0) + ","
                                  + (modelData.logical ? modelData.logical.y : 0)
                                  + " · logical " + (modelData.logical ? modelData.logical.width : 0)
                                  + "×" + (modelData.logical ? modelData.logical.height : 0)
                            color: "#555555"
                            font.pixelSize: 11
                        }
                    }

                    MouseArea {
                        id: rowMa
                        anchors.fill: parent
                        hoverEnabled: true
                        acceptedButtons: Qt.NoButton
                    }
                }
            }
        }
    }
}
