pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// ─────────────────────────────────────────────────────────────────────────────
// NotificationService — owns the freedesktop NotificationServer and tracks the
// list of active popups. Cards drive their own auto-dismiss.
//
// NOTE: only one process may own org.freedesktop.Notifications. If dunst (or
// another daemon) is running, this server won't receive notifications until it
// is disabled (home-config: environment/rice/default.nix). No harm if both run;
// this one simply stays empty.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // Active popups, most-recent first.
    property var popups: []

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: function (notif) {
            notif.tracked = true
            const list = root.popups.slice()
            list.unshift(notif)
            root.popups = list.slice(0, 6) // cap visible stack
        }
    }

    function remove(notif): void {
        root.popups = root.popups.filter(n => n !== notif)
    }

    function dismiss(notif): void {
        remove(notif)
        if (notif) notif.dismiss()
    }

    function clearAll(): void {
        const all = root.popups.slice()
        root.popups = []
        for (const n of all) if (n) n.dismiss()
    }
}
