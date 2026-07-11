import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// SystemPanel — right-side panel, now just the Battery pane (WiFi, Bluetooth,
// and Display all moved to their own docked TUI panels — see BottomBar.qml's
// DockedPanel instances). Kept as its own component (rather than inlining
// the battery pane directly into WindowsBarScreen.qml) since BatteryWidget
// still uses the SidePanel/rightOwner system, unlike the docked panels.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root


    // ── Pane container ────────────────────────────────────────────────────────
    // WiFi and Bluetooth mini-panels lived here (visible on currentTab ===
    // "wifi"/"bluetooth"), spawning nmtui/bluetuith as plain floating
    // windows. Removed: both are now docked TUI panels of their own (see
    // BottomBar.qml's DockedPanel instances), no longer routed through
    // SystemPanelState.currentTab/rightOwner at all — so this pane could
    // never become visible any more.
    Item {
        anchors.fill: parent

        // ════════════════════════════════════════════════════════════════════
        // Battery pane
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: batPane
            anchors.fill: parent
            visible: SystemPanelState.currentTab === "battery"

            readonly property var    dev:         UPower.displayDevice
            readonly property bool   present:     dev !== null && dev.ready && dev.isPresent
            readonly property double pct:         present ? dev.percentage * 100 : 0
            readonly property bool   charging:    present && dev.state === UPowerDeviceState.Charging
            readonly property bool   full:        present && dev.state === UPowerDeviceState.FullyCharged
            readonly property bool   discharging: present && dev.state === UPowerDeviceState.Discharging

            function formatTime(secs) {
                if (!secs || secs <= 0) return "--"
                var h = Math.floor(secs / 3600)
                var m = Math.floor((secs % 3600) / 60)
                return h > 0 ? h + "h " + m + "m" : m + "m"
            }

            Flickable {
                anchors.fill: parent
                contentHeight: batCol.height
                clip: true

                Column {
                    id: batCol
                    width: parent.width
                    spacing: 0

                    // ── Big icon + % ──────────────────────────────────────────────
                    Item {
                        width: parent.width; height: 108

                        Column {
                            anchors.centerIn: parent
                            spacing: 4

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (!batPane.present) return "󰂑"
                                    if (batPane.full)     return "󰁹"
                                    if (batPane.charging) return "󰂄"
                                    var p = batPane.pct
                                    if (p <= 10) return "󰂎"
                                    if (p <= 25) return "󰁻"
                                    if (p <= 50) return "󰁽"
                                    if (p <= 75) return "󰂁"
                                    return "󰁹"
                                }
                                color: batPane.charging || batPane.full ? "#4fc3f7"
                                     : batPane.pct <= 20 && batPane.present ? "#ff6b6b"
                                     : "#e6e6e6"
                                font.pixelSize: 44; font.family: "monospace"
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: batPane.present ? Math.round(batPane.pct) + "%" : "--"
                                color: "#e6e6e6"; font.pixelSize: 26; font.weight: Font.Medium
                            }

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: {
                                    if (!batPane.present)    return "No battery"
                                    if (batPane.full)        return "Fully charged"
                                    if (batPane.charging)    return "Charging…"
                                    if (batPane.discharging) return "On battery"
                                    return "Standby"
                                }
                                color: "#888888"; font.pixelSize: 12
                            }
                        }
                    }

                    // ── Divider ───────────────────────────────────────────────────
                    Rectangle { width: parent.width; height: 1; color: "#252525" }
                    Item      { width: parent.width; height: 12 }

                    // ── Stats rows ────────────────────────────────────────────────
                    // Each row: label left, value right, inside a padded Item
                    component StatRow: Item {
                        width: parent.width; height: 22
                        property string label: ""
                        property string value: "--"
                        property color  valueColor: "#e6e6e6"
                        Text { anchors { left: parent.left; leftMargin: 16; verticalCenter: parent.verticalCenter }
                               text: parent.label; color: "#888888"; font.pixelSize: 12 }
                        Text { anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                               text: parent.value; color: parent.valueColor; font.pixelSize: 12 }
                    }

                    // Time remaining (hidden when full)
                    StatRow {
                        visible: batPane.present && !batPane.full
                        label: batPane.charging ? "Time to full" : "Time remaining"
                        value: batPane.present
                               ? (batPane.charging ? batPane.formatTime(batPane.dev.timeToFull)
                                                   : batPane.formatTime(batPane.dev.timeToEmpty))
                               : "--"
                    }

                    // Power draw / charge rate (hidden when full)
                    StatRow {
                        visible: batPane.present && !batPane.full
                        label: batPane.charging ? "Charge rate" : "Power draw"
                        value: batPane.present
                               ? Math.abs(batPane.dev.changeRate).toFixed(1) + " W"
                               : "--"
                    }

                    // Current / max energy in Wh
                    StatRow {
                        visible: batPane.present
                        label: "Energy"
                        value: batPane.present
                               ? batPane.dev.energy.toFixed(1) + " / "
                                 + batPane.dev.energyCapacity.toFixed(1) + " Wh"
                               : "--"
                    }

                    // Battery health (only when supported)
                    StatRow {
                        visible: batPane.present && batPane.dev.healthSupported
                        label: "Battery health"
                        value: batPane.present && batPane.dev.healthSupported
                               ? Math.round(batPane.dev.healthPercentage) + "%"
                               : "--"
                        valueColor: batPane.present && batPane.dev.healthSupported
                                    ? (batPane.dev.healthPercentage < 75 ? "#ffaa44"
                                     : batPane.dev.healthPercentage < 90 ? "#ffd060"
                                     : "#4ade80")
                                    : "#e6e6e6"
                    }

                    // Model name (hidden when empty)
                    StatRow {
                        visible: batPane.present && !!batPane.dev.model
                        label: "Model"
                        value: batPane.present ? (batPane.dev.model || "--") : "--"
                    }

                    Item { width: parent.width; height: 16 }

                    // ── Divider + Power profile ───────────────────────────────────
                    // PowerProfiles service may not be installed; the QS singleton
                    // still exists but does nothing.  We detect availability by
                    // checking whether the daemon answered — Quickshell logs a WARN
                    // and leaves the profile at 0 (PowerSaver) when it cannot connect.
                    // A safer heuristic: try to read profile and see if the service
                    // is "working" via the PowerProfiles.holds list being initialised.
                    // In practice, wrapping in a visible-guard on a Process check is
                    // the most reliable approach.
                    property bool profAvailable: false
                    Process {
                        id: profCheck
                        command: ["powerprofilesctl", "get"]
                        running: true
                        stdout: StdioCollector {
                            onStreamFinished: batCol.profAvailable = this.text.trim().length > 0
                        }
                        stderr: StdioCollector {}
                    }

                    Rectangle { width: parent.width; height: 1; color: "#252525"; visible: batCol.profAvailable }
                    Item      { width: parent.width; height: 14; visible: batCol.profAvailable }

                    Text {
                        anchors { left: parent.left; leftMargin: 16 }
                        visible: batCol.profAvailable
                        text: "Power Profile"
                        color: "#888888"; font.pixelSize: 11
                        font.capitalization: Font.AllUppercase
                    }

                    Item { width: parent.width; height: 10; visible: batCol.profAvailable }

                    // Three profile buttons in a row
                    Item {
                        visible: batCol.profAvailable
                        width: parent.width; height: 34

                        Row {
                            id: profRow
                            anchors { left: parent.left; right: parent.right
                                      leftMargin: 16; rightMargin: 16 }
                            height: parent.height; spacing: 6

                            readonly property int cols: PowerProfiles.hasPerformanceProfile ? 3 : 2
                            readonly property int btnW: Math.floor((width - spacing * (cols - 1)) / cols)

                            Repeater {
                                // store numeric enum values so comparison works in delegates
                                model: [
                                    { prof: PowerProfile.PowerSaver,  label: "Power Saver" },
                                    { prof: PowerProfile.Balanced,    label: "Balanced"    },
                                    { prof: PowerProfile.Performance, label: "Performance" },
                                ]

                                delegate: Rectangle {
                                    required property var modelData
                                    readonly property bool isPerf:    modelData.prof === PowerProfile.Performance
                                    readonly property bool isCurrent: PowerProfiles.profile === modelData.prof

                                    visible: !isPerf || PowerProfiles.hasPerformanceProfile
                                    width: profRow.btnW; height: profRow.height; radius: 8
                                    color: isCurrent
                                           ? "#1a3a5a"
                                           : (profMa.containsMouse ? "#2a2a2a" : "#1e1e1e")
                                    border.width: isCurrent ? 1 : 0
                                    border.color: "#4fc3f7"

                                    Text {
                                        anchors.centerIn: parent
                                        text: modelData.label
                                        color: isCurrent ? "#4fc3f7" : "#aaaaaa"
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: profMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: PowerProfiles.profile = modelData.prof
                                    }
                                }
                            }
                        }
                    }

                    Item { width: parent.width; height: 16 }
                }
            }
        }
    }
}
