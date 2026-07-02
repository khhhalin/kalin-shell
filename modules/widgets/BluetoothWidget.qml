import QtQuick
import Quickshell.Bluetooth
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// BluetoothWidget — shows adapter power state and number of connected devices.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool hovered: false

    // ── Bluetooth data ────────────────────────────────────────────────────────
    readonly property var  adapter:        Bluetooth.defaultAdapter
    readonly property bool enabled:        adapter ? adapter.enabled : false
    readonly property var  connectedDevices: {
        if (!adapter) return []
        var result = []
        var devs = adapter.devices
        for (var i = 0; i < devs.length; i++) {
            if (devs[i].connected) result.push(devs[i])
        }
        return result
    }
    readonly property int  connectedCount: connectedDevices.length

    // ── Derived label ─────────────────────────────────────────────────────────
    readonly property string icon:  enabled ? "󰂯" : "󰂲"
    readonly property string deviceLabel: {
        if (connectedCount === 0) return icon
        if (connectedCount === 1) {
            var name = connectedDevices[0].name || ""
            if (name.length === 0) return icon + " 1"
            var display = name.length > 18 ? name.substring(0, 17) + "…" : name
            return icon + " " + display
        }
        return icon + " " + connectedCount
    }
    readonly property string label: deviceLabel
    readonly property color textColor: {
        if (!enabled)           return "#555555"
        if (connectedCount > 0) return "#4fc3f7"   // blue — device connected
        return "#e6e6e6"                            // white — on but idle
    }

    property bool active:  false

    implicitWidth:  Math.max(btText.implicitWidth + 20, 48)
    implicitHeight: BarConfig.barHeight

    Rectangle {
        anchors.fill: parent
        radius:       BarConfig.buttonRadius
        color:        root.active ? "#2f2f2f" : (root.hovered ? "#2a2a2a" : "transparent")
        border.width: root.active ? 1 : 0
        border.color: "#3a3a3a"

        Text {
            id:              btText
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
