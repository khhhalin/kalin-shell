import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import Quickshell.Io
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// SystemPanel — right-side panel with Wi-Fi, Bluetooth, and Battery sections.
// Tab selection is driven by SystemPanelState.currentTab.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root


    // ── Pane container ────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent

        // ════════════════════════════════════════════════════════════════════
        // Wi-Fi pane
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: wifiPane
            anchors.fill: parent
            visible: SystemPanelState.currentTab === "wifi"

            ListModel { id: wifiNetworks }

            // ── Processes ────────────────────────────────────────────────────
            Process {
                id: nmcliList
                command: ["nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL,SECURITY",
                          "dev", "wifi", "list", "--rescan", "no"]

                stdout: StdioCollector {
                    onStreamFinished: {
                        wifiNetworks.clear()
                        var lines = this.text.trim().split("\n")
                        var seen = {}
                        for (var i = 0; i < lines.length; i++) {
                            var line = lines[i].trim()
                            if (!line) continue
                            // ACTIVE:SSID:SIGNAL:SECURITY  (nmcli -t escapes colons in SSID as \:)
                            var p1 = line.indexOf(":")
                            if (p1 < 0) continue
                            var isActive = line.substring(0, p1) === "yes"
                            var rest = line.substring(p1 + 1)
                            // Signal and Security fields never contain colons – split from right
                            var p3 = rest.lastIndexOf(":")
                            var p2 = rest.lastIndexOf(":", p3 - 1)
                            var security = rest.substring(p3 + 1)
                            var sig      = parseInt(rest.substring(p2 + 1, p3)) || 0
                            var ssid     = rest.substring(0, p2)
                            if (!ssid || seen[ssid]) continue
                            seen[ssid] = true
                            wifiNetworks.append({ active: isActive, ssid: ssid,
                                                  signal: sig, security: security })
                        }
                    }
                }
                stderr: StdioCollector {}
            }

            Process {
                id: nmcliConnect
                stdout: StdioCollector {}
                stderr: StdioCollector {}
                onExited: Qt.callLater(function() { nmcliList.running = true })
            }

            Process {
                id: nmcliDisconnect
                stdout: StdioCollector {}
                stderr: StdioCollector {}
                onExited: Qt.callLater(function() { nmcliList.running = true })
            }

            Process {
                id: nmcliRescan
                command: ["nmcli", "dev", "wifi", "rescan"]
                stdout: StdioCollector {}
                stderr: StdioCollector {}
                onExited: nmcliList.running = true
            }

            Connections {
                target: PromptState
                function onPasswordEntered(ssid, password): void {
                    nmcliConnect.command = ["nmcli", "dev", "wifi", "connect", ssid, "password", password]
                    nmcliConnect.running = true
                }
            }

            Timer {
                interval: 15000; running: true; repeat: true
                triggeredOnStart: true
                onTriggered: nmcliList.running = true
            }

            // ── Header row ────────────────────────────────────────────────────
            Item {
                id: wifiHeader
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: 16; rightMargin: 16; topMargin: 14 }
                height: 28

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Available Networks"
                    color: "#888888"; font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                }

                Rectangle {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 30; height: 26; radius: 6
                    color: scanMa.containsMouse ? "#3a3a3a" : "#2a2a2a"
                    Text { anchors.centerIn: parent; text: "↻"; color: "#e6e6e6"; font.pixelSize: 15 }
                    MouseArea {
                        id: scanMa; anchors.fill: parent
                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: nmcliRescan.running = true
                    }
                }
            }

            // ── Network list ──────────────────────────────────────────────────
            Flickable {
                anchors { left: parent.left; right: parent.right
                          top: wifiHeader.bottom; bottom: parent.bottom; topMargin: 6 }
                contentHeight: wifiCol.height
                clip: true

                Column {
                    id: wifiCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: wifiNetworks

                        delegate: Rectangle {
                            required property bool   active
                            required property string ssid
                            required property int    signal
                            required property string security

                            width: wifiCol.width; height: 52; radius: 8
                            color: netRowMa.containsMouse ? "#252525" : "transparent"

                            Item {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }

                                Text {
                                    id: wifiSigIcon
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    text: signal >= 75 ? "\udb82\udd28"
                                        : signal >= 50 ? "\udb82\udd25"
                                        : signal >= 25 ? "\udb82\udd22"
                                        :                "\udb82\udd1f"
                                    color: active ? "#4fc3f7" : "#aaaaaa"
                                    font.pixelSize: 20; font.family: "monospace"
                                    width: 28
                                }

                                Column {
                                    anchors { left: wifiSigIcon.right; leftMargin: 10
                                              right: netConnBtn.left; rightMargin: 10
                                              verticalCenter: parent.verticalCenter }
                                    spacing: 2
                                    Text {
                                        text: ssid; color: active ? "#4fc3f7" : "#e6e6e6"
                                        font.pixelSize: 13
                                        elide: Text.ElideRight; width: parent.width
                                    }
                                    Text {
                                        text: active ? "Connected" : (security ? security : "Open")
                                        color: "#888888"; font.pixelSize: 11
                                    }
                                }

                                Rectangle {
                                    id: netConnBtn
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    width: 80; height: 26; radius: 6
                                    color: active
                                           ? "#1a4a5a"
                                           : (netBtnMa.containsMouse ? "#2a4a2a" : "#2a2a2a")

                                    Text {
                                        anchors.centerIn: parent
                                        text:  active ? "Disconnect" : "Connect"
                                        color: active ? "#4fc3f7" : "#cccccc"
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: netBtnMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (active) {
                                                nmcliDisconnect.command = ["nmcli", "con", "down", ssid]
                                                nmcliDisconnect.running = true
                                            } else if (security && security !== "Open" && security !== "--") {
                                                PromptState.requestPassword(ssid)
                                            } else {
                                                nmcliConnect.command = ["nmcli", "dev", "wifi", "connect", ssid]
                                                nmcliConnect.running = true
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: netRowMa; anchors.fill: parent
                                hoverEnabled: true; acceptedButtons: Qt.NoButton
                            }
                        }
                    }
                }
            }
        }

        // ════════════════════════════════════════════════════════════════════
        // Bluetooth pane
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: btPane
            anchors.fill: parent
            visible: SystemPanelState.currentTab === "bluetooth"

            readonly property var  adapter: Bluetooth.defaultAdapter
            readonly property bool btOn:    adapter ? adapter.enabled : false

            // ── Header with power toggle ──────────────────────────────────────
            Item {
                id: btHeader
                anchors { left: parent.left; right: parent.right; top: parent.top
                          leftMargin: 16; rightMargin: 16; topMargin: 16 }
                height: 40

                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                    text: "Bluetooth"; color: "#e6e6e6"; font.pixelSize: 15
                }

                // Toggle pill
                Rectangle {
                    id: btTogglePill
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: 44; height: 24; radius: 12
                    color: btPane.btOn ? "#4fc3f7" : "#3a3a3a"
                    Behavior on color { ColorAnimation { duration: 150 } }

                    Rectangle {
                        x: btPane.btOn ? 22 : 2; y: 2
                        width: 20; height: 20; radius: 10; color: "white"
                        Behavior on x { NumberAnimation { duration: 150 } }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        onClicked: if (btPane.adapter) btPane.adapter.enabled = !btPane.adapter.enabled
                    }
                }
            }

            Text {
                id: btSubtext
                anchors { left: parent.left; top: btHeader.bottom; leftMargin: 16; topMargin: 2 }
                text: btPane.adapter ? (btPane.btOn ? "On · " + (btPane.adapter.name || "") : "Off") : "No adapter found"
                color: "#888888"; font.pixelSize: 11
            }

            Rectangle {
                id: btDivider
                anchors { left: parent.left; right: parent.right; top: btSubtext.bottom
                          leftMargin: 16; rightMargin: 16; topMargin: 12 }
                height: 1; color: "#2a2a2a"
            }

            Text {
                id: btDevicesLabel
                anchors { left: parent.left; top: btDivider.bottom; leftMargin: 16; topMargin: 10 }
                visible: btPane.btOn
                text: "Paired Devices"
                color: "#888888"; font.pixelSize: 11; font.capitalization: Font.AllUppercase
            }

            // "Bluetooth is off" placeholder
            Text {
                anchors.centerIn: parent
                visible: !btPane.btOn
                text: "Bluetooth is off"; color: "#555555"; font.pixelSize: 13
            }

            // ── Device list ───────────────────────────────────────────────────
            Flickable {
                anchors { left: parent.left; right: parent.right
                          top: btDevicesLabel.bottom; bottom: parent.bottom; topMargin: 6 }
                contentHeight: btDevCol.height
                clip: true
                visible: btPane.btOn

                Column {
                    id: btDevCol
                    width: parent.width
                    spacing: 2

                    Repeater {
                        model: btPane.adapter ? btPane.adapter.devices : null

                        delegate: Rectangle {
                            required property var modelData

                            width: btDevCol.width; height: 52; radius: 8
                            color: btDevRowMa.containsMouse ? "#252525" : "transparent"

                            Item {
                                anchors { fill: parent; leftMargin: 12; rightMargin: 12 }

                                Text {
                                    id: btDevIcon
                                    anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                                    text: "\udb80\udcaf"
                                    color: modelData.connected ? "#4fc3f7" : "#888888"
                                    font.pixelSize: 20; font.family: "monospace"
                                    width: 28
                                }

                                Column {
                                    anchors { left: btDevIcon.right; leftMargin: 10
                                              right: btDevBtn.left; rightMargin: 10
                                              verticalCenter: parent.verticalCenter }
                                    spacing: 2
                                    Text {
                                        text: modelData.name || modelData.address
                                        color: "#e6e6e6"; font.pixelSize: 13
                                        elide: Text.ElideRight; width: parent.width
                                    }
                                    Text {
                                        text: modelData.connected ? "Connected" : "Paired"
                                        color: modelData.connected ? "#4fc3f7" : "#888888"
                                        font.pixelSize: 11
                                    }
                                }

                                Rectangle {
                                    id: btDevBtn
                                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                    width: 80; height: 26; radius: 6
                                    color: modelData.connected
                                           ? "#1a4a5a"
                                           : (btDevBtnMa.containsMouse ? "#2a4a2a" : "#2a2a2a")

                                    Text {
                                        anchors.centerIn: parent
                                        text:  modelData.connected ? "Disconnect" : "Connect"
                                        color: modelData.connected ? "#4fc3f7" : "#cccccc"
                                        font.pixelSize: 11
                                    }

                                    MouseArea {
                                        id: btDevBtnMa; anchors.fill: parent
                                        hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: modelData.connected = !modelData.connected
                                    }
                                }
                            }

                            MouseArea {
                                id: btDevRowMa; anchors.fill: parent
                                hoverEnabled: true; acceptedButtons: Qt.NoButton
                            }
                        }
                    }

                    // Empty state
                    Text {
                        width: btDevCol.width
                        horizontalAlignment: Text.AlignHCenter
                        topPadding: 20
                        visible: btPane.btOn && btPane.adapter &&
                                 btPane.adapter.devices.length === 0
                        text: "No paired devices"; color: "#555555"; font.pixelSize: 13
                    }
                }
            }
        }

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

        // ════════════════════════════════════════════════════════════════════
        // Display pane
        // ════════════════════════════════════════════════════════════════════
        Item {
            id: displayPane
            anchors.fill: parent
            visible: SystemPanelState.currentTab === "display"

            DisplayPanel { anchors.fill: parent }
        }
    }
}
