import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland

import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// WindowPeek — live thumbnail popup shown when hovering a taskbar button.
// Overlay PanelWindow masked to the card only (clicks elsewhere fall through),
// mirroring TaskbarContextMenu. Thumbnails come from the foreign-toplevel
// handles for the app (works on niri and kalin-wm); click one to focus it.
// ─────────────────────────────────────────────────────────────────────────────
PanelWindow {
    id: root

    property string appId: ""
    property int    buttonCenterX: 0
    property bool   show: false

    // Foreign-toplevel handles for this app (re-evaluated when appId changes).
    readonly property var toplevels: CompositorService.toplevelsForAppId(appId)
    // True while the cursor is over the popup itself (keeps it open).
    property alias hovered: cardHover.hovered

    readonly property string _name: {
        for (const it of TaskbarService.items)
            if (it.appId === root.appId) return it.entry ? it.entry.name : root.appId
        return root.appId
    }

    visible: root.show && root.appId.length > 0 && root.toplevels.length > 0

    // ── Geometry ──────────────────────────────────────────────────────────────
    readonly property int _thumbW: 220
    readonly property int _thumbH: 132
    readonly property int _gap: 8
    readonly property int _pad: 8
    readonly property int _contentW:
        root.toplevels.length * _thumbW + Math.max(0, root.toplevels.length - 1) * _gap + _pad * 2
    readonly property int _x: screen
        ? Math.max(4, Math.min(buttonCenterX - _contentW / 2, screen.width - _contentW - 4))
        : 0

    color: "transparent"
    anchors { left: true; right: true; bottom: true }
    implicitHeight: card.height
    margins.bottom: BarConfig.barHeight + 6

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace:     "windows-bar:peek"

    mask: Region { item: card }

    Rectangle {
        id: card
        x:      root._x
        y:      0
        width:  root._contentW
        height: col.implicitHeight + root._pad * 2
        radius: BarConfig.buttonRadius + 2
        color:  Theme.scrim
        border { width: 1; color: Theme.border }

        HoverHandler { id: cardHover }

        Column {
            id: col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: root._pad }
            spacing: 6

            Text {
                text:           root._name
                color:          Theme.textSecondary
                font.pixelSize: 11
                font.bold:      true
                elide:          Text.ElideRight
                width:          parent.width
            }

            Row {
                spacing: root._gap

                Repeater {
                    model: root.toplevels

                    delegate: ColumnLayout {
                        required property var modelData
                        spacing: 4

                        Rectangle {
                            Layout.preferredWidth:  root._thumbW
                            Layout.preferredHeight: root._thumbH
                            radius: 6
                            color:  Theme.surface
                            border.width: 1
                            border.color: modelData.activated ? Theme.focusRing : Theme.border
                            clip: true

                            ScreencopyView {
                                anchors.fill:    parent
                                anchors.margins: 1
                                live:            root.visible
                                captureSource:   modelData
                            }

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape:  Qt.PointingHandCursor
                                onClicked: {
                                    modelData.activate()
                                    root.show = false
                                }
                            }
                        }

                        Text {
                            Layout.preferredWidth: root._thumbW
                            text:           modelData.title || root._name
                            color:          Theme.textDim
                            font.pixelSize: 10
                            elide:          Text.ElideRight
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }
                }
            }
        }
    }
}
