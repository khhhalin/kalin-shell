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

    property bool hovered: false

    // Width grows on hover to reveal the app name; minimum width stays square.
    implicitWidth:  Math.max(contentRow.implicitWidth + 14, BarConfig.barHeight)
    implicitHeight: BarConfig.barHeight

    Behavior on implicitWidth { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }

    // ── Background ─────────────────────────────────────────────────────────────
    // TUI-box treatment: amber frame marks the focused app (idle icons stay
    // frameless so the taskbar row doesn't read as a wall of boxes).
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius: BarConfig.buttonRadius
        color:  root.isFocused   ? Theme.surfaceAlt
              : root.hovered    ? Theme.surfaceAlt
              : "transparent"
        border.width: (root.isFocused || root.hovered) ? 1 : 0
        border.color: root.isFocused ? Theme.accent : Theme.borderSubtle
    }

    // ── Icon + name row (centered, name hidden when not hovered) ───────────────
    readonly property int _iconOffset: root.isRunning ? -3 : 0

    Row {
        id: contentRow
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        anchors.leftMargin: (BarConfig.barHeight - BarConfig.taskbarIconSize) / 2
        anchors.verticalCenterOffset: root._iconOffset
        spacing: 6

        Item {
            width: BarConfig.taskbarIconSize
            height: BarConfig.taskbarIconSize

            Image {
                id: icon
                anchors.fill: parent
                source: root.iconName.length > 0 ? ("image://icon/" + root.iconName) : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                mipmap: true
                visible: status === Image.Ready && root.iconName.length > 0
            }

            // Letter badge – shown when the icon fails to load or no icon name is set
            Rectangle {
                visible: !icon.visible
                anchors.fill: parent
                radius: BarConfig.taskbarIconSize * 0.27
                color:  Theme.accentBlue

                Text {
                    anchors.centerIn: parent
                    text:           root.appName.length > 0 ? root.appName[0].toUpperCase() : "?"
                    color:          Theme.text
                    font.pixelSize: BarConfig.taskbarFallbackFontSize
                    font.bold:      true
                }
            }
        }

        Text {
            id: nameText
            anchors.verticalCenter: parent.verticalCenter
            text: root.appName
            color: Theme.text
            font.pixelSize: BarConfig.clockFontSize
            width: root.hovered ? implicitWidth : 0
            opacity: root.hovered ? 1 : 0
            clip: true

            Behavior on width  { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
            Behavior on opacity { NumberAnimation { duration: 90 } }
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
                color:  root.isFocused ? Theme.accent : Theme.textMuted
            }
        }
    }

    // ── Interaction ───────────────────────────────────────────────────────────
    HoverHandler {
        id: hover
        onHoveredChanged: {
            root.hovered = hover.hovered
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
