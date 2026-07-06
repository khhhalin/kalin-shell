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

    // Active popups, most-recent first. A ListModel so the Repeater in
    // Notifications.qml gets incremental insert/remove instead of a full
    // model teardown+rebuild on every notification — reassigning a plain JS
    // array there was crashing Qt's delegate-model incubation
    // (VDMListDelegateDataType::createMissingProperties, SIGSEGV) on every
    // incoming notification.
    property alias popups: popupsModel

    ListModel { id: popupsModel }

    NotificationServer {
        id: server
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true

        onNotification: function (notif) {
            notif.tracked = true
            popupsModel.insert(0, { notifObj: notif })
            while (popupsModel.count > 6) popupsModel.remove(popupsModel.count - 1) // cap visible stack
        }
    }

    function remove(notif): void {
        for (let i = 0; i < popupsModel.count; i++) {
            if (popupsModel.get(i).notifObj === notif) {
                popupsModel.remove(i)
                break
            }
        }
    }

    function dismiss(notif): void {
        remove(notif)
        if (notif) notif.dismiss()
    }

    function clearAll(): void {
        const all = []
        for (let i = 0; i < popupsModel.count; i++) all.push(popupsModel.get(i).notifObj)
        popupsModel.clear()
        for (const n of all) if (n) n.dismiss()
    }
}
