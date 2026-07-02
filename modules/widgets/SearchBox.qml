import QtQuick
import QtQuick.Controls
import "../services"

Item {
    id: root

    property string placeholderText: "Type here to search"
    property alias text: input.text

    function focusForTyping(): void {
        input.forceActiveFocus()
        input.selectAll()
    }

    function clearAndUnfocus(): void {
        input.text = ""
        input.focus = false
    }

    signal submitted(string text)
    signal moveUp()
    signal moveDown()

    implicitHeight: BarConfig.searchBoxHeight
    implicitWidth:  BarConfig.searchBoxWidth

    Rectangle {
        anchors.fill: parent
        radius: BarConfig.buttonRadius
        color: "#2a2a2a"

        // Make the whole box focus the input (not just the glyph/text area).
        // Don't consume the click so TextInput can still handle selection.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            propagateComposedEvents: true
            onPressed: function(mouse) {
                input.forceActiveFocus()
                mouse.accepted = false
            }
        }

        Row {
            anchors.fill: parent
            anchors.margins: BarConfig.searchBoxPadding
            spacing: BarConfig.searchBoxSpacing

            Text {
                text: "⌕"
                color: "#bdbdbd"
                font.pixelSize: BarConfig.searchBoxIconSize
                anchors.verticalCenter: parent.verticalCenter
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - 30
                height: parent.height
                color: "#e6e6e6"
                font.pixelSize: BarConfig.searchBoxFontSize
                clip: true
                selectByMouse: true

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.placeholderText
                    color: "#8e8e8e"
                    font.pixelSize: BarConfig.searchBoxFontSize
                    visible: input.text.length === 0 && !input.activeFocus
                }

                Keys.onReturnPressed: root.submitted(input.text)
                Keys.onEnterPressed: root.submitted(input.text)
                Keys.onUpPressed: root.moveUp()
                Keys.onDownPressed: root.moveDown()
                Keys.onTabPressed: event => {
                    root.moveDown()
                    event.accepted = true
                }
                Keys.onBacktabPressed: event => {
                    root.moveUp()
                    event.accepted = true
                }
            }
        }
    }
}