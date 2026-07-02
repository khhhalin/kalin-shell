pragma Singleton
import QtQuick
import Quickshell

/// Global signal bus so an external IPC call can toggle the left panel
/// on every screen instance without needing a direct object reference.
Singleton {
    id: root
    signal toggleMenu()
}
