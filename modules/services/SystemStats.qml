pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// ─────────────────────────────────────────────────────────────────────────────
// SystemStats — low-overhead CPU / RAM / GPU usage feed for the bar.
// Spawns a one-shot Python helper every 2 s. Avoids persistent polling loops.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property real cpu: 0
    property real ram: 0
    property real gpu: 0
    property string gpuName: ""
    property bool ready: false

    // Resolve the helper script next to this QML file.
    readonly property string scriptPath:
        Qt.resolvedUrl("SystemStats.py").toString().replace("file://", "")

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: statsProc.running = true
    }

    Process {
        id: statsProc
        command: ["python3", root.scriptPath]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    root.cpu = data.cpu ?? 0
                    root.ram = data.ram ?? 0
                    root.gpu = data.gpu ?? 0
                    root.gpuName = data.gpuName ?? ""
                    root.ready = true
                } catch (_) {
                    // ignore malformed output
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("SystemStats:", msg)
            }
        }
    }
}
