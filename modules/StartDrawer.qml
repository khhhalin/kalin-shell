import QtQuick
import "./widgets"
import "./services"

// Left panel content: icon rail + app launcher / power menu swap.
FocusScope {
    id: root

    // Should match barHeight from the parent screen.
    property int railWidth: BarConfig.barHeight

    // Search query — bound directly as bar.searchText from WindowsBarScreen.
    property string query: ""

    // Emitted after an app launches; parent should close the panel.
    signal launched()

    // Drawer mode: "launcher" | "power" | "tmux"
    property string drawerMode: "launcher"

    // Edit mode (resize + font scale)
    property bool editMode: false
    property real fontScale: 1.0

    signal editModeToggleRequested()
    signal fontScaleDeltaRequested(int delta)

    focus: true

    Keys.onPressed: event => {
        if (!root.editMode) return
        if (event.key === Qt.Key_Plus || event.key === Qt.Key_Equal || event.text === "+") {
            root.fontScaleDeltaRequested(1)
            event.accepted = true
            return
        }
        if (event.key === Qt.Key_Minus || event.text === "-") {
            root.fontScaleDeltaRequested(-1)
            event.accepted = true
            return
        }
    }

    onEditModeChanged: {
        if (editMode) {
            root.drawerMode = "tmux"
            tmuxPanel.forceActiveFocus()
        }
    }

    // Bound to leftOpen — resets to launcher every time the panel opens.
    property bool panelOpen: false
    onPanelOpenChanged: if (panelOpen) drawerMode = "launcher"

    // Reset power menu when mouse leaves the whole drawer.
    HoverHandler {
        onHoveredChanged: if (!hovered) root.drawerMode = "launcher"
    }

    // ── Icon rail ─────────────────────────────────────────────────────────────
    Rectangle {
        id: rail
        width: root.railWidth
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; leftMargin: BarConfig.edgePadding }
        color: "transparent"

        // Top: hamburger — always returns to the launcher
        Column {
            anchors { left: parent.left; right: parent.right; top: parent.top; topMargin: 0 }

            RailIconButton {
                width:        rail.width
                height:       rail.width
                iconSize:     BarConfig.railIconSize
                iconSource:   Qt.resolvedUrl("../assets/icons/menu.svg")
                fallbackKind: "menu"
                active:       root.drawerMode === "launcher"
                onClicked:    root.drawerMode = "launcher"
            }
        }

        // Bottom: power — hover opens, click toggles
        Column {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; bottomMargin: 0 }

            // Edit mode — toggle resize/font controls
            RailIconButton {
                width:          rail.width
                height:         rail.width
                iconSize:       BarConfig.railIconSize
                glyph:          "E"
                tooltip:        "Edit mode"
                active:         root.editMode
                onClicked:      root.editModeToggleRequested()
            }

            // Above power: tmux apps — hover opens, click toggles
            RailIconButton {
                width:          rail.width
                height:         rail.width
                iconSize:       BarConfig.railIconSize
                glyph:          "TM"
                tooltip:        "Tmux apps"
                active:         root.drawerMode === "tmux"
                onHoverEntered: root.drawerMode = "tmux"
                onClicked:      root.drawerMode = (root.drawerMode === "tmux") ? "launcher" : "tmux"
            }

            RailIconButton {
                width:          rail.width
                height:         rail.width
                iconSize:       BarConfig.railIconSize
                iconSource:     Qt.resolvedUrl("../assets/icons/power.svg")
                fallbackKind:   "power"
                active:         root.drawerMode === "power"
                onHoverEntered: root.drawerMode = "power"
                onClicked:      root.drawerMode = (root.drawerMode === "power") ? "launcher" : "power"
            }
        }
    }

    // ── Content area ──────────────────────────────────────────────────────────
    Item {
        anchors {
            left: rail.right; right: parent.right
            top: parent.top;  bottom: parent.bottom
            margins: BarConfig.contentPadding
        }

        LauncherView {
            id: launcher
            anchors.fill: parent
            visible:      root.drawerMode === "launcher"
            query:        root.query
            onLaunched:   { root.drawerMode = "launcher"; root.launched() }
        }

        PowerMenu {
            anchors.fill: parent
            visible:      root.drawerMode === "power"
            onClose:      root.drawerMode = "launcher"
        }

        TmuxAppsPanel {
            id: tmuxPanel
            anchors.fill: parent
            visible:      root.drawerMode === "tmux"
            active:       visible
            editMode:     root.editMode
            fontScale:    root.fontScale
            onToggleEditRequested: root.editModeToggleRequested()
            onFontScaleDelta:      root.fontScaleDeltaRequested(delta)
            onVisibleChanged: if (visible) forceActiveFocus()
        }
    }

    // ── Search bar forwarding (called from WindowsBarScreen) ──────────────────
    function submitSearch(): void { launcher.activateSelected(); root.launched() }
    function searchUp():     void { launcher.moveSelection(-1) }
    function searchDown():   void { launcher.moveSelection(+1) }
}
