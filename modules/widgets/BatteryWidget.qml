import QtQuick
import Quickshell.Services.UPower
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// BatteryWidget — shows charge percentage and charging state.
// Uses the UPower display device (the composite "battery" D-Bus object).
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool hovered: false

    // ── UPower data ───────────────────────────────────────────────────────────
    readonly property var    dev:      UPower.displayDevice
    readonly property bool   present:  dev ? dev.isPresent : false
    readonly property double pct:      present ? dev.percentage * 100 : 0
    readonly property bool   charging: present && (dev.state === UPowerDeviceState.Charging)
    readonly property bool   full:     present && (dev.state === UPowerDeviceState.FullyCharged)

    // ── Derived label parts ───────────────────────────────────────────────────
    readonly property string icon: {
        if (!present)  return "󰂑"   // no battery
        if (full)      return "󰁹"   // full / plugged
        if (charging)  return "󰂄"   // charging bolt
        if (pct <= 10) return "󰂎"   // critically low
        if (pct <= 25) return "󰁻"   // low
        if (pct <= 50) return "󰁽"   // mid-low
        if (pct <= 75) return "󰂁"   // mid
        return "󰁹"                  // high / full
    }
    readonly property string label: icon + " " + Math.round(pct) + "%"
    readonly property color  textColor: (pct <= 20 && !charging && !full) ? "#ff6b6b" : "#e6e6e6"

    implicitWidth:  Math.max(batText.implicitWidth + 20, 64)
    implicitHeight: BarConfig.barHeight

    property bool active:  false

    // Hide entirely when no battery is present (e.g., desktop)
    visible: present

    Rectangle {
        anchors.fill: parent
        radius:       BarConfig.buttonRadius
        color:        root.active ? "#2f2f2f" : (root.hovered ? "#2a2a2a" : "transparent")
        border.width: root.active ? 1 : 0
        border.color: "#3a3a3a"

        Text {
            id:              batText
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
