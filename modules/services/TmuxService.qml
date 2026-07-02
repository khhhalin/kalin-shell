pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string sessionName: "apps"
    property var windows: [] // [{ index: int, name: string, active: bool }]

    function _shQuote(s): string {
        const str = String(s ?? "")
        return "'" + str.replace(/'/g, "'\"'\"'") + "'"
    }

    function ensureSession(): void {
        ensureProc.running = true
    }

    function refresh(): void {
        listProc.running = true
    }

    function launch(appName, commandLine): void {
        const name = String(appName ?? "").trim()
        const cmd = String(commandLine ?? "").trim()
        if (!name.length || !cmd.length) return

        // Create (if needed) a single session, then one window per app.
        // Window will close when the command exits (tmux default).
        const script =
            "tmux start-server 2>/dev/null || true; " +
            "tmux has-session -t " + _shQuote(root.sessionName) + " 2>/dev/null || " +
            "tmux new-session -d -s " + _shQuote(root.sessionName) + " -n " + _shQuote(root.sessionName) + "; " +
            "tmux set-window-option -t " + _shQuote(root.sessionName) + " remain-on-exit on; " +
            "tmux new-window -d -t " + _shQuote(root.sessionName + ":") + " -n " + _shQuote(name) + " -- bash -lc " + _shQuote(cmd)

        launchProc.command = ["sh", "-lc", script]
        launchProc.running = true
    }

    function attachWindow(windowIndex): void {
        const idx = Number(windowIndex)
        if (!Number.isFinite(idx)) return

        const target = root.sessionName + ":" + String(idx)
        const script =
            "tmux start-server 2>/dev/null || true; " +
            "tmux has-session -t " + _shQuote(root.sessionName) + " 2>/dev/null || " +
            "tmux new-session -d -s " + _shQuote(root.sessionName) + " -n " + _shQuote(root.sessionName) + "; " +
            "exec foot -e tmux attach -t " + _shQuote(target)

        attachProc.command = ["sh", "-lc", script]
        attachProc.running = true
    }

    function killWindow(windowIndex): void {
        const idx = Number(windowIndex)
        if (!Number.isFinite(idx)) return

        const target = root.sessionName + ":" + String(idx)
        const script =
            "tmux has-session -t " + _shQuote(root.sessionName) + " 2>/dev/null || exit 0; " +
            "tmux kill-window -t " + _shQuote(target) + " 2>/dev/null || true"

        killProc.command = ["sh", "-lc", script]
        killProc.running = true
    }

    Process {
        id: ensureProc
        command: ["sh", "-lc",
            "tmux start-server 2>/dev/null || true; " +
            "tmux has-session -t '" + root.sessionName + "' 2>/dev/null || tmux new-session -d -s '" + root.sessionName + "' -n '" + root.sessionName + "'"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
    }

    Process {
        id: listProc
        stdout: StdioCollector {
            onStreamFinished: {
                const text = String(this.text || "").trim()
                if (!text.length) {
                    root.windows = []
                    return
                }

                const out = []
                const lines = text.split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const line = lines[i]
                    if (!line) continue
                    const parts = line.split("\t")
                    if (parts.length < 3) continue
                    const idx = parseInt(parts[0])
                    const nm = parts[1]
                    const active = parts[2] === "1"
                    if (nm === root.sessionName) continue
                    out.push({ index: idx, name: nm, active })
                }
                root.windows = out
            }
        }
        stderr: StdioCollector {}

        // Don't error if the session doesn't exist; just return an empty list.
        command: ["sh", "-lc",
            "tmux has-session -t '" + root.sessionName + "' 2>/dev/null || exit 0; " +
            "tmux list-windows -t '" + root.sessionName + "' -F '#{window_index}\t#{window_name}\t#{?window_active,1,0}'"]
    }

    Process {
        id: launchProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = String(this.text || "").trim()
                if (msg.length) console.warn("windows-bar:TmuxService:", msg)
            }
        }
        onExited: Qt.callLater(function() { root.refresh() })
    }

    Process {
        id: attachProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = String(this.text || "").trim()
                if (msg.length) console.warn("windows-bar:TmuxService(attach):", msg)
            }
        }
    }

    Process {
        id: killProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = String(this.text || "").trim()
                if (msg.length) console.warn("windows-bar:TmuxService(kill):", msg)
            }
        }
        onExited: Qt.callLater(function() { root.refresh() })
    }
}
