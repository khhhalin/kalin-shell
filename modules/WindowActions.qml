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

            // Android-style radial: round action buttons fan out along an arch
            // above a small hub when Super is held; they retract into the hub on
            // release. `expand` (0..1) drives both the fly-out radius and fade.
            Item {
                id: radial
                anchors.fill: parent

                property real expand: menu.shown ? 1 : 0
                Behavior on expand {
                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
                }

                // Anchor the radial to the focused window's on-screen rect so the
                // buttons flow out of the window itself; fall back to screen center.
                readonly property rect win: KalinViewport.focusedRect
                readonly property bool haveWin: win.width > 0 && win.height > 0
                readonly property real cx: haveWin ? win.x + win.width / 2 : width / 2
                readonly property real cy: haveWin ? win.y + win.height / 2 : height / 2 + 40
                // Buttons sit just outside the window edge.
                readonly property real ringR: haveWin
                    ? Math.max(140, Math.min(win.width, win.height) / 2 + 90)
                    : 150
                readonly property real arcSpan: 2.3          // radians (~132°) the arch spans

                // Central hub: names the window the actions target.
                Rectangle {
                    x: radial.cx - width / 2
                    y: radial.cy - height / 2
                    width: 76; height: 76; radius: 38
                    color: Theme.scrim
                    border.color: Theme.border
                    border.width: 1
                    opacity: radial.expand
                    Text {
                        anchors.centerIn: parent
                        width: 64
                        horizontalAlignment: Text.AlignHCenter
                        elide: Text.ElideRight
                        text: KalinViewport.focusedAppId.length > 0
                              ? KalinViewport.focusedAppId
                              : (KalinViewport.focusedTitle || "window")
                        color: Theme.textSecondary
                        font.pixelSize: 11
                        font.bold: true
                    }
                }

                Repeater {
                    model: scope.actions
                    delegate: Item {
                        id: node
                        required property int index
                        required property var modelData

                        readonly property int n: scope.actions.length
                        // Fan angle around straight-up (0); negative = left.
                        readonly property real ang:
                            -radial.arcSpan / 2
                            + (n <= 1 ? radial.arcSpan / 2
                                      : index * radial.arcSpan / (n - 1))
                        readonly property real rr: radial.ringR * radial.expand

                        width: 108; height: 108
                        x: radial.cx + rr * Math.sin(ang) - width / 2
                        y: radial.cy - rr * Math.cos(ang) - height / 2
                        opacity: radial.expand

                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Rectangle {
                                width: 64; height: 64; radius: 32
                                anchors.horizontalCenter: parent.horizontalCenter
                                color: Theme.surfaceActive
                                border.color: Theme.accent
                                border.width: 1
                                Text {
                                    anchors.centerIn: parent
                                    text: node.modelData.glyph
                                    color: Theme.accent
                                    font.pixelSize: 24
                                    font.bold: true
                                }
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: node.modelData.label
                                color: Theme.textBright
                                font.pixelSize: 12
                                font.bold: true
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: node.modelData.key
                                color: Theme.textSecondary
                                font.pixelSize: 10
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
