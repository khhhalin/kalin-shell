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
    // Warm palette: oranges/yellows/browns throughout the rice, replacing the
    // old cyan/gray scheme (see the ledger for when/why).
    // Exactly foot's background (and the screenshot UI's panel ground) so the
    // bar reads as one continuous TUI surface with the docked foot panels.
    property color bar:          "#1e1915"  // bottom bar / main panel background
    property color surface:      "#332419"  // elevated surface, dividers
    property color surfaceAlt:   "#2b1f15"  // hovered button background
    property color surfaceActive:"#3d2c1c"  // active/focused button background
    property color overlayDim:   "#cc17100a" // full-screen overlay backdrop (overview)
    property color scrim:        "#dd2b1f15" // OSD / tooltip background

    // ── Borders ──────────────────────────────────────────────────────────────
    property color border:       "#4a3625"
    property color borderSubtle: "#33261a"

    // ── Text ─────────────────────────────────────────────────────────────────
    property color textBright:   "#fff3e0"
    property color text:         "#f0ddc0"  // primary
    property color textDim:      "#d8c4a0"
    property color textSecondary:"#b08d5f"
    property color textMuted:    "#6b5642"

    // ── Accents ──────────────────────────────────────────────────────────────
    property color accent:       "#f0a030"  // primary accent (warm amber)
    property color accentBlue:    "#e8833a" // burnt orange
    property color accentGreen:   "#c9a227" // olive-gold
    property color accentPurple:  "#a8674a" // dusty rust-brown

    // ── Status ───────────────────────────────────────────────────────────────
    property color error:        "#e0552f"  // warm red-orange
    property color warning:       "#ffb347"
    property color success:       "#9aa83f" // warm gold-green

    // ── Helpers ──────────────────────────────────────────────────────────────
    // Translucent accent for highlights/selection backgrounds.
    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }
    readonly property color accentSoft: withAlpha(accent, 0.18)
    readonly property color focusRing:  "#ffcf5c"
}
