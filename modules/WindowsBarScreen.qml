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
        function onSystemTabRequested(tab) {
            // IMPORTANT: `currentTab` can change just from hover (preview).
            // Pin/unpin decisions must be based on the pinned owner.
            if (root.rightPinned && SystemPanelState.rightOwner === tab) {
                root.rightPinned = false
                SystemPanelState.rightOwner = ""
            } else {
                SystemPanelState.currentTab = tab
                SystemPanelState.rightOwner = tab
                root.rightPinned = true
            }
        }
        function onStatusHoveredTabChanged() {
            if (bar.statusHoveredTab !== "") {
                SystemPanelState.currentTab = bar.statusHoveredTab
                root._lastStatusTab = bar.statusHoveredTab
            }
        }
    }

    // ── Right panel (system panel or calendar) ────────────────────────────────
    // Latch the last hovered status-widget tab while the cursor is anywhere in
    // the right zone (buttons + panel + 220 ms grace).  This prevents a brief
    // flash to the wrong component while the cursor crosses the gap between the
    // bar button and the panel surface — the grace timer keeps rightOpen alive
    // but statusHoveredTab is already empty at that point.
    property string _lastStatusTab: ""

    readonly property bool cursorInRightZone: rightHover || rightPanelHover || rightGrace
    onCursorInRightZoneChanged: if (!cursorInRightZone) _lastStatusTab = ""

    // Priority: 1) widget is actively hovered  2) latch (cursor in zone)
    //           3) pinned owner
    readonly property string effectiveOwner:
        bar.statusHoveredTab !== "" ? bar.statusHoveredTab
        : cursorInRightZone && _lastStatusTab !== "" ? _lastStatusTab
        : SystemPanelState.rightOwner

    readonly property int effectivePanelHeight: root.panelHeight

    SidePanel {
        screen:      root.screen
        side:        "right"
        barHeight:   root.barHeight
        panelWidth:  root.panelWidth
        panelHeight: root.effectivePanelHeight
        open:        root.rightOpen

        onHoverChanged: hovered => root.rightPanelHover = hovered
        // Only "clock" and "battery" ever reach here now — stats/volume/
        // wifi/bluetooth/display all moved to their own docked TUI panels
        // (see BottomBar.qml's DockedPanel instances), so effectiveOwner
        // can never actually hold those values any more.
        content: root.effectiveOwner === "clock" ? calendarComponent : systemComponent
    }

    Component { id: systemComponent;   SystemPanel   { anchors.fill: parent } }
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
