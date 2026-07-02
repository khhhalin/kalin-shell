pragma Singleton

import Quickshell

// Shared visibility for the exposé/overview overlay. Toggled from a compositor
// keybind via:  qs ipc call windows-bar toggleOverview
Singleton {
    id: root
    property bool visible: false
    function toggle(): void { root.visible = !root.visible }
    function show(): void { root.visible = true }
    function hide(): void { root.visible = false }
}
