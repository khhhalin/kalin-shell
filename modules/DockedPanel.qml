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

    Process {
        id: proc
        // If the TUI quits or crashes (all the kalin_tuis panels bind `q`),
        // forget the spawn — otherwise `spawned` stays true, _show() re-docks
        // a dead app_id forever, and the bar button is dead until the shell
        // restarts. Also drop the pin so a pinned-but-gone panel doesn't
        // linger "open"; the undock/minimize in _close() no-op harmlessly on
        // the vanished app_id.
        onExited: function(exitCode, exitStatus) {
            root.spawned = false
            root.pinned = false
            root.grace = false
        }
    }

    // First spawn needs a beat before kalin-wm's client list actually has
    // the new surface — dock/minimize address by app_id and silently no-op
    // if the client isn't mapped yet, so an immediate dock right after
    // `running = true` would be a race. Only the very first open pays this
    // cost; every later toggle re-docks the same already-running client.
    Timer {
        id: firstSpawnDelay
        interval: 500
        repeat: false
        // Guard on open: if the cursor already left during the spawn beat,
        // showing now would pop the panel open with nobody hovering it.
        onTriggered: if (root.open) root._show()
    }

    // Cold-start race: the first spawn can take seconds to map (python TUI,
    // cold caches — routine in the test VM). If the panel logically closed
    // before the client mapped, _close()'s undock/minimize no-op'd against
    // the not-yet-existing app_id, and the client then maps *visible* via
    // the armed dockPrep rect with nothing left to hide it. Re-assert the
    // closed state once a second for a while after the first spawn.
    Timer {
        id: lateSpawnSettle
        interval: 1000
        repeat: true
        property int remaining: 0
        onTriggered: {
            if (remaining-- <= 0) {
                stop()
                return
            }
            if (!root.open) {
                KalinViewport.undock(root.appId)
                KalinViewport.minimize(root.appId, true)
            }
        }
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
            // 60s: a cold TUI spawn in the test VM has been observed to take
            // over a minute to map; on the host it's sub-second and the
            // spare ticks are idempotent no-ops.
            lateSpawnSettle.remaining = 60
            lateSpawnSettle.restart()
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
