import QtQuick
import Quickshell
import Quickshell.Wayland

import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// ConnectionLines — draws the kalin-wm connection graph (KalinViewport.
// connections) as dotted/sparkle lines between related windows while Super is
// held, or while native overview mode (Super+O) is open — the graph is most
// useful to see precisely when you're looking at the whole desktop at once.
// Also draws the live rubber-band line for a menu-armed pending
// connect (KalinViewport.pendingConnect, Super+L / WindowActions.qml's
// "Link" button) from the armed source window to the current cursor
// position — same dotted/sparkle rendering, just one more edge whose second
// "rect" is a zero-size point at the cursor (LineGeometry.hitPoints()'s edge-
// anchor math degenerates to that point for a zero-width/height rect, so no
// changes were needed there).
//
// Each connection is one undirected edge between two windows (each window
// can have up to 8, one per compass direction — see enum Octant in
// kalin.h). Drawn as a string of twinkling star/dot glyphs along the
// segment between the two windows' near edges, each inset toward its
// window's center (not sitting exactly on the boundary, and not running all
// the way to the center either) — visible as clearly belonging to that
// window even when it's slightly overlapped by a neighbor, instead of
// getting squeezed into whatever sliver of shared boundary happens to be
// between two close/overlapping windows.
//
// Purely decorative — like WindowActions' hold-Super menu, a per-screen
// full-bleed transparent overlay with an EMPTY input mask, always fully
// click-through. Click-to-sever is handled entirely by the compositor
// (dwl.c's connection_click_hit(), next to buttonpress()), not here: a
// partial (line-shaped) wlr-layer-shell input region turned out to never
// actually receive clicks on this wlroots/Quickshell combination — only a
// mask covering the *entire* output worked, which isn't usable here since it
// would swallow every Super-held click anywhere on screen (Wayland input
// doesn't fall through once a client's own region claims the pixel), breaking
// normal Super+drag. The compositor already has the same graph and camera
// transform for the IPC broadcast, so it does the hit-test itself; this file
// only needs to draw.
// ─────────────────────────────────────────────────────────────────────────────
Variants {
    model: Quickshell.screens

    Scope {
        id: scope
        required property ShellScreen modelData

        PanelWindow {
            id: overlay
            screen: scope.modelData
            visible: (KalinViewport.superHeld || KalinViewport.overviewActive)
                && (KalinViewport.connections.length > 0 || KalinViewport.pendingConnect)
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "windows-bar:connection-lines"
            mask: Region {}

            // Shared twinkle phase driving every sparkle's opacity — one
            // ticking value instead of a Timer/Animation per dot.
            property real twinklePhase: 0
            NumberAnimation on twinklePhase {
                from: 0; to: Math.PI * 2
                duration: 2200
                loops: Animation.Infinite
                running: overlay.visible
            }

            Repeater {
                model: KalinViewport.connections

                delegate: Item {
                    id: lineItem
                    required property var modelData
                    anchors.fill: parent

                    readonly property var linePts:
                        LineGeometry.hitPoints(modelData.aRect, modelData.bRect)

                    Repeater {
                        model: lineItem.linePts
                        delegate: Text {
                            required property var modelData
                            required property int index
                            // Every 3rd point gets a bigger sparkle glyph;
                            // the rest are small dots — reads as a dotted
                            // line with the occasional twinkling star.
                            readonly property bool big: index % 3 === 0
                            text: big ? "✦" : "•"
                            font.pixelSize: big ? 20 : 14
                            color: big ? Theme.accentPurple : Theme.accent
                            x: modelData.x - implicitWidth / 2
                            y: modelData.y - implicitHeight / 2
                            opacity: 0.35 + 0.55 * Math.abs(Math.sin(overlay.twinklePhase + index * 0.7))
                        }
                    }
                }
            }

            // Pending connect's rubber-band: same dotted/sparkle look as a
            // real connection, one line, no Repeater-of-Repeaters needed.
            Repeater {
                model: KalinViewport.pendingConnect
                    ? LineGeometry.hitPoints(KalinViewport.pendingRect,
                        Qt.rect(KalinViewport.pendingCursor.x, KalinViewport.pendingCursor.y, 0, 0))
                    : []
                delegate: Text {
                    required property var modelData
                    required property int index
                    readonly property bool big: index % 3 === 0
                    text: big ? "✦" : "•"
                    font.pixelSize: big ? 20 : 14
                    color: big ? Theme.accentPurple : Theme.accent
                    x: modelData.x - implicitWidth / 2
                    y: modelData.y - implicitHeight / 2
                    opacity: 0.35 + 0.55 * Math.abs(Math.sin(overlay.twinklePhase + index * 0.7))
                }
            }
        }
    }
}
