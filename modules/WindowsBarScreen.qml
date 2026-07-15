import QtQuick
import Quickshell
import Quickshell.Wayland

import "./services"
import "./widgets"

// Per-screen shell: wires the bottom bar and right-side panel.
Item {
    id: root

    required property ShellScreen screen

    // ── Layout constants ──────────────────────────────────────────────────────
    property int barHeight:   BarConfig.barHeight
    property int panelWidth:  BarConfig.panelWidth
    property int panelHeight: BarConfig.panelHeight

    // ── Panel open/close state ────────────────────────────────────────────────
    property bool rightPinned:     false
    property bool rightPanelHover: false
    property bool rightGrace:      false

    readonly property bool rightHover: bar.rightHovered
    readonly property bool rightOpen:  rightPinned || rightHover || rightPanelHover || rightGrace || PromptState.visible

    function closeAll(): void {
        rightPinned = false
        rightGrace  = false
        SystemPanelState.rightOwner = ""
    }

    // Grace period: keeps the panel alive while the cursor moves from the
    // bar button into the drawer surface.
    function updateGrace(): void {
        if      (rightPinned)                   { rightGrace = true;  rightCloseTimer.stop()   }
        else if (rightHover || rightPanelHover) { rightGrace = true;  rightCloseTimer.stop()   }
        else                                    {                     rightCloseTimer.restart() }
    }

    onRightHoverChanged:      updateGrace()
    onRightPanelHoverChanged: updateGrace()
    onRightPinnedChanged:     updateGrace()

    Timer { id: rightCloseTimer; interval: 220; repeat: false; onTriggered: rightGrace = false }

    // ── Click-outside catcher ─────────────────────────────────────────────────
    // Transparent fullscreen surface — active when a panel is pinned OR the
    // taskbar context menu is open. Clicks outside the context menu's mask
    // region fall through the Overlay layer and land here.
    property bool contextMenuOpen: false

    PanelWindow {
        screen:  root.screen
        color:   "transparent"
        visible: root.rightPinned || root.contextMenuOpen

        // Click catcher for "outside" clicks.
        // IMPORTANT: exclude the bottom bar area so bar buttons remain clickable
        // while a panel is pinned (clicking another button should swap the pin).
        anchors { top: true; bottom: true; left: true; right: true }
        margins.bottom: root.barHeight
        exclusionMode:               ExclusionMode.Ignore
        exclusiveZone:               0
        WlrLayershell.layer:         WlrLayer.Top
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
        WlrLayershell.namespace:     "windows-bar:click-catcher"

        MouseArea {
            anchors.fill:    parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            onPressed: {
                root.contextMenuOpen = false
                root.closeAll()
            }
        }
    }

    // ── Taskbar context menu ──────────────────────────────────────────────────
    TaskbarContextMenu {
        id: contextMenu
        screen:  root.screen
        visible: root.contextMenuOpen
        onCloseRequested: root.contextMenuOpen = false
    }

    // ── Live window peek (hover thumbnail) ─────────────────────────────────────
    WindowPeek {
        id: peek
        screen: root.screen
        onHoveredChanged: peek.hovered ? peekHideTimer.stop() : peekHideTimer.restart()
    }
    // Grace so moving the cursor from button into the popup (or between buttons)
    // doesn't make it flicker.
    Timer {
        id: peekHideTimer
        interval: 250
        repeat: false
        onTriggered: if (!peek.hovered) peek.show = false
    }

    Connections {
        target: bar
        function onTaskbarContextRequested(appId, x) {
            contextMenu.appId         = appId
            contextMenu.buttonCenterX = x
            root.contextMenuOpen      = true
        }
        function onTaskbarPeekRequested(appId, x) {
            peek.appId         = appId
            peek.buttonCenterX = x
            peek.show          = true
            peekHideTimer.stop()
        }
        function onTaskbarPeekCleared() {
            peekHideTimer.restart()
        }
    }

    // ── Right panel (calendar) ────────────────────────────────────────────────
    // The clock is the only remaining SidePanel user — battery (the last
    // other drawer pane) moved to its own docked battery TUI panel, so the
    // drawer content is unconditionally the calendar now.
    SidePanel {
        screen:      root.screen
        side:        "right"
        barHeight:   root.barHeight
        panelWidth:  root.panelWidth
        panelHeight: root.panelHeight
        open:        root.rightOpen

        onHoverChanged: hovered => root.rightPanelHover = hovered
        content: calendarComponent
    }

    Component { id: calendarComponent; CalendarPanel { anchors.fill: parent } }

    // ── Bottom bar ────────────────────────────────────────────────────────────
    BottomBar {
        id: bar
        screen:           root.screen
        heightHint:       root.barHeight
        rightActive:    root.rightOpen

        onRightClicked: {
            // Exclusive pin behavior: clicking clock pins it, clicking again unpins.
            // If something else is pinned, switch the pin to clock.
            if (root.rightPinned && SystemPanelState.rightOwner === "clock") {
                root.rightPinned = false
                SystemPanelState.rightOwner = ""
            } else {
                root.rightPinned = true
                SystemPanelState.rightOwner = "clock"
            }
        }
        onRequestCloseAll: root.closeAll()
    }

}
