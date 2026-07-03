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
//                      "focused":{appid,title,fullscreen}}
//   client -> server: pan <dx> <dy> | zoom <factor> | zoom-reset | follow-toggle
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
    property bool exitPending: false    // quit() armed; waiting for 2nd Esc

    // Focused window mirrored from the compositor (foreign-toplevel is the
    // authoritative window list; this is a convenience for OSD/labels).
    property string focusedAppId: ""
    property string focusedTitle: ""
    property bool focusedFullscreen: false
    property bool focusedFloating: false
    // Focused window's on-screen rect (px), for flowing overlays out of it.
    property rect focusedRect: Qt.rect(0, 0, 0, 0)

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
            root.exitPending = !!msg.exit_pending
            if (msg.rect)
                root.focusedRect = Qt.rect(msg.rect.x, msg.rect.y, msg.rect.w, msg.rect.h)
            if (msg.focused) {
                root.focusedAppId = msg.focused.appid || ""
                root.focusedTitle = msg.focused.title || ""
                root.focusedFullscreen = !!msg.focused.fullscreen
                root.focusedFloating = !!msg.focused.floating
            }
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
}
