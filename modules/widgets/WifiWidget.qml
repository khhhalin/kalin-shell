import QtQuick
import Quickshell.Io
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// WifiWidget — shows connected SSID and strength via nmcli polling.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool hovered: false

    // ── Polled data ───────────────────────────────────────────────────────────
    property string ssid:     ""
    property int    strength: 0
    readonly property bool online: ssid.length > 0

    // Poll every 15 s and on startup.
    Timer {
        interval: 15000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: nmcliProc.running = true
    }

    // nmcli -t -f active,ssid,signal dev wifi
    // Each line: "yes:MySSID:75" or "no:Other:40"
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
                        root.ssid     = parts[1]
                        root.strength = parseInt(parts[2]) || 0
                        break
                    }
                }
            }
        }

        stderr: StdioCollector {}
    }

    // ── Derived label ─────────────────────────────────────────────────────────
    readonly property string icon: {
        if (!online)          return "󰤭"   // no connection
        if (strength >= 75)   return "󰤨"   // excellent
        if (strength >= 50)   return "󰤥"   // good
        if (strength >= 25)   return "󰤢"   // fair
        return "󰤟"                         // weak
    }
    readonly property string displaySsid: ssid.length > 20
                                          ? ssid.substring(0, 19) + "…"
                                          : ssid
    readonly property string label: online ? (icon + " " + displaySsid) : (icon + " No WiFi")
    readonly property color  textColor: online ? "#e6e6e6" : "#555555"

    property bool active:  false

    implicitWidth:  Math.max(wifiText.implicitWidth + 20, 64)
    implicitHeight: BarConfig.barHeight

    Rectangle {
        anchors.fill: parent
        radius:       BarConfig.buttonRadius
        color:        root.active ? "#2f2f2f" : (root.hovered ? "#2a2a2a" : "transparent")
        border.width: root.active ? 1 : 0
        border.color: "#3a3a3a"

        Text {
            id:              wifiText
            anchors.centerIn: parent
            text:            root.label
            color:           root.textColor
            font.pixelSize:  BarConfig.clockFontSize
            font.family:     "monospace"
        }
    }

    signal clicked()

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered:    root.hovered = true
        onExited:     root.hovered = false
        onClicked:    root.clicked()
    }
}
