pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Bluetooth

// Lightweight singleton that exposes BlueZ adapter state for the bar and panels.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter ? adapter.enabled : false

    readonly property var connectedDevices: {
        if (!adapter) return []
        var result = []
        var devs = adapter.devices
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].connected) result.push(devs[i])
        }
        return result
    }

    readonly property int connectedCount: connectedDevices.length

    readonly property string icon: enabled ? "󰂯" : "󰂲"

    readonly property string statusText: {
        if (!enabled) return "Bluetooth off"
        if (connectedCount === 0) return "Bluetooth on, no devices connected"
        if (connectedCount === 1) {
            var name = connectedDevices[0].name || connectedDevices[0].address || "device"
            return "Connected: " + name
        }
        return "Connected: " + connectedCount + " devices"
    }
}
