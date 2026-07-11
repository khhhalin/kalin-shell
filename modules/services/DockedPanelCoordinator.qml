pragma Singleton
import Quickshell

// Every DockedPanel.qml instance on a given monitor shares that monitor's
// on-screen rect (bottom-right, flush with its own bar), so two panels open
// at once *on the same screen* would visually overlap/fight for the same
// spot. This tracks which one is currently open **per screen** — a newly-
// opening panel only asks the previous panel *on its own monitor* to close,
// not panels on other monitors (each monitor's docked-panel rect is
// independent; see WindowsBar.qml for why there's one bar per screen now).
Singleton {
    id: root

    // screen name -> appId of that screen's currently-open docked panel.
    // A `var` (plain JS object) rather than one string, now that there's
    // one bar (and one independent docked-panel rect) per monitor.
    property var activeByScreen: ({})

    signal closeRequested(string appId)

    // Called by a DockedPanel right before it opens. If a *different* panel
    // was active *on the same screen*, ask it to close first, then claim
    // the slot.
    function claim(screenName, appId): void {
        const prevAppId = root.activeByScreen[screenName] || ""
        if (prevAppId !== "" && prevAppId !== appId)
            root.closeRequested(prevAppId)
        // Reassign the whole object rather than mutate in place — QML's
        // property-change notification doesn't see through an in-place
        // mutation of a `var` object, only a new assignment.
        const next = Object.assign({}, root.activeByScreen)
        next[screenName] = appId
        root.activeByScreen = next
    }

    function release(screenName, appId): void {
        if (root.activeByScreen[screenName] !== appId)
            return
        const next = Object.assign({}, root.activeByScreen)
        delete next[screenName]
        root.activeByScreen = next
    }
}
