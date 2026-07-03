pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var events: []
    property string error: ""
    property bool ready: false

    readonly property string scriptPath:
        Qt.resolvedUrl("CalendarService.py").toString().replace("file://", "")

    function refresh(year, month) {
        root.ready = false
        root.error = ""
        fetchProc.command = ["python3", root.scriptPath, "fetch", String(year), String(month)]
        fetchProc.running = true
    }

    function addEvent(text) {
        root.error = ""
        addProc.command = ["python3", root.scriptPath, "add", text]
        addProc.running = true
    }

    Process {
        id: fetchProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    if (data.error) {
                        root.error = data.error
                    } else {
                        root.events = data.events ?? []
                    }
                } catch (_) {
                    root.error = "Failed to parse calendar data"
                }
                root.ready = true
            }
        }
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("CalendarService:", msg)
            }
        }
    }

    Process {
        id: addProc
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    if (data.error) {
                        root.error = data.error
                    } else {
                        const now = new Date()
                        root.refresh(now.getFullYear(), now.getMonth() + 1)
                    }
                } catch (_) {
                    root.error = "Failed to add event"
                }
            }
        }
    }
}
