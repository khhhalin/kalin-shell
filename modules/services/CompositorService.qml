pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Wayland

import "."

// ─────────────────────────────────────────────────────────────────────────────
// CompositorService — a backend-agnostic window source.
//
// Picks its backend from the environment: if kalin-wm exported
// $KALIN_IPC_SOCKET we use the wlr-foreign-toplevel-management protocol (via
// Quickshell's ToplevelManager) for the window list and control; otherwise we
// delegate to the existing niri `niri msg` integration (NiriIpc).
//
// Normalized window shape (both backends):
//   { key, title, appId, isFocused, toplevel }   (toplevel is null on niri)
//
// Existing bar widgets still talk to NiriIpc directly; new overlays use this
// facade so they work on kalin-wm too.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    readonly property string backend: KalinViewport.enabled ? "kalin" : "niri"
    readonly property bool isKalin: backend === "kalin"

    readonly property bool available: isKalin ? true : NiriIpc.available

    // Unified, normalized window list.
    property var windows: []

    signal updated()

    // ── Kalin backend: wlr-foreign-toplevel via ToplevelManager ───────────────
    Connections {
        target: ToplevelManager.toplevels
        enabled: root.isKalin
        function onValuesChanged() { root._rebuildKalin() }
    }
    Connections {
        target: ToplevelManager
        enabled: root.isKalin
        function onActiveToplevelChanged() { root._rebuildKalin() }
    }

    function _rebuildKalin(): void {
        const active = ToplevelManager.activeToplevel
        const list = []
        const tls = ToplevelManager.toplevels.values
        for (let i = 0; i < tls.length; i++) {
            const tl = tls[i]
            list.push({
                key: tl,                       // the Toplevel object is the handle
                id: tl,
                title: tl.title || "",
                appId: tl.appId || "",
                isFocused: tl === active || tl.activated === true,
                toplevel: tl,
            })
        }
        root.windows = list
        root.updated()
    }

    // ── Niri backend: delegate to NiriIpc ─────────────────────────────────────
    Connections {
        target: NiriIpc
        enabled: !root.isKalin
        function onUpdated() { root._rebuildNiri() }
    }

    function _rebuildNiri(): void {
        root.windows = (NiriIpc.windows || []).map(w => ({
            key: w.id,
            id: w.id,
            title: w.title || "",
            appId: w.appId || "",
            isFocused: !!w.isFocused,
            toplevel: null,
            workspaceId: w.workspaceId,
        }))
        root.updated()
    }

    Component.onCompleted: isKalin ? _rebuildKalin() : _rebuildNiri()

    // ── Unified actions ───────────────────────────────────────────────────────
    function activate(win): void {
        if (!win) return
        if (root.isKalin) {
            if (win.toplevel) win.toplevel.activate()
        } else {
            NiriIpc.focusWindowById(win.id)
        }
    }

    function close(win): void {
        if (!win) return
        if (root.isKalin) {
            if (win.toplevel) win.toplevel.close()
        } else {
            NiriIpc.closeWindowById(win.id)
        }
    }

    // Live foreign-toplevel handles whose appId matches `appId`, for
    // ScreencopyView thumbnails (window peek). Uses ToplevelManager directly,
    // which works on any compositor implementing wlr-foreign-toplevel-management
    // (both niri and kalin-wm), independent of the window-list backend above.
    function toplevelsForAppId(appId) {
        const out = []
        if (!appId) return out
        const tls = ToplevelManager.toplevels.values
        for (let i = 0; i < tls.length; i++) {
            if (tls[i] && tls[i].appId === appId)
                out.push(tls[i])
        }
        return out
    }
}
