pragma Singleton
import Quickshell

// Tracks which tab is active in the right-side system panel.
Singleton {
    id: root

    // Side-panel state. Default to "battery" — the only other tab, "clock",
    // is opt-in via a click. Stats/volume/wifi/bluetooth/display all moved
    // to their own docked TUI panels (see BottomBar.qml's DockedPanel
    // instances) and no longer route through here at all.
    property string currentTab: "battery"

    // Which widget last pinned the right panel ("clock" | "battery" | "")
    property string rightOwner: ""
}
