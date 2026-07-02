pragma Singleton
import Quickshell

// ─────────────────────────────────────────────────────────────────────────────
// BarConfig — single source of truth for every layout size in the bar.
// Change a value here and it propagates to all components automatically.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    // ── Overall geometry ─────────────────────────────────────────────────────
    property int barHeight:   44    // bottom bar height; also used as rail button size
    property int panelWidth:  440   // width of the left/right slide-out drawer
    property int panelHeight: 520   // height of the drawer (upward from bar)
    property real panelFontScale: 1.0 // font scale for panel contents (edit mode)

    // ── Global spacing ────────────────────────────────────────────────────────
    property int edgePadding:    8  // left margin: screen edge → NixOS button / icon rail
    property int contentPadding: 8  // gap between icon rail and launcher/power-menu area
    property int buttonRadius:   8  // corner radius for all interactive buttons

    // ── Icon sizes ────────────────────────────────────────────────────────────
    property int railIconSize:  22  // SVG icon render size inside rail/task buttons
    property int railGlyphSize: 14  // fallback text-glyph font size in RailIconButton

    // ── Search box ────────────────────────────────────────────────────────────
    // Width is derived from panel geometry so the right edge of the search box
    // aligns exactly with the right edge of the launcher list.
    // Search box starts at: edgePadding + barHeight + edgePadding (left edge of content area)
    // Launcher list ends at: panelWidth - contentPadding (right edge of content area)
    // Therefore: width = panelWidth - contentPadding - barHeight - 2*edgePadding
    readonly property int searchBoxWidth: panelWidth - barHeight - 2 * edgePadding - contentPadding
    property int searchBoxHeight:   32  // input height
    property int searchBoxPadding:  10  // internal margin (all sides)
    property int searchBoxSpacing:   8  // gap between magnifier glyph and text input
    property int searchBoxIconSize: 14  // magnifier "⌕" glyph font size
    property int searchBoxFontSize: 13  // input & placeholder text size

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

    // ── Launcher list ─────────────────────────────────────────────────────────
    property int launcherDefaultWidth:    320  // fallback implicitWidth  (overridden by layout)
    property int launcherDefaultHeight:   360  // fallback implicitHeight (overridden by layout)
    property int launcherListMargin:       6  // inset inside the rounded container
    property int launcherContainerRadius: 10  // outer rounded-rect corner radius
    property int launcherRowHeight:       34  // height of each app/command row
    property int launcherRowGap:           2  // vertical spacing between rows
    property int launcherRowRadius:        8  // per-row corner radius
    property int launcherRowHPadding:     10  // left & right inset inside each row
    property int launcherRowSpacing:      10  // gap between icon badge and text column
    property int launcherIconSize:        22  // app/cmd icon badge width & height
    property int launcherIconRadius:       6  // icon badge corner radius
    property int launcherNameFontSize:    12  // primary (app name) text size
    property int launcherSubFontSize:     10  // secondary (exec / desktopId) text size
    property int launcherTextWidthInset:  70  // text column width = list.width − this

    // ── Power menu ────────────────────────────────────────────────────────────
    property int powerRowHeight:       54  // height of each action row
    property int powerRowGap:          12  // vertical spacing between rows
    property int powerMenuRowRadius:   10  // row corner radius
    property int powerMenuRowHPadding: 16  // left inset inside each row
    property int powerMenuRowSpacing:  14  // glyph ↔ label gap
    property int powerMenuGlyphSize:   22  // unicode power-symbol font size
    property int powerMenuLabelSize:   14  // action label font size

    // ── Taskbar (Win10-style running/pinned app icons) ─────────────────────────
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
