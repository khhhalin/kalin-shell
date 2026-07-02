import QtQuick
import Quickshell.Services.Pipewire
import Quickshell.Io
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// MixerPanel — master volume + per-app stream sliders via Pipewire.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    // ── Master controls backend (wpctl) ──────────────────────────────────────
    // Pipewire QML audio mute state can be stale on some setups; wpctl is
    // authoritative for default sink/source.
    property bool   sinkReady:   false
    property double sinkVol:     0.0
    property bool   sinkMuted:   false
    property bool   sourceReady: false
    property double sourceVol:   0.0
    property bool   sourceMuted: false

    function _parseWpctlVolume(text) {
        var t = String(text || "").trim()
        var m = t.match(/Volume:\s*([0-9.]+)/)
        if (!m || m.length < 2) return null
        return {
            vol: Math.max(0.0, Math.min(1.25, parseFloat(m[1]) || 0.0)),
            muted: t.indexOf("MUTED") !== -1,
        }
    }

    Timer {
        interval: 1200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sinkGetProc.running) sinkGetProc.running = true
            if (!sourceGetProc.running) sourceGetProc.running = true
        }
    }

    Process {
        id: sinkGetProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var r = root._parseWpctlVolume(this.text)
                if (!r) { root.sinkReady = false; return }
                root.sinkReady = true
                root.sinkVol = r.vol
                root.sinkMuted = r.muted
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: sourceGetProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]
        stdout: StdioCollector {
            onStreamFinished: {
                var r = root._parseWpctlVolume(this.text)
                if (!r) { root.sourceReady = false; return }
                root.sourceReady = true
                root.sourceVol = r.vol
                root.sourceMuted = r.muted
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: wpctlCmd
        command: ["wpctl", "status"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    function wpctl(args) {
        wpctlCmd.command = ["wpctl"].concat(args)
        wpctlCmd.running = true
    }

    function streamNodeId(node) {
        if (!node) return ""
        // Try a handful of common id property names across bindings.
        var candidates = [
            node.id,
            node.objectId,
            node.nodeId,
            node.pwId,
            node.pw_id,
            node.pipewireId,
            node.pipewire_id,
        ]
        for (var i = 0; i < candidates.length; i++) {
            var v = candidates[i]
            if (v === undefined || v === null) continue
            var s = String(v)
            if (s.length === 0) continue
            // Prefer numeric ids.
            if (isFinite(Number(s))) return s
        }
        return ""
    }

    function setStreamVolume(node, audio, v) {
        var id = node && (node.id || node.objectId || node.nodeId)
        // Prefer wpctl by node id when possible (works even if QML audio isn't writable).
        if (id) {
            root.wpctl(["set-volume", String(id), String(v)])
            return
        }
        if (audio) root.setAudioVolume(audio, v)
    }

    function toggleStreamMute(node, audio) {
        var id = node && (node.id || node.objectId || node.nodeId)
        if (id) {
            root.wpctl(["set-mute", String(id), "toggle"])
            return
        }
        if (audio) root.setAudioMuted(audio, !audio.muted)
    }

    function setAudioVolume(audio, v) {
        if (!audio) return
        // Some Quickshell versions expose volume as a writable property,
        // others expose setter functions.
        if (typeof audio.setVolume === "function") audio.setVolume(v)
        else audio.volume = v
    }

    function setAudioMuted(audio, m) {
        if (!audio) return
        if (typeof audio.setMuted === "function") audio.setMuted(m)
        else audio.muted = m
    }

    function nodeMediaClass(n) {
        if (!n) return ""
        // Try common property names.
        return String(n.mediaClass || n.media_class || n.mediaClassName || n.className || "")
    }

    function isAppPlaybackStreamNode(n) {
        if (!n || !n.audio) return false
        if (!n.isStream) return false

        var mc = nodeMediaClass(n)
        if (mc.indexOf("Stream/Output/Audio") !== -1) return true
        // Fallback heuristics for older/newer bindings.
        if (n.isOutput === true) return true
        if (n.isSinkInput === true) return true
        if (n.isSink === true) return true
        return false
    }

    property bool hasAppStreams: false
    Timer {
        interval: 800
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            var any = false
            var nodes = Pipewire.nodes
            for (var i = 0; i < nodes.length; i++) {
                if (root.isAppPlaybackStreamNode(nodes[i])) { any = true; break }
            }
            root.hasAppStreams = any
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────────────
    component VolumeSlider: Item {
        id: sliderRoot

        property double value: 0.0          // 0.0 – 1.25  (125 % max)
        property bool   muted: false
        property string icon:  "󰕾"
        property string label: ""
        property color  accentColor: "#4a9eff"
        property bool   showMuteBtn: true

        signal volumeChanged(double v)
        signal muteToggled()

        height: 54

        readonly property double _safeValue: isFinite(sliderRoot.value) ? sliderRoot.value : 0.0

        // Mute / icon button
        Rectangle {
            id: muteBtn
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            width: 32; height: 32; radius: 6
            visible: sliderRoot.showMuteBtn
            color: muteMa.containsMouse ? "#2a2a2a" : "transparent"

            Text {
                anchors.centerIn: parent
                text:            sliderRoot.icon
                color:           sliderRoot.muted ? "#ff6b6b" : "#e6e6e6"
                font.pixelSize:  16
                font.family:     "monospace"
            }
            MouseArea {
                id: muteMa; anchors.fill: parent
                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: sliderRoot.muteToggled()
            }
        }

        // Label
        Text {
            id: nameLabel
            anchors { left: muteBtn.right; leftMargin: 6; verticalCenter: parent.verticalCenter }
            visible: sliderRoot.label.length > 0
            text:    sliderRoot.label
            color:   sliderRoot.muted ? "#666666" : "#e6e6e6"
            font.pixelSize: 12
            elide: Text.ElideRight
            width: Math.min(implicitWidth, 120)
        }

        // Percentage label
        Text {
            id: pctLabel
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            text:           Math.round(sliderRoot._safeValue * 100) + "%"
            color:          "#888888"
            font.pixelSize: 11
            width: 32
            horizontalAlignment: Text.AlignRight
        }

        // Track
        Item {
            id: track
            anchors {
                left:  sliderRoot.label.length > 0 ? nameLabel.right : muteBtn.right
                right: pctLabel.left
                leftMargin: 8; rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            height: 6

            Rectangle {
                anchors.fill: parent
                radius: 3
                color: "#2a2a2a"
            }

            Rectangle {
                width:  Math.min(parent.width, parent.width * sliderRoot._safeValue / 1.25)
                height: parent.height
                radius: 3
                color:  sliderRoot.muted ? "#555555" : sliderRoot.accentColor
            }

            MouseArea {
                anchors { fill: parent; margins: -8 }
                hoverEnabled: true
                cursorShape:  Qt.PointingHandCursor
                function seek(mouse) {
                    var v = Math.max(0, Math.min(1.25, (mouse.x / track.width) * 1.25))
                    sliderRoot.volumeChanged(v)
                }
                onPressed:      function(mouse) { seek(mouse) }
                onPositionChanged: function(mouse) { if (pressed) seek(mouse) }
                onWheel: function(wheel) {
                    var delta = wheel.angleDelta.y / 120 * 0.05
                    var v = Math.max(0, Math.min(1.25, sliderRoot._safeValue + delta))
                    sliderRoot.volumeChanged(v)
                }
            }
        }
    }

    // ── Master sink section ───────────────────────────────────────────────────
    Item {
        id: masterSection
        anchors { left: parent.left; right: parent.right; top: parent.top
                  leftMargin: 16; rightMargin: 16; topMargin: 14 }
        height: childrenRect.height

        Text {
            id: masterLabel
            text: "Output"
            color: "#888888"; font.pixelSize: 11
            font.capitalization: Font.AllUppercase
        }

        VolumeSlider {
            anchors { left: parent.left; right: parent.right; top: masterLabel.bottom; topMargin: 2 }
            value: root.sinkReady ? root.sinkVol : 0
            muted: root.sinkReady ? root.sinkMuted : false
            icon:  {
                var v = root.sinkReady ? root.sinkVol : 0
                if (muted || v === 0) return "󰄟"
                return v < 0.5 ? "󰅀" : "󰄾"
            }
            accentColor: "#4a9eff"
            onVolumeChanged: v => root.wpctl(["set-volume", "@DEFAULT_AUDIO_SINK@", String(v)])
            onMuteToggled:   root.wpctl(["set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"])
        }
    }

    // ── Microphone section ────────────────────────────────────────────────────
    Item {
        id: micSection
        anchors { left: parent.left; right: parent.right; top: masterSection.bottom
                  leftMargin: 16; rightMargin: 16; topMargin: 8 }
        height: childrenRect.height

        Text {
            id: micLabel
            text: "Input"
            color: "#888888"; font.pixelSize: 11
            font.capitalization: Font.AllUppercase
        }

        VolumeSlider {
            anchors { left: parent.left; right: parent.right; top: micLabel.bottom; topMargin: 2 }
            value: root.sourceReady ? root.sourceVol : 0
            muted: root.sourceReady ? root.sourceMuted : false
            icon:  muted ? "󰇭" : "󰇬"
            accentColor: "#a78bfa"
            onVolumeChanged: v => root.wpctl(["set-volume", "@DEFAULT_AUDIO_SOURCE@", String(v)])
            onMuteToggled:   root.wpctl(["set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"])
        }
    }

    // Divider
    Rectangle {
        id: appsDivider
        anchors { left: parent.left; right: parent.right; top: micSection.bottom
                  leftMargin: 16; rightMargin: 16; topMargin: 12 }
        height: 1; color: "#2a2a2a"
    }

    // ── App streams section ───────────────────────────────────────────────────
    Text {
        id: appsLabel
        anchors { left: parent.left; top: appsDivider.bottom
                  leftMargin: 16; topMargin: 10 }
        text: "Applications"
        color: "#888888"; font.pixelSize: 11
        font.capitalization: Font.AllUppercase
    }

    Flickable {
        anchors { left: parent.left; right: parent.right
                  top: appsLabel.bottom; bottom: parent.bottom; topMargin: 4 }
        contentHeight: streamsCol.height
        clip: true

        Column {
            id: streamsCol
            anchors { left: parent.left; right: parent.right; leftMargin: 16; rightMargin: 16 }
            spacing: 0

            Repeater {
                // Pipewire.nodes changes over time; bind directly so new streams appear.
                model: Pipewire.nodes

                delegate: VolumeSlider {
                    required property var modelData
                    readonly property var a: modelData.audio
                    readonly property string nodeId: root.streamNodeId(modelData)

                    // Pull authoritative stream volume/mute from wpctl, since
                    // Pipewire QML stream audio values can be undefined.
                    property bool _wpReady: false
                    property double _wpVol: 0.0
                    property bool _wpMuted: false

                    Timer {
                        interval: 1200
                        running: parent.visible && nodeId.length > 0
                        repeat: true
                        triggeredOnStart: true
                        onTriggered: if (!streamGetProc.running) streamGetProc.running = true
                    }

                    Process {
                        id: streamGetProc
                        command: nodeId.length > 0
                                 ? ["wpctl", "get-volume", nodeId]
                                 : ["true"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                var r = root._parseWpctlVolume(this.text)
                                if (!r) { _wpReady = false; return }
                                _wpReady = true
                                _wpVol = r.vol
                                _wpMuted = r.muted
                            }
                        }
                        stderr: StdioCollector {
                            onStreamFinished: {
                                var t = this.text.trim()
                                if (t.length > 0) console.warn("MixerPanel: wpctl get-volume failed for", nodeId, t)
                            }
                        }
                    }

                    // Throttled/queued setter so drag updates aren't dropped.
                    property double _pendingVol: 0.0
                    property bool _hasPendingVol: false

                    function _runSetVolume(v) {
                        if (nodeId.length === 0) return
                        streamSetProc.command = ["wpctl", "set-volume", nodeId, String(v)]
                        streamSetProc.running = true
                    }

                    Process {
                        id: streamSetProc
                        command: ["true"]
                        stdout: StdioCollector {
                            onStreamFinished: {
                                if (parent._hasPendingVol) {
                                    var v = parent._pendingVol
                                    parent._hasPendingVol = false
                                    parent._runSetVolume(v)
                                } else {
                                    if (!streamGetProc.running) streamGetProc.running = true
                                }
                            }
                        }
                        stderr: StdioCollector {
                            onStreamFinished: {
                                var t = this.text.trim()
                                if (t.length > 0) console.warn("MixerPanel: wpctl set-volume failed for", nodeId, t)
                            }
                        }
                    }

                    Process {
                        id: streamMuteProc
                        command: ["true"]
                        stdout: StdioCollector { onStreamFinished: { if (!streamGetProc.running) streamGetProc.running = true } }
                        stderr: StdioCollector {
                            onStreamFinished: {
                                var t = this.text.trim()
                                if (t.length > 0) console.warn("MixerPanel: wpctl set-mute failed for", nodeId, t)
                            }
                        }
                    }

                    width: streamsCol.width
                    visible: root.isAppPlaybackStreamNode(modelData)
                    height: visible ? 54 : 0
                    value: _wpReady ? _wpVol : ((a && isFinite(a.volume)) ? a.volume : 0)
                    muted: _wpReady ? _wpMuted : ((a && typeof a.muted === "boolean") ? a.muted : false)
                    icon:  "󰅃"
                    accentColor: "#4ade80"
                    label: {
                        var n = modelData.appName
                             || modelData.applicationName
                             || modelData.nickname
                             || modelData.description
                             || modelData.name
                             || ""
                        return n.length > 0 ? n : "App"
                    }
                    onVolumeChanged: v => {
                        if (nodeId.length === 0) {
                            // Fallback if we can't determine an id.
                            root.setAudioVolume(a, v)
                            return
                        }
                        if (streamSetProc.running) {
                            _pendingVol = v
                            _hasPendingVol = true
                        } else {
                            _runSetVolume(v)
                        }
                    }
                    onMuteToggled: {
                        if (nodeId.length === 0) {
                            root.setAudioMuted(a, !muted)
                            return
                        }
                        if (!streamMuteProc.running) {
                            streamMuteProc.command = ["wpctl", "set-mute", nodeId, "toggle"]
                            streamMuteProc.running = true
                        }
                    }
                }
            }

            // Empty state
            Text {
                width: streamsCol.width
                horizontalAlignment: Text.AlignHCenter
                topPadding: 12
                visible: !root.hasAppStreams
                text: "No active streams"; color: "#555555"; font.pixelSize: 12
            }
        }
    }
}
