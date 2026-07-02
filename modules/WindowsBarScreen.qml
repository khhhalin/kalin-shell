import QtQuick
import Quickshell
import Quickshell.Wayland

import "./services"

// Per-screen shell: wires the bottom bar, left/right side panels, and IPC.
// All UI content lives in dedicated components (StartDrawer, BottomBar, SidePanel).
Item {
    id: root

    required property ShellScreen screen

    // ── Layout constants ──────────────────────────────────────────────────────
    property int barHeight:   BarConfig.barHeight
    property int panelWidth:  BarConfig.panelWidth
    property int panelHeight: BarConfig.panelHeight

    // Edit mode (resize + font scale)
    property bool editMode: false
    property bool _prevLeftPinned: false
    property bool _prevRightPinned: false

    // ── Panel open/close state ────────────────────────────────────────────────
    property bool leftPinned:      false
    property bool rightPinned:     false
    property bool leftPanelHover:  false
    property bool rightPanelHover: false
    property bool leftGrace:       false
    property bool rightGrace:      false

    readonly property bool leftHover:  bar.leftHovered
    readonly property bool rightHover: bar.rightHovered
    readonly property bool leftOpen:   leftPinned  || leftHover  || leftPanelHover  || leftGrace
    // Keep the right panel open while a password dialog spawned from it is visible.
    readonly property bool rightOpen:  rightPinned || rightHover || rightPanelHover || rightGrace || PromptState.visible

    function closeAll(): void {
        leftPinned  = false; rightPinned  = false
        leftGrace   = false; rightGrace   = false
        SystemPanelState.rightOwner = ""
    }

    function setEditMode(enabled): void {
        if (root.editMode === enabled) return
        if (enabled) {
            root._prevLeftPinned = root.leftPinned
            root._prevRightPinned = root.rightPinned
            root.leftPinned = true
            root.rightPinned = true
        } else {
            root.leftPinned = root._prevLeftPinned
            root.rightPinned = root._prevRightPinned
        }
        root.editMode = enabled
    }

    function toggleEditMode(): void {
        setEditMode(!root.editMode)
    }

    function adjustFontScale(delta): void {
        const step = 0.1
        const minScale = 0.8
        const maxScale = 1.6
        const next = Math.max(minScale, Math.min(maxScale, BarConfig.panelFontScale + step * delta))
        BarConfig.panelFontScale = Math.round(next * 10) / 10
    }

    function updatePanelWidth(nextWidth): void {
        const minW = 320
        const maxW = Math.max(minW, root.screen.width - 80)
        BarConfig.panelWidth = Math.max(minW, Math.min(maxW, nextWidth))
    }

    function updatePanelHeight(nextHeight): void {
        const minH = 260
        const maxH = Math.max(minH, root.screen.height - root.barHeight - 20)
        BarConfig.panelHeight = Math.max(minH, Math.min(maxH, nextHeight))
    }

    // Grace period: keeps the panel alive while the cursor moves from the
    // bar button into the drawer surface.
    function updateGrace(): void {
        if      (leftPinned)                  { leftGrace = false; leftCloseTimer.stop()    }
        else if (leftHover || leftPanelHover) { leftGrace = true;  leftCloseTimer.stop()    }
        else                                  {                    leftCloseTimer.restart()  }

        if      (rightPinned)                   { rightGrace = false; rightCloseTimer.stop()   }
        else if (rightHover || rightPanelHover) { rightGrace = true;  rightCloseTimer.stop()   }
        else                                    {                     rightCloseTimer.restart() }
    }

    onLeftHoverChanged:       updateGrace()
    onRightHoverChanged:      updateGrace()
    onLeftPanelHoverChanged:  updateGrace()
    onRightPanelHoverChanged: updateGrace()
    onLeftPinnedChanged:      updateGrace()
    onRightPinnedChanged:     updateGrace()

    Timer { id: leftCloseTimer;  interval: 220; repeat: false; onTriggered: leftGrace  = false }
    Timer { id: rightCloseTimer; interval: 220; repeat: false; onTriggered: rightGrace = false }

    // ── IPC: kanata Win-tap → toggle left panel ───────────────────────────────
    Connections {
        target: MenuState
        function onToggleMenu(): void {
            root.leftPinned = !root.leftPinned
            if (root.leftPinned) root.rightPinned = false
        }
    }

    // ── Click-outside catcher ─────────────────────────────────────────────────
    // Transparent fullscreen surface — active when a panel is pinned OR the
    // taskbar context menu is open. Clicks outside the context menu's mask
    // region fall through the Overlay layer and land here.
    property bool contextMenuOpen: false

    PanelWindow {
        screen:  root.screen
        color:   "transparent"
        visible: root.leftPinned || root.rightPinned || root.contextMenuOpen

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
                root.leftPinned  = false
            }
        }
        function onStatusHoveredTabChanged() {
            if (bar.statusHoveredTab !== "") {
                SystemPanelState.currentTab = bar.statusHoveredTab
                root._lastStatusTab = bar.statusHoveredTab
            }
        }
    }

    // ── Left panel (start drawer) ─────────────────────────────────────────────
    SidePanel {
        screen:      root.screen
        side:        "left"
        barHeight:   root.barHeight
        panelWidth:  root.panelWidth
        panelHeight: root.panelHeight
        open:        root.leftOpen
        editMode:    root.editMode

        onResizeWidthRequested:  w => root.updatePanelWidth(w)
        onResizeHeightRequested: h => root.updatePanelHeight(h)

        onHoverChanged: hovered => root.leftPanelHover = hovered

        content: StartDrawer {
            id: startDrawer
            anchors.fill: parent
            railWidth:    root.barHeight
            panelOpen:    root.leftOpen
            query:        bar.searchText
            editMode:     root.editMode
            fontScale:    BarConfig.panelFontScale
            onLaunched:   root.closeAll()
            onEditModeToggleRequested: root.toggleEditMode()
            onFontScaleDeltaRequested: delta => root.adjustFontScale(delta)

            // bar and startDrawer are both in scope here:
            // bar via the component's creation context (WindowsBarScreen document),
            // startDrawer as the root id of this component instance.
            Connections {
                target: bar
                function onSearchSubmitted() { startDrawer.submitSearch() }
                function onSearchUp()        { startDrawer.searchUp()     }
                function onSearchDown()      { startDrawer.searchDown()   }
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

    SidePanel {
        screen:      root.screen
        side:        "right"
        barHeight:   root.barHeight
        panelWidth:  root.panelWidth
        panelHeight: root.panelHeight
        open:        root.rightOpen
        editMode:    root.editMode

        onResizeWidthRequested:  w => root.updatePanelWidth(w)
        onResizeHeightRequested: h => root.updatePanelHeight(h)

        onHoverChanged: hovered => root.rightPanelHover = hovered
        content: root.effectiveOwner === "clock"
                 ? calendarComponent
                 : root.effectiveOwner === "volume"
                 ? mixerComponent
                 : systemComponent
    }

    Component { id: systemComponent;   SystemPanel   { anchors.fill: parent } }
    Component { id: calendarComponent; CalendarPanel { anchors.fill: parent } }
    Component { id: mixerComponent;    MixerPanel    { anchors.fill: parent } }

    // ── Bottom bar ────────────────────────────────────────────────────────────
    BottomBar {
        id: bar
        screen:           root.screen
        heightHint:       root.barHeight
        searchBoxWidth:   BarConfig.searchBoxWidth
        panelHoverWidth:  root.panelWidth
        leftActive:       root.leftOpen
        rightActive:    root.rightOpen
        leftPinned:     root.leftPinned

        onLeftClicked: {
            root.leftPinned = !root.leftPinned
            if (root.leftPinned) root.rightPinned = false
        }
        onRightClicked: {
            // Exclusive pin behavior: clicking clock pins it, clicking again unpins.
            // If something else is pinned, switch the pin to clock.
            if (root.rightPinned && SystemPanelState.rightOwner === "clock") {
                root.rightPinned = false
                SystemPanelState.rightOwner = ""
            } else {
                root.rightPinned = true
                root.leftPinned = false
                SystemPanelState.rightOwner = "clock"
            }
        }
        onRequestCloseAll: root.closeAll()
    }
}

