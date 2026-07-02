pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Normalized workspace objects:
    // { id:number, idx:number, name:string|null, output:string, isActive:bool, isFocused:bool, isUrgent:bool, activeWindowId:number|null }
    property var workspaces: []

    // All open windows: { id, title, appId, pid, workspaceId, isFocused }
    property var windows: []

    // Raw focused window object from niri (may be null)
    property var focusedWindow: null

    property bool available: false

    signal updated()

    // Only poll niri when we're actually running under niri. On kalin-wm
    // ($KALIN_IPC_SOCKET set) this stays idle so we don't spawn `niri msg`
    // processes every second and spam the log with "NIRI_SOCKET is not set".
    Timer {
        interval: 1000
        running: !KalinViewport.enabled
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            workspacesProc.running = true
            focusedWindowProc.running = true
            windowsProc.running = true
        }
    }

    Process {
        id: workspacesProc
        command: ["niri", "msg", "--json", "workspaces"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(this.text)
                    if (!Array.isArray(raw)) {
                        root.available = false
                        return
                    }

                    root.available = true
                    root.workspaces = raw.map(ws => ({
                        id: ws.id,
                        idx: ws.idx,
                        name: ws.name,
                        output: ws.output,
                        isUrgent: !!ws.is_urgent,
                        isActive: !!ws.is_active,
                        isFocused: !!ws.is_focused,
                        activeWindowId: ws.active_window_id,
                    })).sort((a, b) => a.idx - b.idx)

                    root.updated()
                } catch (e) {
                    console.error("windows-bar: failed to parse niri workspaces:", e)
                    root.available = false
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: niri workspaces stderr:", msg)
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) root.available = false
        }
    }

    Process {
        id: focusedWindowProc
        command: ["niri", "msg", "--json", "focused-window"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const obj = JSON.parse(this.text)
                    root.available = true
                    root.focusedWindow = obj
                    root.updated()
                } catch (e) {
                    // No focused window or parse error
                    root.focusedWindow = null
                }
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.focusedWindow = null
            }
        }
    }

    Process {
        id: focusWorkspaceProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: focus-workspace stderr:", msg)
            }
        }
    }

    function focusWorkspace(reference): void {
        if (reference === null || reference === undefined) return
        focusWorkspaceProc.command = ["niri", "msg", "action", "focus-workspace", String(reference)]
        focusWorkspaceProc.running = true
    }

    // ── Window actions ────────────────────────────────────────────────────────

    Process {
        id: windowsProc
        command: ["niri", "msg", "--json", "windows"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(this.text)
                    if (!Array.isArray(raw)) return
                    root.windows = raw.map(w => ({
                        id:          w.id,
                        title:       w.title,
                        appId:       w.app_id,
                        pid:         w.pid,
                        workspaceId: w.workspace_id,
                        isFocused:   !!w.is_focused,
                    }))
                    root.updated()
                } catch (e) {
                    console.error("windows-bar: failed to parse niri windows:", e)
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: niri windows stderr:", msg)
            }
        }
    }

    Process {
        id: focusWindowProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: focus-window stderr:", msg)
            }
        }
    }

    function focusWindowById(id): void {
        focusWindowProc.command = ["niri", "msg", "action", "focus-window", "--id", String(id)]
        focusWindowProc.running = true
    }

    Process {
        id: closeWindowProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: close-window stderr:", msg)
            }
        }
    }

    function closeWindowById(id): void {
        closeWindowProc.command = ["niri", "msg", "action", "close-window", "--id", String(id)]
        closeWindowProc.running = true
    }
}
