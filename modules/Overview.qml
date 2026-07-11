import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// Overview — full-screen exposé. Shows every window as a live thumbnail
// (ScreencopyView over the foreign-toplevel handles surfaced by
// CompositorService); clicking a thumbnail focuses that window and closes the
// overview. Visible only while OverviewState.visible is true.
//
// Toggle from a compositor keybind:  qs ipc call windows-bar toggleOverview
// Works on any backend that exposes toplevels (kalin-wm via
// wlr-foreign-toplevel-management; falls back to the niri window list with
// placeholder tiles when no toplevel handle is available).
// ─────────────────────────────────────────────────────────────────────────────
Variants {
    model: Quickshell.screens

    Scope {
        required property ShellScreen modelData

        PanelWindow {
            id: overview
            screen: modelData
            visible: OverviewState.visible
            color: Theme.overlayDim

            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: OverviewState.visible
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            WlrLayershell.namespace: "windows-bar:overview"

            // Key handling must live on a focusable Item, not the PanelWindow.
            Item {
                id: overviewContent
                anchors.fill: parent
                focus: OverviewState.visible

                // Keyboard selection index into CompositorService.windows.
                property int selectedIndex: 0

                // Fade + scale in when shown.
                opacity: OverviewState.visible ? 1 : 0
                scale:   OverviewState.visible ? 1 : 0.96
                Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
                Behavior on scale   { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

                Connections {
                    target: OverviewState
                    function onVisibleChanged() {
                        if (OverviewState.visible) overviewContent.selectedIndex = 0
                    }
                }

                function activateSelected() {
                    const w = CompositorService.windows[overviewContent.selectedIndex]
                    if (w) { CompositorService.activate(w); OverviewState.hide() }
                }

                Keys.onEscapePressed: OverviewState.hide()
                Keys.onLeftPressed:  selectedIndex = Math.max(0, selectedIndex - 1)
                Keys.onRightPressed: selectedIndex = Math.min(repeater.count - 1, selectedIndex + 1)
                Keys.onReturnPressed: activateSelected()
                Keys.onEnterPressed:  activateSelected()

            // Esc / click on the backdrop closes.
            MouseArea {
                anchors.fill: parent
                onClicked: OverviewState.hide()
            }

            GridLayout {
                anchors.centerIn: parent
                width: parent.width * 0.86
                height: parent.height * 0.82
                columns: Math.max(1, Math.ceil(Math.sqrt(Math.max(1, repeater.count))))
                columnSpacing: 24
                rowSpacing: 24

                Repeater {
                    id: repeater
                    model: CompositorService.windows

                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        readonly property bool selected:
                            overviewContent.selectedIndex === index || modelData.isFocused
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: 12
                        color: selected ? Theme.accentSoft : Theme.surface
                        border.color: selected ? Theme.focusRing : Theme.border
                        border.width: selected ? 2 : 1
                        clip: true

                        ColumnLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 6

                            // Live thumbnail when a foreign-toplevel handle exists.
                            // Wrapped in a Loader keyed on the handle's validity — see
                            // the comment inside for why the ScreencopyView itself must
                            // never have its captureSource reassigned to null.
                            Item {
                                Layout.fillWidth: true
                                Layout.fillHeight: true

                                Loader {
                                    anchors.fill: parent
                                    // Also gated on OverviewState.visible, not just the
                                    // toplevel's validity: the enclosing PanelWindow's
                                    // `visible: OverviewState.visible` (see the file
                                    // header) only hides the panel — it does NOT tear
                                    // down this component tree. Without this, every
                                    // open window's thumbnail Timer fires
                                    // captureFrame() every thumbnailRefreshMs forever,
                                    // in the background, whether Overview is ever
                                    // opened or not — meaning the close-race with
                                    // Quickshell's capture code (see the pinnedSource
                                    // comment below) was reproducible on *every* window
                                    // close, not just while Overview happened to be
                                    // open. Only actually construct (and only actually
                                    // capture) while the user can see it.
                                    active: modelData.toplevel !== null && OverviewState.visible
                                    sourceComponent: Component {
                                        ScreencopyView {
                                            id: thumbView
                                            anchors.fill: parent
                                            // Snapshotted once at creation (imperative
                                            // assignment in Component.onCompleted, not a
                                            // binding) rather than `captureSource:
                                            // modelData.toplevel` directly. That direct
                                            // binding reassigns captureSource to null the
                                            // instant the window closes — and merely
                                            // *assigning* a null captureSource to a live
                                            // ScreencopyView appears to make Quickshell's
                                            // own (compiled, not ours) capture-negotiation
                                            // code immediately attempt
                                            // capture_toplevel_with_wlr_toplevel_handle
                                            // with a null handle, which is a fatal,
                                            // non-recoverable Wayland protocol error that
                                            // kills the whole connection — confirmed live
                                            // on real hardware even after guarding the
                                            // Timer below (that guard alone wasn't
                                            // enough; the crash isn't only from
                                            // captureFrame()). Freezing the value here and
                                            // destroying this whole Loader'd instance via
                                            // `active` above (instead of reassigning its
                                            // property) means captureSource is never once
                                            // set to null on a live instance.
                                            property var pinnedSource: null
                                            Component.onCompleted: pinnedSource = modelData.toplevel
                                            captureSource: pinnedSource
                                            // Periodic snapshot, not `live: true` — see
                                            // the comment on OverviewState.thumbnailRefreshMs
                                            // for why: every tile
                                            // "live" at once means every tile
                                            // renegotiates a buffer on every single
                                            // compositor frame, and that dmabuf
                                            // negotiation was observed failing
                                            // ("No matching formats") and falling
                                            // back to SHM on *every* attempt — a
                                            // continuous churn of failed
                                            // allocations that was the real driver
                                            // behind this bar's recurring crashes,
                                            // not just the notification popup model
                                            // bug fixed separately in
                                            // NotificationService.qml.
                                            live: false

                                            Timer {
                                                interval: OverviewState.thumbnailRefreshMs
                                                running: thumbView.visible
                                                repeat: true
                                                triggeredOnStart: true
                                                onTriggered: if (thumbView.captureSource) thumbView.captureFrame()
                                            }
                                        }
                                    }
                                }

                                // Fallback tile (e.g. niri backend without a handle).
                                Text {
                                    anchors.centerIn: parent
                                    visible: modelData.toplevel === null
                                    text: modelData.appId || "window"
                                    color: Theme.textDim
                                    font.pixelSize: 14
                                }
                            }

                            Text {
                                Layout.fillWidth: true
                                text: modelData.title || modelData.appId || ""
                                color: Theme.text
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                horizontalAlignment: Text.AlignHCenter
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                CompositorService.activate(modelData)
                                OverviewState.hide()
                            }
                        }
                    }
                }
            }

            // Empty-state hint.
            Text {
                anchors.centerIn: parent
                visible: repeater.count === 0
                text: "No open windows"
                color: Theme.textSecondary
                font.pixelSize: 18
            }
            } // overviewContent
        }
    }
}
