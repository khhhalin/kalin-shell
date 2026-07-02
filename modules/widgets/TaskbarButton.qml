import QtQuick
import "../services"

// Win10-style taskbar button.
//
// Visual layers (bottom to top):
//   1. Hover/active background rectangle
//   2. App icon (image://icon/NAME) with letter-badge fallback
//   3. Running indicator – small bar/dots below the icon
//
// Interaction:
//   Left-click  → focus/launch (handled by TaskbarService)
//   Right-click → toggle pin
//   Middle-click → close all windows of this app
Item {
    id: root

    required property string appId
    property string  appName:     ""
    property string  iconName:    ""
    property int     windowCount: 0
    property bool    isFocused:   false
    property bool    isPinned:    false
    property bool    isRunning:   false

    signal leftClicked()
    signal rightClicked()
    signal middleClicked()
    // WindowPeek: fired on hover enter/leave with the button's screen-space
    // center X so a thumbnail popup can be anchored above it.
    signal peekRequested(int screenX)
    signal peekCleared()

    // Square button, same height as the bar so it fills it completely
    implicitWidth:  BarConfig.barHeight
    implicitHeight: BarConfig.barHeight

    // ── Background ─────────────────────────────────────────────────────────────
    Rectangle {
        anchors.fill: parent
        radius: BarConfig.buttonRadius
        color:  root.isFocused   ? Theme.surfaceActive
              : hover.hovered    ? Theme.surfaceAlt
              : "transparent"
        border.width: root.isFocused ? 1 : 0
        border.color: Theme.border
    }

    // ── Icon (shift up slightly when indicator is visible) ─────────────────────
    readonly property int _iconOffset: root.isRunning ? -3 : 0

    Image {
        id: icon
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root._iconOffset
        width:  BarConfig.taskbarIconSize
        height: BarConfig.taskbarIconSize
        source: root.iconName.length > 0 ? ("image://icon/" + root.iconName) : ""
        fillMode: Image.PreserveAspectFit
        smooth: true
        mipmap: true
        visible: status === Image.Ready && root.iconName.length > 0
    }

    // Letter badge – shown when the icon fails to load or no icon name is set
    Rectangle {
        visible: !icon.visible
        anchors.centerIn: parent
        anchors.verticalCenterOffset: root._iconOffset
        width:  BarConfig.taskbarIconSize
        height: BarConfig.taskbarIconSize
        radius: BarConfig.taskbarIconSize * 0.27
        color:  "#2f4a7a"

        Text {
            anchors.centerIn: parent
            text:           root.appName.length > 0 ? root.appName[0].toUpperCase() : "?"
            color:          Theme.text
            font.pixelSize: BarConfig.taskbarFallbackFontSize
            font.bold:      true
        }
    }

    // ── Running indicator ─────────────────────────────────────────────────────
    // Win10 style:
    //   • Not running (pinned only) → nothing
    //   • 1 window, not focused    → single dim dot centred below icon
    //   • 1 window, focused        → wider bright bar centred below icon
    //   • N windows                → N small dots (max 3), focused = bright
    Row {
        visible: root.isRunning
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: BarConfig.taskbarIndicatorBM
        spacing: 2

        Repeater {
            model: Math.min(root.windowCount, 3)
            Rectangle {
                // Single window → wider bar; multiple → compact dots
                width:  root.windowCount > 1
                        ? BarConfig.taskbarIndicatorDotW
                        : BarConfig.taskbarIndicatorFocusW
                height: BarConfig.taskbarIndicatorH
                radius: height / 2
                color:  root.isFocused ? "#ffffff" : "#606060"
            }
        }
    }

    // ── Interaction ───────────────────────────────────────────────────────────
    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hover.hovered) {
                const pt = root.mapToGlobal(root.width / 2, 0)
                root.peekRequested(pt.x)
            } else {
                root.peekCleared()
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        cursorShape: Qt.PointingHandCursor

        onClicked: mouse => {
            if      (mouse.button === Qt.RightButton)  root.rightClicked()
            else if (mouse.button === Qt.MiddleButton) root.middleClicked()
            else                                       root.leftClicked()
        }
    }
}
