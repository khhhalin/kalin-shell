import QtQuick
import Quickshell.Io
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// VolumeWidget — shows master sink volume / mute state.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool hovered: false
    property bool active:  false
    signal clicked()

    // ── Volume data (wpctl) ───────────────────────────────────────────────────
    // Quickshell's Pipewire QML `audio.muted` can be stale on some setups.
    // Use `wpctl get-volume` as the ground truth.
    property bool   ready: false
    property bool   muted: false
    property double vol:   0.0
    readonly property int    pct:    Math.round(vol * 100)

    Timer {
        interval: 1200
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: wpctlProc.running = true
    }

    Process {
        id: wpctlProc
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]

        stdout: StdioCollector {
            onStreamFinished: {
                var t = this.text.trim()
                // Expected:
                //  - "Volume: 0.50"
                //  - "Volume: 0.50 [MUTED]"
                var m = t.match(/Volume:\s*([0-9.]+)/)
                if (!m || m.length < 2) {
                    root.ready = false
                    return
                }
                root.ready = true
                root.vol = Math.max(0.0, Math.min(1.25, parseFloat(m[1]) || 0.0))
                root.muted = t.indexOf("MUTED") !== -1
            }
        }

        stderr: StdioCollector {}
    }

    // ── Derived label ─────────────────────────────────────────────────────────
    readonly property string icon: {
        if (!ready || muted) return "󰝟"
        if (pct === 0)      return "󰕿"
        if (pct < 50)       return "󰖀"
        return "󰕾"
    }
    readonly property string label: !ready ? ("󰕿 --") : (muted ? (icon + " mute") : (icon + " " + pct + "%"))
    readonly property color  textColor: muted ? Theme.error
                                       : (root.active ? Theme.accent
                                       : (root.hovered ? Theme.text : Theme.textDim))

    implicitWidth:  Math.max(volText.implicitWidth + 20, 64)
    implicitHeight: BarConfig.barHeight

    // TUI-box treatment, same as TuiLauncherWidget.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius:       BarConfig.buttonRadius
        color:        root.active ? Theme.surfaceAlt : "transparent"
        border.width: 1
        border.color: root.active ? Theme.accent
                    : (root.hovered ? Theme.accent : Theme.borderSubtle)

        Text {
            id:              volText
            anchors.centerIn: parent
            text:            root.label
            color:           root.textColor
            font.pixelSize:  BarConfig.clockFontSize
            font.family:     "monospace"
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered:    root.hovered = true
        onExited:     root.hovered = false
        onClicked:    root.clicked()
    }
}
