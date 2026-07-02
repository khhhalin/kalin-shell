pragma Singleton
import Quickshell

// Tracks which tab is active in the right-side system panel.
// Any widget can write currentTab; SystemPanel reacts automatically.
Singleton {
    id: root

    // "wifi" | "bluetooth" | "battery" | "volume" | "display"
    property string currentTab: "wifi"

    // Which widget last pinned the right panel ("clock" | "wifi" | "bluetooth" | "battery" | "volume" | "display" | "")
    property string rightOwner: ""
}
