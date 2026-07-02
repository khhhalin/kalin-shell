import QtQuick
import Quickshell
import Quickshell.Wayland

import "./services"

// Win10-style right-click context menu for taskbar buttons.
//
// Implemented as a full-width Overlay PanelWindow with a mask that covers
// only the menu rectangle, so clicks outside the menu fall through to the
// click-catcher layer (which closes everything).
PanelWindow {
    id: root

    property string appId: ""
    property int    buttonCenterX: 0   // screen-space x centre of the clicked button

    signal closeRequested()

    // ── Resolved item ─────────────────────────────────────────────────────────
    readonly property var _item: {
        for (const it of TaskbarService.items)
            if (it.appId === root.appId) return it
        return null
    }
    readonly property string _name:    _item && _item.entry ? _item.entry.name : root.appId
    readonly property bool   _pinned:  _item ? _item.isPinned  : false
    readonly property bool   _running: _item ? _item.isRunning : false
    readonly property int    _count:   _item ? _item.windowCount : 0

    // ── Geometry ──────────────────────────────────────────────────────────────
    readonly property int _pad:  8
    readonly property int _menuW: 200
    // Clamp so the menu never overflows the screen edge
    readonly property int _menuX: screen
        ? Math.max(0, Math.min(buttonCenterX - _menuW / 2, screen.width - _menuW))
        : 0

    // ── Layer shell setup ─────────────────────────────────────────────────────
    color: "transparent"
    anchors { left: true; right: true; bottom: true }
    implicitHeight: _menu.height
    margins.bottom: BarConfig.barHeight

    exclusionMode: ExclusionMode.Ignore
    exclusiveZone: 0
    WlrLayershell.layer:         WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace:     "windows-bar:context-menu"

    // Only the menu rectangle intercepts input.
    // Clicks outside fall through to the click-catcher on the layer below.
    mask: Region { item: _menu }

    // ── Inline action row component ───────────────────────────────────────────
    component MenuRow: Item {
        id: _mr
        property string label: ""
        property string glyph: ""
        signal triggered()

        width:  parent.width
        height: 30

        Rectangle {
            anchors.fill:    parent
            anchors.margins: 2
            radius:          BarConfig.buttonRadius
            color:           _mhov.containsMouse ? "#333333" : "transparent"
        }

        Row {
            anchors.fill:       parent
            anchors.leftMargin: 10
            spacing:            9

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           _mr.glyph
                color:          "#a0a0a0"
                font.pixelSize: 13
                visible:        _mr.glyph.length > 0
            }
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text:           _mr.label
                color:          "#e6e6e6"
                font.pixelSize: 12
            }
        }

        MouseArea {
            id: _mhov
            anchors.fill: parent
            hoverEnabled: true
            cursorShape:  Qt.PointingHandCursor
            onClicked:    _mr.triggered()
        }
    }

    // ── Menu rectangle ────────────────────────────────────────────────────────
    Rectangle {
        id: _menu
        x:      root._menuX
        y:      0
        width:  root._menuW
        height: _col.implicitHeight + root._pad * 2
        radius: BarConfig.buttonRadius + 2
        color:  "#252525"
        border { width: 1; color: "#3a3a3a" }

        Column {
            id: _col
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: root._pad }
            spacing: 1

            // App name header (non-interactive)
            Item {
                width: parent.width
                height: 26

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left:           parent.left
                    anchors.leftMargin:     8
                    text:                   root._name
                    color:                  "#888888"
                    font.pixelSize:         11
                    font.bold:              true
                    elide:                  Text.ElideRight
                    width:                  parent.width - 16
                }
            }

            Rectangle { width: parent.width; height: 1; color: "#3a3a3a" }

            // Pin / Unpin
            MenuRow {
                glyph: root._pinned ? "⊟" : "⊞"
                label: root._pinned ? "Unpin from taskbar" : "Pin to taskbar"
                onTriggered: { TaskbarService.togglePin(root.appId); root.closeRequested() }
            }

            // Separator + close actions (only when the app has windows open)
            Rectangle { visible: root._running; width: parent.width; height: 1; color: "#3a3a3a" }

            MenuRow {
                visible: root._running && root._count <= 1
                glyph:   "✕"
                label:   "Close window"
                onTriggered: { TaskbarService.closeAll(root.appId); root.closeRequested() }
            }
            MenuRow {
                visible: root._running && root._count > 1
                glyph:   "✕"
                label:   "Close all windows (" + root._count + ")"
                onTriggered: { TaskbarService.closeAll(root.appId); root.closeRequested() }
            }
        }
    }
}
