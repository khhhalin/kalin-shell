import QtQuick
import QtQuick.Layouts

import "../services"

Item {
    id: root

    visible: !KalinViewport.enabled
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: visible ? BarConfig.workspaceWidgetHeight : 0

    Rectangle {
        anchors.fill: row
        anchors.margins: -BarConfig.workspaceContainerPadding
        radius: BarConfig.workspaceContainerRadius
        color: "#252525"
        border.width: 1
        border.color: "#323232"
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: BarConfig.workspaceDotSpacing

        Repeater {
            model: NiriIpc.workspaces

            Rectangle {
                width:  BarConfig.workspaceDotSize
                height: BarConfig.workspaceDotSize
                radius: BarConfig.workspaceDotRadius
                color: modelData.isActive ? "#e6e6e6" : "#6d6d6d"

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // niri action expects workspace reference: index or name
                        NiriIpc.focusWorkspace(modelData.name ?? modelData.idx)
                    }
                }
            }
        }
    }
}
