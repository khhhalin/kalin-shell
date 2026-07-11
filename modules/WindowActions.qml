import QtQuick
import Quickshell
import Quickshell.Wayland

import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// WindowActions — two transient, keyboard-focus-free overlays driven by the
// kalin-wm IPC state (KalinViewport), so both are inert on niri:
//
//   1. Hold-Super menu: while the Super key is held and a window is focused,
//      show that window's available actions with their key hints. The user
//      presses the key (still holding Super) to invoke the compositor keybind;
//      this overlay is purely informational, not clickable — an empty input
//      mask (see `menu.mask` below) is load-bearing here, not incidental:
//      Super is also the window-drag modifier, and a real click-through
//      region big enough to cover clickable buttons would swallow those drags.
//   2. Exit prompt: when quit() is armed (first Super+Escape), flash
//      "Press Esc again to quit" so the double-press confirmation is visible.
//
// Layout: normally an Android-style arc flowing out of the focused window's
// right edge (see `radial` below). A window spanning (close to) the full
// screen width has no room to its right for that, so past a width threshold
// the menu switches to a side dock pinned to the screen's right edge instead
// (`radial.dockMode`) — same buttons, same on/off states, just anchored to
// the screen rather than the window.
// ─────────────────────────────────────────────────────────────────────────────
Variants {
    model: Quickshell.screens

    Scope {
        id: scope
        required property ShellScreen modelData

        // Window actions and the keys that trigger them (see
        // code/config/default_binds.h). `state` is null for a plain
        // momentary action, or a bool for a toggle whose on/off is shown via
        // the button's fill/border (see the delegate below).
        readonly property var actions: [
            { glyph: "✕", key: "Q",      label: "Close",   state: null },
            { glyph: "⛶", key: "E",      label: "Fullscreen", state: KalinViewport.focusedFullscreen },
            { glyph: "◳", key: "C",      label: "Crop",    state: KalinViewport.cropActive },
            { glyph: "⧉", key: "⇧O",     label: "Overlap", state: KalinViewport.focusedOverlap },
            { glyph: "⇄", key: "Ctrl←→", label: "Swap",    state: null },
            { glyph: "⛓", key: "L",      label: "Link",    state: KalinViewport.pendingConnect },
        ]

        readonly property bool hasFocused:
            KalinViewport.focusedAppId.length > 0 || KalinViewport.focusedTitle.length > 0

        // The compositor's bind engine owns the hold timing now: it raises the
        // menu after a 1s uninterrupted hold of Super (see `hold Super` in
        // binds.conf) and broadcasts `menu`. We just mirror that flag; no camera
        // spotlight (it snapped the view around) — the menu appears in place.
        Connections {
            target: KalinViewport
            function onStateChanged() {
                menu.shown = KalinViewport.menuShown && scope.hasFocused
                // Exit prompt: flash on the rising edge of exit_pending.
                if (KalinViewport.exitPending && !scope.lastExitPending)
                    exit.flash()
                scope.lastExitPending = KalinViewport.exitPending
            }
        }
        property bool lastExitPending: false

        // ── Hold-Super window-actions menu ───────────────────────────────────
        PanelWindow {
            id: menu
            screen: scope.modelData
            property bool shown: false
            // Include `shown` directly: the window must be visible for the
            // radial fly-out animation to tick (otherwise expand never leaves 0).
            visible: shown || radial.expand > 0.01
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "windows-bar:window-actions"
            /* Purely informational + shown while Super is held (which is also the
             * window-drag modifier), so it must be click-through: an empty input
             * mask passes pointer events to the windows below. */
            mask: Region {}

            // Android-style side menu: round action buttons flow out from the
            // right edge of the focused window in a gently-curved vertical arc.
            // `expand` (0..1) drives the horizontal fly-out and fade.
            Item {
                id: radial
                anchors.fill: parent

                property real expand: menu.shown ? 1 : 0
                Behavior on expand {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                }

                // Anchor to the right edge of the focused window's on-screen rect
                // (fall back to a bit right of screen centre) — unless the window
                // is (close to) full screen width, in which case there's no room
                // to its right for the fly-out arc, so dock to the screen edge
                // instead (see the header comment).
                readonly property rect win: KalinViewport.focusedRect
                readonly property bool haveWin: win.width > 0 && win.height > 0
                readonly property real fullWidthThreshold: 0.85
                readonly property bool dockMode:
                    haveWin && win.width >= width * fullWidthThreshold
                readonly property real dockInset: 240 // dock column's distance from the right screen edge
                readonly property real edgeX:
                    dockMode ? (width - dockInset)
                             : (haveWin ? win.x + win.width : width * 0.62)
                readonly property real midY: haveWin ? win.y + win.height / 2 : height / 2
                readonly property real vGap: 96      // vertical spacing between buttons
                readonly property real outX: 64      // gap from the window edge (non-dock mode)
                readonly property real bulge: 40     // how far the middle buttons bow out (non-dock mode)
                // In dock mode the buttons fly straight in from off-screen at the
                // right edge rather than bowing out from a window edge.
                readonly property real flyFromX: dockMode ? width : edgeX

                Repeater {
                    model: scope.actions
                    delegate: Item {
                        id: node
                        required property int index
                        required property var modelData

                        readonly property int n: scope.actions.length
                        readonly property real row: index - (n - 1) / 2.0
                        readonly property real half: Math.max(1, (n - 1) / 2.0)
                        // Parabolic bow so the column curves out to the right —
                        // only in the window-relative arc layout; a docked column
                        // is a straight vertical stack.
                        readonly property real bow:
                            radial.dockMode ? 0
                                : radial.bulge * (1 - (row / half) * (row / half))
                        readonly property real targetX: radial.edgeX + radial.outX + bow
                        readonly property real ty: radial.midY + row * radial.vGap

                        // A toggle button (state !== null) gets a filled,
                        // brighter treatment when on; a momentary action (state
                        // === null) always uses the neutral/off look.
                        readonly property bool isOn: node.modelData.state === true

                        width: 220; height: 72
                        // Fly out horizontally toward the target; vertical fixed.
                        x: radial.flyFromX + (targetX - radial.flyFromX) * radial.expand
                        y: ty - height / 2
                        opacity: radial.expand

                        Row {
                            spacing: 12
                            Rectangle {
                                width: 60; height: 60; radius: 30
                                anchors.verticalCenter: parent.verticalCenter
                                color: node.isOn ? Theme.accent : Theme.surfaceActive
                                border.color: node.isOn ? Theme.textBright : Theme.accent
                                border.width: node.isOn ? 2 : 1
                                Text {
                                    anchors.centerIn: parent
                                    text: node.modelData.glyph
                                    color: node.isOn ? Theme.bar : Theme.accent
                                    font.pixelSize: 22
                                    font.bold: true
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Row {
                                    spacing: 6
                                    Text {
                                        text: node.modelData.label
                                        color: Theme.textBright
                                        font.pixelSize: 14
                                        font.bold: true
                                    }
                                    // On/off indicator dot for toggle buttons only.
                                    Rectangle {
                                        visible: node.modelData.state !== null
                                        width: 8; height: 8; radius: 4
                                        anchors.verticalCenter: parent.verticalCenter
                                        color: node.isOn ? Theme.success : Theme.textMuted
                                    }
                                }
                                Text {
                                    text: node.modelData.key
                                    color: Theme.textSecondary
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── "Press Esc again to quit" prompt ─────────────────────────────────
        PanelWindow {
            id: exit
            screen: scope.modelData
            visible: exitCard.opacity > 0.01
            color: "transparent"

            anchors { top: true }
            margins.top: 120
            implicitWidth: 320
            implicitHeight: 64

            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "windows-bar:exit-prompt"

            function flash(): void {
                exitCard.opacity = 1
                exitTimer.restart()
            }

            Rectangle {
                id: exitCard
                anchors.centerIn: parent
                width: exitText.implicitWidth + 36
                height: 44
                radius: 12
                color: Theme.scrim
                border.color: Theme.warning
                border.width: 1
                opacity: 0
                Behavior on opacity { NumberAnimation { duration: 160 } }

                Text {
                    id: exitText
                    anchors.centerIn: parent
                    text: "Press Esc again to quit"
                    color: Theme.textBright
                    font.pixelSize: 15
                    font.bold: true
                }
            }

            // Match EXIT_CONFIRMATION_SECONDS (2s) in the compositor.
            Timer {
                id: exitTimer
                interval: 2000
                repeat: false
                onTriggered: exitCard.opacity = 0
            }
        }
    }
}
