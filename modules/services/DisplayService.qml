pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

import "."

// ─────────────────────────────────────────────────────────────────────────────
// DisplayService — queries and controls outputs under niri.
//
// Features:
//   - Reorder displays left-to-right via `niri msg output position`.
//   - Per-display brightness slider (via brightnessctl) for internal panels.
//   - Resolution/mode cycling via `niri msg output mode`.
//   - Scale cycling via `niri msg output scale`.
//
// On kalin-wm the service is unavailable because kalin-wm has no runtime
// output IPC yet.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    property var outputs: []
    property bool available: false
    property string unavailableReason: ""

    readonly property bool _kalin: KalinViewport.enabled

    // Internal data pending merge.
    property var _rawOutputs: []
    property var _backlights: ({})

    // Preset scales to cycle through.
    readonly property var _scales: [1, 1.25, 1.5, 1.75, 2, 2.5, 3]

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root._poll()
    }

    function _poll(): void {
        if (root._kalin) {
            root.available = false
            root.unavailableReason = "Display configuration is not available on kalin-wm yet."
            return
        }
        outputsProc.running = true
        backlightsProc.running = true
    }

    Process {
        id: outputsProc
        command: ["niri", "msg", "--json", "outputs"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const raw = JSON.parse(this.text)
                    const list = []
                    for (const name in raw) {
                        const o = raw[name]
                        const mode = (o.modes && o.current_mode !== undefined)
                                     ? o.modes[o.current_mode]
                                     : null
                        list.push({
                            name: o.name || name,
                            make: o.make || "",
                            model: o.model || "",
                            logical: o.logical || { x: 0, y: 0, width: 0, height: 0, scale: 1.0 },
                            modes: o.modes || [],
                            currentModeIndex: o.current_mode !== undefined ? o.current_mode : -1,
                            currentMode: mode,
                        })
                    }
                    root._rawOutputs = list
                    root._merge()
                } catch (e) {
                    console.error("windows-bar: failed to parse niri outputs:", e)
                    root.available = false
                    root.unavailableReason = "Failed to read niri outputs."
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: niri outputs stderr:", msg)
            }
        }

        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) {
                root.available = false
                root.unavailableReason = "niri outputs command failed."
            }
        }
    }

    Process {
        id: backlightsProc
        command: ["brightnessctl", "-m", "-l", "-c", "backlight"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const map = {}
                    const lines = this.text.trim().split("\n")
                    for (let i = 0; i < lines.length; i++) {
                        const line = lines[i].trim()
                        if (!line) continue
                        const parts = line.split(",")
                        if (parts.length < 5) continue
                        const percentStr = parts[3]
                        const percent = parseFloat(percentStr.replace("%", "")) || 0
                        map[parts[0]] = {
                            name: parts[0],
                            current: parseInt(parts[2]) || 0,
                            percent: percent / 100.0,
                            max: parseInt(parts[4]) || 0,
                        }
                    }
                    root._backlights = map
                    root._merge()
                } catch (e) {
                    console.warn("windows-bar: failed to parse brightnessctl list:", e)
                }
            }
        }

        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: brightnessctl list stderr:", msg)
            }
        }
    }

    function _merge(): void {
        const backlights = root._backlights
        const backlightNames = Object.keys(backlights)
        let backlightIndex = 0

        const list = root._rawOutputs.slice()
        for (let i = 0; i < list.length; i++) {
            const o = list[i]
            // Heuristic: internal laptop panels start with eDP/LVDS/DSI.
            const isInternal = /^(eDP|LVDS|DSI)/i.test(o.name)
            if (isInternal && backlightIndex < backlightNames.length) {
                const dev = backlightNames[backlightIndex++]
                o.brightnessDevice = dev
                o.brightness = backlights[dev].percent
                o.brightnessControllable = true
            } else {
                o.brightnessDevice = ""
                o.brightness = 0
                o.brightnessControllable = false
            }
        }

        list.sort((a, b) => a.logical.x - b.logical.x)
        root.outputs = list
        root.available = true
        root.unavailableReason = ""
    }

    // ── Reordering ─────────────────────────────────────────────────────────────

    function moveOutput(fromIndex, toIndex): void {
        if (fromIndex < 0 || fromIndex >= root.outputs.length) return
        if (toIndex < 0 || toIndex >= root.outputs.length) return
        if (fromIndex === toIndex) return

        const list = root.outputs.slice()
        const item = list.splice(fromIndex, 1)[0]
        list.splice(toIndex, 0, item)
        root.applyLayout(list)
    }

    function resetToAuto(): void {
        const list = root.outputs.slice()
        for (let i = 0; i < list.length; i++) {
            root._queue.push({ type: "position", name: list[i].name, auto: true })
        }
        root._drainQueue()
    }

    function applyLayout(newOrder): void {
        if (!newOrder) newOrder = root.outputs
        if (newOrder.length === 0) return

        let x = 0
        for (let i = 0; i < newOrder.length; i++) {
            const o = newOrder[i]
            const y = o.logical ? o.logical.y : 0
            root._queue.push({ type: "position", name: o.name, x: x, y: y })
            x += (o.logical ? o.logical.width : 0)
        }
        root.outputs = newOrder
        root._drainQueue()
    }

    // ── Brightness ─────────────────────────────────────────────────────────────

    function setBrightness(outputName, value): void {
        const output = root._findOutput(outputName)
        if (!output || !output.brightnessDevice) return
        const pct = Math.max(0, Math.min(1, value))
        root._queue.push({
            type: "brightness",
            device: output.brightnessDevice,
            percent: Math.round(pct * 100),
        })
        output.brightness = pct
        root.outputsChanged()
        root._drainQueue()
    }

    // ── Mode / resolution ──────────────────────────────────────────────────────

    function cycleMode(outputName, delta): void {
        const output = root._findOutput(outputName)
        if (!output || output.modes.length === 0) return
        const next = output.currentModeIndex + delta
        const idx = next < 0 ? output.modes.length - 1
                  : next >= output.modes.length ? 0
                  : next
        root.setMode(outputName, idx)
    }

    function setMode(outputName, modeIndex): void {
        const output = root._findOutput(outputName)
        if (!output || modeIndex < 0 || modeIndex >= output.modes.length) return
        const mode = output.modes[modeIndex]
        const refreshHz = (mode.refresh_rate / 1000.0).toFixed(3)
        const modeString = mode.width + "x" + mode.height + "@" + refreshHz
        root._queue.push({ type: "mode", name: outputName, modeString: modeString })
        output.currentModeIndex = modeIndex
        output.currentMode = mode
        root.outputsChanged()
        root._drainQueue()
    }

    // ── Scale ──────────────────────────────────────────────────────────────────

    function cycleScale(outputName, delta): void {
        const output = root._findOutput(outputName)
        if (!output) return
        const current = output.logical ? output.logical.scale : 1
        let idx = 0
        for (let i = 0; i < root._scales.length; i++) {
            if (root._scales[i] >= current) {
                idx = i
                break
            }
        }
        const next = idx + delta
        const scale = root._scales[Math.max(0, Math.min(root._scales.length - 1, next))]
        root.setScale(outputName, scale)
    }

    function setScale(outputName, scale): void {
        const output = root._findOutput(outputName)
        if (!output) return
        root._queue.push({ type: "scale", name: outputName, scale: scale })
        if (output.logical) output.logical.scale = scale
        root.outputsChanged()
        root._drainQueue()
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    function _findOutput(name): var {
        for (let i = 0; i < root.outputs.length; i++) {
            if (root.outputs[i].name === name) return root.outputs[i]
        }
        return null
    }

    // ── Command queue (sequential, so hardware/compositor sees one at a time) ──

    property var _queue: []

    Process {
        id: applyProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("windows-bar: display apply stderr:", msg)
            }
        }
        onExited: function(exitCode, exitStatus) {
            if (exitCode !== 0) console.warn("windows-bar: display apply command failed")
            root._drainQueue()
        }
    }

    function _drainQueue(): void {
        if (applyProc.running) return
        if (root._queue.length === 0) return
        const item = root._queue.shift()
        switch (item.type) {
        case "position":
            if (item.auto) {
                applyProc.command = ["niri", "msg", "output", item.name, "position", "auto"]
            } else {
                applyProc.command = ["niri", "msg", "output", item.name, "position", "set",
                                     String(item.x), String(item.y)]
            }
            break
        case "brightness":
            applyProc.command = ["brightnessctl", "-d", item.device, "s", item.percent + "%"]
            break
        case "mode":
            applyProc.command = ["niri", "msg", "output", item.name, "mode", item.modeString]
            break
        case "scale":
            applyProc.command = ["niri", "msg", "output", item.name, "scale", String(item.scale)]
            break
        }
        applyProc.running = true
    }
}
