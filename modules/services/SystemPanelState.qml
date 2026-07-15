pragma Singleton
import Quickshell

// State for the right-side SidePanel drawer, which now only serves the
// clock's calendar. Every other status widget (battery included, since the
// kalin_tuis suite landed) is a docked TUI panel with its own open state —
// see BottomBar.qml's DockedPanel instances.
Singleton {
    id: root

    // Which widget pinned the right panel ("clock" | "")
    property string rightOwner: ""
}
