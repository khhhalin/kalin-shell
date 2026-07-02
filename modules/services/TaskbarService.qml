pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Manages pinned app IDs and merges them with the live window list from NiriIpc
// to produce a single `items` list that TaskbarRow renders.
//
// Item shape: {
//   appId:       string,
//   isPinned:    bool,
//   isRunning:   bool,
//   isFocused:   bool,
//   windowCount: int,
//   windows:     [ {id, title, appId, isFocused} ],
//   entry:       LauncherIndex entry | null
// }
//
// Pin/unpin persists to ~/.config/quickshell/windows-bar/taskbar-pins.json.
// On first launch, BarConfig.taskbarPins is used as the default list.
Singleton {
    id: root

    // ── Pin list ──────────────────────────────────────────────────────────────
    property var pinned: BarConfig.taskbarPins.slice()

    // ── Combined items (reactive binding) ─────────────────────────────────────
    // Uses CompositorService.windows so the taskbar works on both kalin-wm and
    // niri. On niri we still sort by workspace index; kalin has no workspaces.
    readonly property var items: {
        const windows = CompositorService.windows
        const pins    = root.pinned
        const byId    = LauncherIndex.byDesktopId
        const entries = LauncherIndex.entries

        // Group windows by appId
        const groups = {}
        for (const w of windows) {
            if (!groups[w.appId]) groups[w.appId] = []
            groups[w.appId].push(w)
        }

        const result = []
        const seen   = new Set()

        // 1. Pinned apps – always shown, in pin order
        for (const appId of pins) {
            seen.add(appId)
            const wins = groups[appId] || []
            const entry = _resolveEntry(appId, byId, entries)
            result.push({
                appId,
                isPinned:    true,
                isRunning:   wins.length > 0,
                isFocused:   wins.some(w => w.isFocused),
                windowCount: wins.length,
                windows:     wins,
                entry,
            })
        }

        // 2. Running apps that are NOT pinned
        const runningAppIds = Object.keys(groups).filter(id => !seen.has(id))

        if (!CompositorService.isKalin) {
            // On niri, order by workspace index, then by first window id.
            const workspaceIdx = {}
            for (const ws of NiriIpc.workspaces) workspaceIdx[ws.id] = ws.idx
            runningAppIds.sort((a, b) => {
                const aWins = groups[a], bWins = groups[b]
                const aMinWs = Math.min(...aWins.map(w => workspaceIdx[w.workspaceId] ?? Infinity))
                const bMinWs = Math.min(...bWins.map(w => workspaceIdx[w.workspaceId] ?? Infinity))
                if (aMinWs !== bMinWs) return aMinWs - bMinWs
                const aMinId = Math.min(...aWins.map(w => w.id))
                const bMinId = Math.min(...bWins.map(w => w.id))
                return aMinId - bMinId
            })
        }

        for (const appId of runningAppIds) {
            const wins = groups[appId]
            const entry = _resolveEntry(appId, byId, entries)
            result.push({
                appId,
                isPinned:    false,
                isRunning:   true,
                isFocused:   wins.some(w => w.isFocused),
                windowCount: wins.length,
                windows:     wins,
                entry,
            })
        }

        return result
    }

    // ── Pin helpers ───────────────────────────────────────────────────────────
    function isPinned(appId): bool {
        return pinned.indexOf(appId) >= 0
    }

    function pin(appId): void {
        if (isPinned(appId)) return
        root.pinned = root.pinned.concat([appId])
        _savePins()
    }

    function unpin(appId): void {
        root.pinned = root.pinned.filter(id => id !== appId)
        _savePins()
    }

    function togglePin(appId): void {
        if (isPinned(appId)) unpin(appId)
        else                 pin(appId)
    }

    // ── Window actions ────────────────────────────────────────────────────────

    // Try to resolve a launcher entry for app IDs that don't match desktop IDs
    // (e.g., VS Code might be "code" while its desktop ID is "code-url-handler").
    function _resolveEntry(appId, byId, entries): var {
        const id = String(appId || "").trim()
        if (!id.length) return null

        if (byId && byId[id]) return byId[id]
        if (!Array.isArray(entries)) return null

        const idLower = id.toLowerCase()
        // 1) Exact desktopId match by case-insensitive compare
        for (const e of entries) {
            if (!e || !e.desktopId) continue
            if (String(e.desktopId).toLowerCase() === idLower) return e
        }
        // 2) Exec starts with or equals appId (common for CLI launchers)
        for (const e of entries) {
            if (!e || !e.exec) continue
            const exec = String(e.exec).toLowerCase()
            if (exec === idLower || exec.startsWith(idLower + " ")) return e
        }
        // 3) Name matches (fallback)
        for (const e of entries) {
            if (!e || !e.name) continue
            if (String(e.name).toLowerCase() === idLower) return e
        }
        // 4) DesktopId contains appId (code → code-url-handler)
        for (const e of entries) {
            if (!e || !e.desktopId) continue
            if (String(e.desktopId).toLowerCase().indexOf(idLower) >= 0) return e
        }
        return null
    }

    // Left-click: if running focus (cycling through multiple windows), else launch.
    function focusOrLaunch(appId): void {
        const wins = CompositorService.windows.filter(w => w.appId === appId)

        if (wins.length === 0) {
            // Not running – launch via LauncherIndex entry
            const entry = _resolveEntry(appId, LauncherIndex.byDesktopId, LauncherIndex.entries)
            // Keep behavior consistent with the StartDrawer launcher: route starts into tmux.
            if (entry) {
                TmuxService.launch(entry.name, entry.exec)
                UsageStats.bump(entry)
            }
            return
        }

        if (wins.length === 1) {
            CompositorService.activate(wins[0])
            return
        }

        // Multiple windows – cycle to the next unfocused one
        const focusedIdx = wins.findIndex(w => w.isFocused)
        const nextIdx    = focusedIdx >= 0 ? (focusedIdx + 1) % wins.length : 0
        CompositorService.activate(wins[nextIdx])
    }

    // Middle-click: close every window belonging to this app.
    function closeAll(appId): void {
        for (const w of CompositorService.windows.filter(w => w.appId === appId))
            CompositorService.close(w)
    }

    // ── Pins persistence ──────────────────────────────────────────────────────
    Component.onCompleted: _loadPins()

    Process {
        id: loadPinsProc
        command: ["sh", "-c",
            "cat ~/.config/quickshell/windows-bar/taskbar-pins.json 2>/dev/null || echo null"]

        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text.trim())
                    if (Array.isArray(data)) root.pinned = data
                } catch (_) {
                    // File missing or malformed – keep BarConfig default
                }
            }
        }
    }

    function _loadPins(): void { loadPinsProc.running = true }

    Process {
        id: savePinsProc
        stdout: StdioCollector {}
        stderr: StdioCollector {
            onStreamFinished: {
                const msg = this.text.trim()
                if (msg.length) console.warn("TaskbarService: save pins:", msg)
            }
        }
    }

    function _savePins(): void {
        // App IDs are safe ASCII (no single quotes), so this is fine.
        const json = JSON.stringify(root.pinned)
        savePinsProc.command = ["sh", "-c",
            "mkdir -p ~/.config/quickshell/windows-bar && " +
            "printf '%s' '" + json + "' > ~/.config/quickshell/windows-bar/taskbar-pins.json"]
        savePinsProc.running = true
    }
}
