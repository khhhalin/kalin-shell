import QtQuick
import Quickshell

import "./services"

// Per-screen shell: since the 2026-07-17 TUI-bar cutover the bar itself is a
// docked kitty terminal (kalin-bar-tui bar) — BarHost only reserves the strip
// and supervises the process. The old QML surface (BottomBar + SidePanel
// calendar drawer + taskbar peek/context menu + DockedPanel triggers) was
// deleted with the cutover: taskbar and panel toggling live inside the bar
// TUI now, and their QML replacements-to-be (calendar, peek, tray, MPRIS) are
// tracked in the kalin-wm vault's tui-bar note. KALIN_TUI_BAR=0 flips
// BarConfig.useTuiBar back, but the QML bar it used to select is gone — the
// escape hatch then just leaves the strip unreserved.
Item {
    id: root

    required property ShellScreen screen

    Loader {
        active: BarConfig.useTuiBar
        sourceComponent: BarHost {
            screen:     root.screen
            heightHint: BarConfig.barHeight
        }
    }
}
