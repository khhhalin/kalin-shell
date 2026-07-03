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
//      this overlay is purely informational, not clickable.
//   2. Exit prompt: when quit() is armed (first Super+Escape), flash
//      "Press Esc again to quit" so the double-press confirmation is visible.
// ─────────────────────────────────────────────────────────────────────────────
Variants {
    model: Quickshell.screens

    Scope {
        id: scope
        required property ShellScreen modelData

        // Window actions and the keys that trigger them (see code/config/config.h).
        readonly property var actions: [
            { glyph: "✕",  key: "Q",       label: "Close" },
            { glyph: "⛶",  key: "E",       label: "Fullscreen" },
            // Toggles with the focused window's state: re-tile a floating window
            // or float a tiled one (both Super+Shift+Space).
            KalinViewport.focusedFloating
                ? { glyph: "▦",  key: "⇧Space", label: "Tile" }
                : { glyph: "❒",  key: "⇧Space", label: "Float" },
            { glyph: "◳",  key: "C",       label: "Crop" },
            { glyph: "↔",  key: "Ctrl←→",  label: "Move" },
        ]

        readonly property bool hasFocused:
            KalinViewport.focusedAppId.length > 0 || KalinViewport.focusedTitle.length > 0

        // Debounce: only raise the menu after Super has been held briefly, so a
        // quick Super+<key> chord doesn't flash it.
        Timer {
            id: holdTimer
            interval: 180
            repeat: false
            onTriggered: {
                if (KalinViewport.superHeld && scope.hasFocused) {
                    menu.shown = true
                    // Spotlight the active window (camera focus + dim rest);
                    // driven here so it fires only on a real hold, not a chord.
                    KalinViewport.spotlight(true)
                }
            }
        }

        Connections {
            target: KalinViewport
            function onStateChanged() {
                if (KalinViewport.superHeld) {
                    if (!menu.shown) holdTimer.restart()
                } else {
                    holdTimer.stop()
                    if (menu.shown)
                        KalinViewport.spotlight(false)
                    menu.shown = false
                }
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
                // (fall back to a bit right of screen centre).
                readonly property rect win: KalinViewport.focusedRect
                readonly property bool haveWin: win.width > 0 && win.height > 0
                readonly property real edgeX: haveWin ? win.x + win.width : width * 0.62
                readonly property real midY: haveWin ? win.y + win.height / 2 : height / 2
                readonly property real vGap: 96      // vertical spacing between buttons
                readonly property real outX: 64      // gap from the window edge
                readonly property real bulge: 40     // how far the middle buttons bow out

                Repeater {
                    model: scope.actions
                    delegate: Item {
                        id: node
                        required property int index
                        required property var modelData

                        readonly property int n: scope.actions.length
                        readonly property real row: index - (n - 1) / 2.0
                        readonly property real half: Math.max(1, (n - 1) / 2.0)
                        // Parabolic bow so the column curves out to the right.
                        readonly property real bow:
                            radial.bulge * (1 - (row / half) * (row / half))
                        readonly property real targetX: radial.edgeX + radial.outX + bow
                        readonly property real ty: radial.midY + row * radial.vGap

                        width: 220; height: 72
                        // Fly out horizontally from the window edge; vertical fixed.
                        x: radial.edgeX + (targetX - radial.edgeX) * radial.expand
                        y: ty - height / 2
                        opacity: radial.expand

                        Row {
                            spacing: 12
                            Rectangle {
                                width: 60; height: 60; radius: 30
                                anchors.verticalCenter: parent.verticalCenter
                                color: Theme.surfaceActive
                                border.color: Theme.accent
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: node.modelData.glyph
                                    color: Theme.accent
                                    font.pixelSize: 22
                                    font.bold: true
                                }
                            }
                            Column {
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 2
                                Text {
                                    text: node.modelData.label
                                    color: Theme.textBright
                                    font.pixelSize: 14
                                    font.bold: true
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
