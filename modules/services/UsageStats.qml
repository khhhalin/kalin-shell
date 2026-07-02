pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Tracks launcher usage to bias search ordering toward frequently used entries.
Singleton {
    id: root

    // key -> count
    property var counts: ({})
    property bool ready: false

    function _keyFor(entry): string {
        if (!entry) return ""
        const desktopId = String(entry.desktopId ?? "").trim()
        if (desktopId.length) return "app:" + desktopId
        const exec = String(entry.exec ?? "").trim()
        if (exec.length) return "exec:" + exec
        const name = String(entry.name ?? "").trim()
        if (name.length) return "name:" + name
        return ""
    }

    function score(entry): int {
        const key = _keyFor(entry)
        if (!key.length) return 0
        const val = root.counts[key]
        return (typeof val === "number" && isFinite(val)) ? Math.max(0, Math.floor(val)) : 0
    }

    function bump(entry): void {
        const key = _keyFor(entry)
        if (!key.length) return
        const current = root.counts[key]
        const next = (typeof current === "number" && isFinite(current)) ? current + 1 : 1
        root.counts[key] = next
        _save()
    }

    Component.onCompleted: _load()

    Process {
        id: loadProc
        command: ["sh", "-c",
            "cat ~/.config/quickshell/windows-bar/launcher-usage.json 2>/dev/null || echo '{}'"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(this.text.trim())
                    if (obj && typeof obj === "object") root.counts = obj
                } catch (_) {
                    root.counts = {}
                }
                root.ready = true
            }
        }
        stderr: StdioCollector {}
    }

    Process {
        id: saveProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("UsageStats: save:", msg)
            }
        }
    }

    function _load(): void { loadProc.running = true }

    function _save(): void {
        const json = JSON.stringify(root.counts)
        saveProc.command = ["sh", "-c",
            "mkdir -p ~/.config/quickshell/windows-bar && " +
            "printf '%s' '" + json + "' > ~/.config/quickshell/windows-bar/launcher-usage.json"
        ]
        saveProc.running = true
    }
}
