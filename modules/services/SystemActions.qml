pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    Process {
        id: proc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar:SystemActions:", msg)
            }
        }
    }

    Process {
        id: spawnProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar:spawn:", msg)
            }
        }
    }

    function run(commandList): void {
        if (!commandList || commandList.length === 0) return
        proc.command = commandList
        proc.running = true
    }

    function spawn(commandLine): void {
        const cmd = String(commandLine || "").trim()
        if (!cmd.length) return
        // Run through a shell so .desktop Exec lines work reasonably.
        spawnProc.command = ["sh", "-lc", cmd]
        spawnProc.running = true
    }

    // NOTE: These may require polkit permissions depending on your system.
    function shutdown(): void { run(["systemctl", "poweroff"]) }
    function hibernate(): void { run(["systemctl", "hibernate"]) }

    // "Logout" is environment-specific. Provide a safe default placeholder.
    // Replace with your preferred command (e.g. `loginctl terminate-session ...`).
    function logout(): void {
        run(["sh", "-c", "echo 'logout requested (wire me to your session manager)' >&2"])
    }
}
