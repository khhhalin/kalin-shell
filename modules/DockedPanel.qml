import QtQuick
import Quickshell
import Quickshell.Io
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// DockedPanel — reusable state/lifecycle for a bar panel backed by a real,
// compositor-docked terminal (kalin-wm only; see obsidian/ipc-socket.md's
// dock/undock/minimize commands) instead of QML-rendered content.
//
// Mirrors the existing QML SidePanel drawer's open/close shape as closely as
// a real window allows: hover the trigger (bar button) to open, move the
// cursor away and it closes after a short grace period (bridging the gap
// while the cursor crosses from the button to the panel), click to pin it
// open. The one thing a QML drawer gets for free that this doesn't — hover
// state *inside* the content — comes from the compositor's own dock_hover
// IPC mirror (KalinViewport.dockHoverAppId), since the panel's content is a
// real Wayland toplevel the compositor positions, not a QML Item this shell
// can attach a HoverHandler to directly.
//
// One instance per panel (clipboard, stats, volume, wifi, bluetooth,
// display, ...). The backing process is spawned once per shell session on
// first open and never killed — later opens just re-dock/un-minimize the
// same already-running client, so reopening is instant with whatever state
// it was left in (a live fzf/btop/nmtui/... session), never a respawn.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    required property string appId
    required property var command   // argv for Process, e.g. ["foot", "--app-id=...", "-e", "cmd"]
    required property ShellScreen screen
    required property int barHeight
    property int panelWidth: BarConfig.tuiPanelWidth
    property int panelHeight: BarConfig.tuiPanelHeight

    // Bar button binds this to its own `hovered`.
    property bool buttonHover: false
    property bool pinned: false

    readonly property bool panelHover: KalinViewport.dockHoverAppId === root.appId
    readonly property bool cursorNear: root.buttonHover || root.panelHover
    property bool grace: false
    readonly property bool open: root.pinned || root.cursorNear || root.grace

    property bool spawned: false

    // Bottom-right, flush with the bar — same placement as the QML
    // SidePanel drawer for visual consistency across panels.
    readonly property int panelX: root.screen.x + root.screen.width  - root.panelWidth
    readonly property int panelY: root.screen.y + root.screen.height - root.barHeight - root.panelHeight

    // Toggle the pin (bar button's onClicked) — matches the clock button's
    // click-to-pin/click-to-unpin behavior.
    function togglePin(): void {
        root.pinned = !root.pinned
    }

    onCursorNearChanged: {
        if (root.cursorNear) {
            closeGrace.stop()
            root.grace = false
        } else {
            closeGrace.restart()
        }
    }

    Timer {
        id: closeGrace
        interval: 220
        repeat: false
        onTriggered: root.grace = false
    }

    onOpenChanged: root.open ? root._open() : root._close()

    // Every DockedPanel shares the same on-screen rect — only one may be
    // open at a time, or they'd visually overlap. See
    // DockedPanelCoordinator.qml.
    Connections {
        target: DockedPanelCoordinator
        function onCloseRequested(appId) {
            if (appId === root.appId) {
                root.pinned = false
                root.grace = false
                root.buttonHover = false
            }
        }
    }

    Process { id: proc }

    // First spawn needs a beat before kalin-wm's client list actually has
    // the new surface — dock/minimize address by app_id and silently no-op
    // if the client isn't mapped yet, so an immediate dock right after
    // `running = true` would be a race. Only the very first open pays this
    // cost; every later toggle re-docks the same already-running client.
    Timer {
        id: firstSpawnDelay
        interval: 500
        repeat: false
        onTriggered: root._show()
    }

    function _show(): void {
        KalinViewport.minimize(root.appId, false)
        KalinViewport.dock(root.appId, root.panelX, root.panelY, root.panelWidth, root.panelHeight)
    }

    function _open(): void {
        DockedPanelCoordinator.claim(root.screen.name, root.appId)
        if (!root.spawned) {
            root.spawned = true
            // Arm the dock rect *before* spawning, so the client is docked
            // from its very first frame — never visible anywhere else (no
            // flash at a default floating position, no camera jump chasing
            // it there). firstSpawnDelay's own dock()/minimize() call below
            // is a no-op once this has already taken effect; kept as a
            // fallback in case dockPrep ever misses (e.g. a future app_id
            // mismatch) rather than relying on it exclusively.
            KalinViewport.dockPrep(root.appId, root.panelX, root.panelY, root.panelWidth, root.panelHeight)
            proc.command = root.command
            proc.running = true
            firstSpawnDelay.restart()
        } else {
            root._show()
        }
    }

    function _close(): void {
        DockedPanelCoordinator.release(root.screen.name, root.appId)
        KalinViewport.undock(root.appId)
        KalinViewport.minimize(root.appId, true)
    }
}
