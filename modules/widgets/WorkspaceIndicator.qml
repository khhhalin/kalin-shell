import QtQuick
import QtQuick.Layouts

import "../services"

Item {
    id: root

    visible: !KalinViewport.enabled
    implicitWidth: visible ? row.implicitWidth : 0
    implicitHeight: visible ? BarConfig.workspaceWidgetHeight : 0

    // TUI-box treatment (pre-rice grays replaced with Theme tokens).
    Rectangle {
        anchors.fill: row
        anchors.margins: -BarConfig.workspaceContainerPadding
        radius: BarConfig.buttonRadius
        color: Theme.surfaceAlt
        border.width: 1
        border.color: Theme.borderSubtle
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
                color: modelData.isActive ? Theme.accent : Theme.textMuted

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
