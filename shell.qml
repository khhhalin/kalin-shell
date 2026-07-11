//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io

import "./modules"
import "./modules/services"
import "./modules/widgets"

ShellRoot {
    id: root

    // External IPC toggles, e.g. `qs ipc call windows-bar toggleMenu`
    IpcHandler {
        target: "windows-bar"
        function toggleMenu(): void {
            MenuState.toggleMenu()
        }
        // Exposé/overview, bound to a compositor keybind.
        function toggleOverview(): void {
            OverviewState.toggle()
        }
        function showOverview(): void { OverviewState.show() }
        function hideOverview(): void { OverviewState.hide() }
    }

    WindowsBar {}

    // Exposé overlay + infinite-canvas camera OSD (inert unless running on
    // kalin-wm, which exports $KALIN_IPC_SOCKET / foreign-toplevel handles).
    Overview {}
    Osd {}

    // Hold-Super window-actions hint menu + "Esc again to quit" prompt.
    WindowActions {}

    // Hold-Super spawn-connection lines (kalin-wm only; inert on niri).
    ConnectionLines {}

    // Notification popups (freedesktop NotificationServer).
    Notifications {}

    // Global password prompt for Wi-Fi and other secure connections.
    PasswordDialog {}
}
