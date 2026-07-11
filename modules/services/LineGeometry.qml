pragma Singleton

import QtQuick
import Quickshell

// ─────────────────────────────────────────────────────────────────────────────
// LineGeometry — pure helper for ConnectionLines: turns two window rects into
// a string of evenly-spaced points running edge-to-edge between them (not
// center-to-center, so the line doesn't run under the window content).
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root
    // Matches the compositor's CONN_HIT_RADIUS_PX (dwl.c) closely enough that
    // the drawn dots visually cover the actual clickable strip along the
    // line, not just a sparse subset of it.
    readonly property real spacing: 14 // px between points along the line

    // Anchor point on `rect`'s boundary closest to `other`'s center, picking
    // whichever edge (left/right/top/bottom) the direction to `other` points
    // through most strongly — gives a clean edge-to-edge connector instead of
    // a line that visibly cuts across both windows.
    function _edgeAnchor(rect, other) {
        const cx = rect.x + rect.width / 2
        const cy = rect.y + rect.height / 2
        const ocx = other.x + other.width / 2
        const ocy = other.y + other.height / 2
        const dx = ocx - cx
        const dy = ocy - cy
        if (Math.abs(dx) > Math.abs(dy)) {
            return { x: dx > 0 ? rect.x + rect.width : rect.x, y: cy }
        }
        return { x: cx, y: dy > 0 ? rect.y + rect.height : rect.y }
    }

    function hitPoints(rectA, rectB) {
        const p1 = _edgeAnchor(rectA, rectB)
        const p2 = _edgeAnchor(rectB, rectA)
        const dx = p2.x - p1.x
        const dy = p2.y - p1.y
        const len = Math.sqrt(dx * dx + dy * dy)
        if (len < 1) return [p1]

        const n = Math.max(1, Math.round(len / spacing))
        const pts = []
        for (let i = 0; i <= n; i++) {
            const t = i / n
            pts.push({ x: p1.x + dx * t, y: p1.y + dy * t })
        }
        return pts
    }
}
