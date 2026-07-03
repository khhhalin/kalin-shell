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
            { key: "Q",        label: "Close" },
            { key: "E",        label: "Fullscreen" },
            { key: "⇧ Space",  label: "Float" },
            { key: "C",        label: "Crop" },
            { key: "Ctrl ← →", label: "Move column" },
        ]

        readonly property bool hasFocused:
            KalinViewport.focusedAppId.length > 0 || KalinViewport.focusedTitle.length > 0

        // Debounce: only raise the menu after Super has been held briefly, so a
        // quick Super+<key> chord doesn't flash it.
        Timer {
            id: holdTimer
            interval: 180
            repeat: false
            onTriggered: if (KalinViewport.superHeld && scope.hasFocused) menu.shown = true
        }

        Connections {
            target: KalinViewport
            function onStateChanged() {
                if (KalinViewport.superHeld) {
                    if (!menu.shown) holdTimer.restart()
                } else {
                    holdTimer.stop()
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
            visible: shown || menuCard.opacity > 0.01
            color: "transparent"

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
            WlrLayershell.namespace: "windows-bar:window-actions"

            Rectangle {
                id: menuCard
                anchors.centerIn: parent
                width: Math.max(260, header.implicitWidth + 48)
                height: layout.implicitHeight + 28
                radius: 14
                color: Theme.scrim
                border.color: Theme.border
                border.width: 1
                opacity: menu.shown ? 1 : 0
                scale: menu.shown ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: 140 } }
                Behavior on scale { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Column {
                    id: layout
                    anchors { left: parent.left; right: parent.right;
                              verticalCenter: parent.verticalCenter
                              leftMargin: 18; rightMargin: 18 }
                    spacing: 8

                    Text {
                        id: header
                        width: parent.width
                        elide: Text.ElideRight
                        text: KalinViewport.focusedAppId.length > 0
                              ? KalinViewport.focusedAppId
                              : (KalinViewport.focusedTitle || "window")
                        color: Theme.textSecondary
                        font.pixelSize: 12
                        font.bold: true
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.border }

                    Repeater {
                        model: scope.actions
                        delegate: Row {
                            id: actionRow
                            required property var modelData
                            width: layout.width
                            spacing: 12

                            Rectangle {
                                width: Math.max(48, keyText.implicitWidth + 16)
                                height: 24
                                radius: 6
                                color: Theme.surface
                                border.color: Theme.borderSubtle
                                border.width: 1
                                Text {
                                    id: keyText
                                    anchors.centerIn: parent
                                    text: actionRow.modelData.key
                                    color: Theme.accent
                                    font.pixelSize: 12
                                    font.bold: true
                                }
                            }
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: actionRow.modelData.label
                                color: Theme.textBright
                                font.pixelSize: 13
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
