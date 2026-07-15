import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: panel

    // No `property ... screen` — it would shadow PanelWindow's own screen
    // property and break per-monitor placement (see BottomBar.qml's note).

    // "left" or "right"
    property string side: "left"

    property int barHeight: 44
    property int panelWidth: 420
    property int panelHeight: 520
    // Tiny overlap to avoid a 1px seam due to rounding/subpixel.
    property int seamOverlapPx: 1

    property bool open: false

    // Edit mode (resize handles)
    property bool editMode: false

    signal resizeWidthRequested(int width)
    signal resizeHeightRequested(int height)

    property real _resizeStartX: 0
    property real _resizeStartY: 0
    property int _resizeStartWidth: 0
    property int _resizeStartHeight: 0

    // 0..1 animation driver (keeps morph + easing consistent)
    property real progress: 0

    // Provide your own contents from parent (skeleton)
    property Component content: null

    // Emits hover state so the controller can keep the panel open
    signal hoverChanged(bool hovered)

    color: "transparent"

    anchors {
        left: side === "left"
        right: side === "right"
        bottom: true
    }

    // Keep window geometry stable (better for wlroots/niri).
    implicitWidth: panelWidth
    implicitHeight: panelHeight
    margins.bottom: barHeight

    // Keep the surface mapped for instant hover response.
    // Use a dynamic mask so it doesn't steal input when the drawer is closed.
    mask: Region {
        x: 0
        y: panel.height - drawerFx.height
        width: drawerFx.width
        height: drawerFx.height + panel.seamOverlapPx
    }

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "windows-bar:side-panel"

    NumberAnimation {
        id: openAnim
        target: panel
        property: "progress"
        to: 1
        duration: 220
        easing.type: Easing.OutCubic
    }

    NumberAnimation {
        id: closeAnim
        target: panel
        property: "progress"
        to: 0
        duration: 170
        easing.type: Easing.InOutCubic
    }

    onOpenChanged: {
        openAnim.stop()
        closeAnim.stop()
        if (open) openAnim.start()
        else closeAnim.start()
    }

    // Morph drawer container (rolls up from the bar).
    // Shadow lives on this wrapper (not clipped), so it won't create dark
    // artifacts under rounded corners.
    Item {
        id: drawerFx

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom

        // Grow upwards immediately (avoid a perceptual "delay" at tiny heights).
        readonly property real minVisibleHeight: 6
        height: panel.progress <= 0.001
            ? 0
            : Math.max(minVisibleHeight, panel.panelHeight * panel.progress)

        // Optional overshoot feel: slight Y-scale from the bottom.
        transform: Scale {
            origin.x: drawerFx.width / 2
            origin.y: drawerFx.height
            yScale: 0.45 + 0.55 * panel.progress
        }

        // No shadow: avoids "black corner" artifacts on rounded edges.
        layer.enabled: false

        Rectangle {
            id: drawer
            anchors.fill: parent

            // Morphing corners + Caelestia-ish border.
            readonly property real innerRadius: 14
            readonly property real outerRadiusBase: 24
            // Ease radius morph a bit for a cleaner feel.
            readonly property real eased: 1 - Math.pow(1 - panel.progress, 3)
            readonly property real outerRadius: outerRadiusBase * (1 - eased)

            // Borderless panel (clean surface)
            readonly property int borderWidth: 0

            // Outer edge (flush to screen) morphs to square on OPEN.
            // Inner edge stays rounded.
            // Bottom corners: outer-bottom is ALWAYS square so the slope always
            // carries from the vertical panel into the horizontal bar correctly.
            topLeftRadius: panel.side === "left" ? outerRadius : innerRadius
            topRightRadius: panel.side === "right" ? outerRadius : innerRadius
            // Abandon bottom-corner rounding; keep the join with the bar clean.
            bottomLeftRadius: 0
            bottomRightRadius: 0

            color: "#1f1f1f"
            border.width: borderWidth
            clip: true

            // Hide the bottom border so it fuses into the bar with no edge.
            Rectangle {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                height: drawer.borderWidth + panel.seamOverlapPx
                color: drawer.color
            }

            // Content fades in quickly; the container does the main motion.
            opacity: Math.min(1, panel.progress * 1.2)

            Loader {
                anchors.fill: parent
                sourceComponent: panel.content
            }

            // Resize handles (edit mode only)
            Rectangle {
                id: widthHandle
                visible: panel.editMode
                width: 12
                color: "#00000000"
                z: 5
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    right: panel.side === "left" ? parent.right : undefined
                    left: panel.side === "right" ? parent.left : undefined
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: 2
                    height: parent.height
                    color: "#3b3b3b"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeHorCursor
                    preventStealing: true
                    onPressed: {
                        panel._resizeStartX = mouse.x
                        panel._resizeStartWidth = panel.panelWidth
                    }
                    onPositionChanged: {
                        if (!pressed) return
                        const dx = mouse.x - panel._resizeStartX
                        const delta = panel.side === "left" ? dx : -dx
                        panel.resizeWidthRequested(Math.round(panel._resizeStartWidth + delta))
                    }
                }
            }

            Rectangle {
                id: heightHandle
                visible: panel.editMode
                height: 12
                color: "#00000000"
                z: 5
                anchors { left: parent.left; right: parent.right; top: parent.top }

                Rectangle {
                    anchors.centerIn: parent
                    height: 2
                    width: parent.width
                    color: "#3b3b3b"
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.SizeVerCursor
                    preventStealing: true
                    onPressed: {
                        panel._resizeStartY = mouse.y
                        panel._resizeStartHeight = panel.panelHeight
                    }
                    onPositionChanged: {
                        if (!pressed) return
                        const dy = mouse.y - panel._resizeStartY
                        panel.resizeHeightRequested(Math.round(panel._resizeStartHeight - dy))
                    }
                }
            }

            HoverHandler {
                onHoveredChanged: panel.hoverChanged(hovered)
            }
        }
    }
}
