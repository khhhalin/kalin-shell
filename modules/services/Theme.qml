pragma Singleton
import QtQuick
import Quickshell

// ─────────────────────────────────────────────────────────────────────────────
// Theme — single source of truth for colors (companion to BarConfig, which owns
// sizes). Values are seeded from the palette already used across the shell so
// migrating a hardcoded hex to the matching token is a no-op visually.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // ── Surfaces ─────────────────────────────────────────────────────────────
    property color bar:          "#1f1f1f"  // bottom bar / main panel background
    property color surface:      "#2a2a2a"  // elevated surface, dividers
    property color surfaceAlt:   "#252525"  // hovered button background
    property color surfaceActive:"#2f2f2f"  // active/focused button background
    property color overlayDim:   "#cc101014" // full-screen overlay backdrop (overview)
    property color scrim:        "#dd1f1f1f" // OSD / tooltip background

    // ── Borders ──────────────────────────────────────────────────────────────
    property color border:       "#3a3a3a"
    property color borderSubtle:  "#2a2a2a"

    // ── Text ─────────────────────────────────────────────────────────────────
    property color textBright:   "#f0f0f0"
    property color text:         "#e6e6e6"  // primary
    property color textDim:      "#cccccc"
    property color textSecondary:"#888888"
    property color textMuted:    "#555555"

    // ── Accents ──────────────────────────────────────────────────────────────
    property color accent:       "#4fc3f7"  // primary accent (cyan)
    property color accentBlue:    "#4a9eff"
    property color accentGreen:   "#4ade80"
    property color accentPurple:  "#a78bfa"

    // ── Status ───────────────────────────────────────────────────────────────
    property color error:        "#ff6b6b"
    property color warning:       "#ffaa44"
    property color success:       "#4ade80"

    // ── Helpers ──────────────────────────────────────────────────────────────
    // Translucent accent for highlights/selection backgrounds.
    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
    readonly property color accentSoft: withAlpha(accent, 0.18)
    readonly property color focusRing:  "#4f7fff"
}
