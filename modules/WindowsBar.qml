import QtQuick
import Quickshell

Variants {
    // One bar per connected monitor — kalin-wm's camera is a single shared
    // infinite canvas (every monitor is a window into the same coordinate
    // space, not an independent camera per screen), but each monitor still
    // gets its own bar + docked panels. Re-evaluates on Quickshell.screens
    // changes, so plugging/unplugging a display adds/removes its bar live.
    model: Quickshell.screens

    Scope {
        required property ShellScreen modelData

        WindowsBarScreen {
            screen: modelData
        }
    }
}
