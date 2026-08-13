pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ─────────────────────────────────────────────────────────────────────────────
// KalinViewport — connects to the kalin-wm compositor IPC socket
// ($KALIN_IPC_SOCKET) and exposes the infinite-canvas camera state plus a
// command channel. On niri (or any compositor that doesn't export the env var)
// this stays disconnected and `available` is false, so it's inert.
//
// Wire protocol (newline-delimited), matched to code/src/modules/ipc.c:
//   server -> client: {"type":"state","viewport":{x,y,zoom,follow,follow_new},
//                      "crop":bool,"super_held":bool,"exit_pending":bool,
//                      "focused":{appid,title,fullscreen,ontop,overlap,yellow}}
//   client -> server: pan <dx> <dy> | zoom <factor> | zoom-reset | follow-toggle
//                      | ontop-toggle
// "overlap" (the focused window's `toggle-overlap` flag, `Super+Shift+o`) is
// read-only here — mirrored for the hold-Super menu's on/off indicator, same
// as "ontop"/"fullscreen"; there's no shell-side command for it since the
// menu is a key-hint overlay, not clickable (see WindowActions.qml). The flag
// is dormant since the connection graph was removed; a rail-based grow-push
// re-homes it (kalin-wm layout Phase 3).
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    readonly property string socketPath: Quickshell.env("KALIN_IPC_SOCKET") || ""
    readonly property bool enabled: socketPath.length > 0

    property bool available: false

    // Camera / compositor state (defaults until the first state line arrives).
    property real x: 0
    property real y: 0
    property real zoom: 1.0
    property bool follow: false
    property bool followNew: false
    property bool cropActive: false

    // Transient input state for shell overlays.
    property bool superHeld: false      // Super key currently held down
    property bool menuShown: false      // compositor's hold-Super window menu is up
    property bool exitPending: false    // quit() armed; waiting for 2nd Esc
    property bool overviewActive: false // native overview mode (Super+O) is open

    // Focused window mirrored from the compositor (foreign-toplevel is the
    // authoritative window list; this is a convenience for OSD/labels).
    property string focusedAppId: ""
    property string focusedTitle: ""
    property bool focusedFullscreen: false
    property bool focusedOverlap: false
    // Papyrus knob (0..1) of the focused window — drives the paper-mode shader
    // strength+warmth; mirrored here for the WindowActions papyrus gauge.
    property real focusedYellow: 0
    // Focused window's on-screen rect (px), for flowing overlays out of it.
    property rect focusedRect: Qt.rect(0, 0, 0, 0)

    // app_id of whichever docked client (see dock()/undock() below) the
    // cursor is currently over, or "" if none. A docked client is a real
    // Wayland toplevel positioned by the compositor, not QML content, so
    // this is the only way a panel can know the cursor is over it — used to
    // auto-hide a docked panel on cursor-leave the same way the QML
    // SidePanel drawer does via its own HoverHandler. See DockedPanel.qml.
    property string dockHoverAppId: ""

    signal stateChanged()

    Socket {
        id: sock
        path: root.socketPath
        connected: root.enabled

        parser: SplitParser {
            // SplitParser emits one message per newline-delimited record.
            onRead: line => root._handleLine(line)
        }

        onConnectionStateChanged: {
            root.available = sock.connected
            if (!sock.connected)
                root._scheduleReconnect()
        }
    }

    // Best-effort reconnect: the compositor may start after the shell.
    Timer {
        id: reconnectTimer
        interval: 1500
        repeat: false
        onTriggered: if (root.enabled && !sock.connected) sock.connected = true
    }

    function _scheduleReconnect(): void {
        if (root.enabled) reconnectTimer.restart()
    }

    function _handleLine(line): void {
        if (!line || !line.length) return
        try {
            const msg = JSON.parse(line)
            if (msg.type !== "state") return
            if (msg.viewport) {
                root.x = msg.viewport.x
                root.y = msg.viewport.y
                root.zoom = msg.viewport.zoom
                root.follow = !!msg.viewport.follow
                root.followNew = !!msg.viewport.follow_new
            }
            root.cropActive = !!msg.crop
            root.superHeld = !!msg.super_held
            root.overviewActive = !!msg.overview
            root.menuShown = !!msg.menu
            root.exitPending = !!msg.exit_pending
            if (msg.rect)
                root.focusedRect = Qt.rect(msg.rect.x, msg.rect.y, msg.rect.w, msg.rect.h)
            if (msg.focused) {
                root.focusedAppId = msg.focused.appid || ""
                root.focusedTitle = msg.focused.title || ""
                root.focusedFullscreen = !!msg.focused.fullscreen
                root.focusedOverlap = !!msg.focused.overlap
                root.focusedYellow = msg.focused.yellow || 0
            }
            root.dockHoverAppId = msg.dock_hover || ""
            root.available = true
            root.stateChanged()
        } catch (e) {
            console.warn("KalinViewport: bad state line:", e)
        }
    }

    // ── Commands ─────────────────────────────────────────────────────────────
    function send(cmd): void {
        if (sock.connected) sock.write(cmd + "\n")
    }
    function pan(dx, dy): void { send("pan " + dx + " " + dy) }
    function zoomBy(factor): void { send("zoom " + factor) }
    function zoomReset(): void { send("zoom-reset") }
    function toggleFollow(): void { send("follow-toggle") }
    function spotlight(on): void { send("spotlight " + (on ? 1 : 0)) }

    // Arm a one-shot "dock this app_id straight into this rect the moment
    // it maps" request — send *before* spawning a panel's backing terminal
    // (its client doesn't exist yet, so dock() itself would no-op). Makes
    // the very first frame a docked panel ever shows already docked: no
    // flash at a default floating position, no camera jump chasing it
    // there (see dockprep_register()/dockprep_consume() in dwl.c).
    function dockPrep(appId, x, y, w, h): void {
        send("dockprep " + appId + " " + Math.round(x) + " " + Math.round(y) + " "
             + Math.round(w) + " " + Math.round(h))
    }
    // Pin a client (by app_id) into an exact borderless screen rect,
    // exempt from camera pan/zoom — see setdocked() in dwl.c. For embedding
    // a real, fully interactive client at a fixed spot in a shell panel's
    // own layout, e.g. ClipboardPanel.
    function dock(appId, x, y, w, h): void {
        send("dock " + appId + " " + Math.round(x) + " " + Math.round(y) + " "
             + Math.round(w) + " " + Math.round(h))
    }
    // Release a docked client back to a normal floating window at its
    // pre-dock geometry. Does not hide it — pair with minimize().
    function undock(appId): void { send("undock " + appId) }
    // Hide/show a client by app_id without touching its surface.
    function minimize(appId, minimized): void {
        send("minimize " + appId + " " + (minimized ? 1 : 0))
    }
}
