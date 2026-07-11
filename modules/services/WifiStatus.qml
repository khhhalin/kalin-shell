pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Lightweight singleton that polls nmcli for the current WiFi connection.
Singleton {
    id: root

    property string ssid: ""
    property int strength: 0
    readonly property bool online: ssid.length > 0

    readonly property string icon: {
        if (!online)          return "󰤭"
        if (strength >= 75)   return "󰤨"
        if (strength >= 50)   return "󰤥"
        if (strength >= 25)   return "󰤢"
        return "󰤟"
    }

    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: nmcliProc.running = true
    }

    Process {
        id: nmcliProc
        command: ["nmcli", "-t", "-f", "active,ssid,signal", "dev", "wifi"]

        stdout: StdioCollector {
            onStreamFinished: {
                var lines = this.text.trim().split("\n")
                root.ssid = ""
                root.strength = 0
                for (var i = 0; i < lines.length; i++) {
                    var parts = lines[i].split(":")
                    if (parts[0] === "yes" && parts.length >= 3) {
                        root.ssid = parts[1]
                        root.strength = parseInt(parts[2]) || 0
                        break
                    }
                }
            }
        }

        stderr: StdioCollector {}
    }
}
