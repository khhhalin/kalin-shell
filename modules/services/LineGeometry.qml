pragma Singleton

import QtQuick
import Quickshell

// ─────────────────────────────────────────────────────────────────────────────
// LineGeometry — pure helper for ConnectionLines: turns two window rects into
// a string of evenly-spaced points running between them, anchored near (not
// exactly on) each window's near edge — inset toward the center so the line
// doesn't run under the window content, but also doesn't sit precisely on a
// boundary that can end up squeezed into a thin sliver when two windows are
// close together or slightly overlapping.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root
    // Matches the compositor's CONN_HIT_RADIUS_PX (dwl.c) closely enough that
    // the drawn dots visually cover the actual clickable strip along the
    // line, not just a sparse subset of it.
    readonly property real spacing: 14 // px between points along the line

    // How far in from the edge, toward the center, each anchor is pulled.
    // Clamped so it can never cross past the center (see the Math.max/min
    // below) — small windows still get a sensible anchor instead of
    // overshooting to the opposite edge.
    readonly property real edgeInset: 28

    // Anchor point near `rect`'s boundary closest to `other`'s center, picking
    // whichever edge (left/right/top/bottom) the direction to `other` points
    // through most strongly, then pulling that point in by `edgeInset` toward
    // the center — gives a clean edge-to-edge connector whose endpoint is
    // still visibly inside/near the window's own silhouette, instead of a
    // line that visibly cuts across both windows or one that hugs the exact
    // boundary (invisible against a neighbor's edge when they nearly touch).
    function _edgeAnchor(rect, other) {
        const cx = rect.x + rect.width / 2
        const cy = rect.y + rect.height / 2
        const ocx = other.x + other.width / 2
        const ocy = other.y + other.height / 2
        const dx = ocx - cx
        const dy = ocy - cy
        if (Math.abs(dx) > Math.abs(dy)) {
            const edgeX = dx > 0 ? rect.x + rect.width : rect.x
            const x = dx > 0 ? Math.max(cx, edgeX - root.edgeInset)
                              : Math.min(cx, edgeX + root.edgeInset)
            return { x, y: cy }
        }
        const edgeY = dy > 0 ? rect.y + rect.height : rect.y
        const y = dy > 0 ? Math.max(cy, edgeY - root.edgeInset)
                          : Math.min(cy, edgeY + root.edgeInset)
        return { x: cx, y }
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
