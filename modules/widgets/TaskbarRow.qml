import QtQuick
import "../services"

// Horizontal row of Win10-style taskbar buttons driven by TaskbarService.
// Place this in BottomBar between the search box and the workspace indicator.
Row {
    id: root
    spacing: BarConfig.taskbarButtonSpacing

    // Emitted on right-click; buttonCenterX is the screen-space X centre of the clicked button.
    signal contextRequested(string appId, int buttonCenterX)
    // Emitted on hover for the live window-peek popup.
    signal peekRequested(string appId, int buttonCenterX)
    signal peekCleared()

    Repeater {
        model: TaskbarService.items

        TaskbarButton {
            id: btn
            required property var modelData

            appId:       modelData.appId
            appName:     modelData.entry ? modelData.entry.name : modelData.appId
            iconName:    modelData.entry ? modelData.entry.icon : ""
            windowCount: modelData.windowCount
            isFocused:   modelData.isFocused
            isPinned:    modelData.isPinned
            isRunning:   modelData.isRunning

            onLeftClicked:   TaskbarService.focusOrLaunch(modelData.appId)
            onRightClicked: {
                // Map button centre to screen coordinates so the context menu
                // can position itself directly above the button.
                const pt = btn.mapToGlobal(btn.width / 2, 0)
                root.contextRequested(modelData.appId, Math.round(pt.x))
            }
            onMiddleClicked: TaskbarService.closeAll(modelData.appId)

            onPeekRequested: sx => root.peekRequested(modelData.appId, Math.round(sx))
            onPeekCleared:   root.peekCleared()
        }
    }
}
