pragma Singleton
import Quickshell

// ─────────────────────────────────────────────────────────────────────────────
// BarConfig — single source of truth for every layout size in the bar.
// Change a value here and it propagates to all components automatically.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // ── Overall geometry ─────────────────────────────────────────────────────
    property int barHeight:   22    // TUI bar strip height — one kitty row at font_size 11

    // TUI bar (BarHost: a docked kitty running `kalin-bar-tui bar`) is the
    // default since the 2026-07-17 cutover; KALIN_TUI_BAR=0 is the emergency
    // escape hatch back to the QML BottomBar.
    // String() coercion: env() hands back a QString-ish value for which a
    // strict === comparison silently evaluated false (found in the nested
    // TUI-bar gate — the loader never activated despite the env being set).
    readonly property bool useTuiBar: String(Quickshell.env("KALIN_TUI_BAR") ?? "") !== "0"
    property int panelWidth:  440   // width of the right slide-out drawer
    property int panelHeight: 520   // height of the drawer (upward from bar)

    // Docked TUI panels (DockedPanel.qml) need real terminal-cell columns/rows,
    // not just visual space — btop specifically refuses to render below 80x24
    // and prints "Terminal size too small" instead. panelWidth/panelHeight
    // above were sized for QML content and are too narrow for that (measured:
    // 440px only fit ~51 columns at foot's default font). Sized generously
    // for 80x24 at a typical monospace cell (~8x16px) plus margin.
    property int tuiPanelWidth:  700
    property int tuiPanelHeight: 480

    // ── Global spacing ────────────────────────────────────────────────────────
    property int edgePadding:    8  // margin between screen edge and bar contents
    property int buttonRadius:   2  // corner radius for all interactive buttons
                                    // (near-square: TUI-box look, matches the
                                    // screenshot UI's hard-framed panels)

    // ── Icon sizes ────────────────────────────────────────────────────────────
    property int railIconSize:  22  // SVG icon render size inside rail/task buttons

    // ── Clock button ──────────────────────────────────────────────────────────
    property real clockWidthRatio:  2.6  // clockWidth = barHeight × this
    property int  clockFontSize:    14   // time label font size
    property int  clockRightMargin:  6   // right edge margin on the bar
    readonly property int clockWidth: Math.round(barHeight * clockWidthRatio)

    // ── Workspace dots ────────────────────────────────────────────────────────
    property int workspaceDotSize:          10  // dot width & height
    property int workspaceDotRadius:         6  // dot corner radius
    property int workspaceDotSpacing:        6  // gap between dots in the row
    property int workspaceContainerPadding:  6  // background extends this far beyond dots
    property int workspaceContainerRadius:  10  // background rounded-rect radius
    property int workspaceWidgetHeight:     28  // total widget height (includes click area)

    // ── Taskbar (running/pinned app icons) ───────────────────────────────────
    // Default pinned app IDs. TaskbarService will load from
    // ~/.config/quickshell/windows-bar/taskbar-pins.json if it exists.
    property var taskbarPins: ["vivaldi-stable", "foot", "code"]

    property int taskbarButtonSpacing: 2   // horizontal gap between buttons
    property int taskbarIconSize:     22   // icon render size inside each button
    property int taskbarIndicatorH:    3   // running-indicator bar height
    property int taskbarIndicatorBM:   3   // bottom margin of the indicator from button edge
    property int taskbarIndicatorFocusW:  8  // indicator width when single window, focused
    property int taskbarIndicatorDotW:    4  // dot width when showing multiple windows
    property int taskbarFallbackFontSize: 12 // letter fallback font size
}
