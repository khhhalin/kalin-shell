pragma Singleton

import Quickshell

// Shared visibility for the exposé/overview overlay. Toggled from a compositor
// keybind via:  qs ipc call windows-bar toggleOverview
Singleton {
    id: root
    property bool visible: false
    function toggle(): void { root.visible = !root.visible }
    function show(): void { root.visible = true }
    function hide(): void { root.visible = false }

    // How often each Overview/WindowPeek thumbnail tile requests a fresh
    // ScreencopyView frame. NOT `live: true` (continuous, one buffer
    // negotiation per compositor frame per tile) — with several windows
    // open at once that's many concurrent per-frame dmabuf negotiations,
    // and on this hardware/driver combo those negotiations were observed
    // reliably failing ("Unable to create dmabuf for request: No matching
    // formats") and falling back to SHM on *every single attempt* — a
    // continuous allocate-fail-fallback churn (visible as repeating bursts
    // in quickshell's own per-instance logs, one burst per open tile, every
    // frame) that wastes memory/CPU without bound for as long as the
    // overlay stays open, and lines up with this bar's recurring crashes
    // far better than raw memory volume does. A periodic one-shot
    // captureFrame() keeps thumbnails reasonably fresh at a small fraction
    // of the allocation rate. Tune down if thumbnails feel stale, but don't
    // go back to continuous `live` for every tile at once.
    property int thumbnailRefreshMs: 2000
}
