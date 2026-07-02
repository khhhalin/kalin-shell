import QtQuick
import "../services"

// Shut down / Hibernate / Log out list.
// Emits close() when any action is triggered.
Item {
    id: root

    signal close()

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: BarConfig.powerRowGap

        component ActionRow: Rectangle {
            id: row

            required property string label
            required property string glyph
            required property var    action

            width:  parent.width
            height: BarConfig.powerRowHeight
            radius: BarConfig.powerMenuRowRadius
            color:  mouse.containsMouse ? "#2a2a2a" : "transparent"

            Row {
                anchors.fill:       parent
                anchors.leftMargin: BarConfig.powerMenuRowHPadding
                spacing:            BarConfig.powerMenuRowSpacing

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:           row.glyph
                    color:          "#e6e6e6"
                    font.pixelSize: BarConfig.powerMenuGlyphSize
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text:           row.label
                    color:          "#e6e6e6"
                    font.pixelSize: BarConfig.powerMenuLabelSize
                }
            }

            MouseArea {
                id: mouse
                anchors.fill:  parent
                hoverEnabled:  true
                cursorShape:   Qt.PointingHandCursor
                onClicked: { root.close(); row.action() }
            }
        }

        ActionRow { label: "Shut down"; glyph: "⏻"; action: SystemActions.shutdown  }
        ActionRow { label: "Hibernate";  glyph: "⏾"; action: SystemActions.hibernate }
        ActionRow { label: "Log out";    glyph: "⎋"; action: SystemActions.logout    }
    }
}
