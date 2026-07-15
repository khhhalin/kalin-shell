import QtQuick
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// ClipboardButton — hover/click trigger for the docked clipboard-history
// terminal panel (see ../DockedPanel.qml, instantiated in BottomBar.qml).
// Static icon, no polling — unlike VolumeWidget/BatteryWidget there's no
// live status to reflect, the panel is either open or not.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool hovered: false
    property bool active:  false
    signal clicked()

    implicitWidth:  BarConfig.barHeight
    implicitHeight: BarConfig.barHeight

    // TUI-box treatment, same as TuiLauncherWidget; nerd-font glyph instead of
    // the color emoji (emoji ignores `color:` and clashes with the amber rice).
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius:       BarConfig.buttonRadius
        color:        root.active ? Theme.surfaceAlt : "transparent"
        border.width: 1
        border.color: root.active ? Theme.accent
                    : (root.hovered ? Theme.accent : Theme.borderSubtle)

        Text {
            anchors.centerIn: parent
            text:            "󰅍"
            color:           root.active ? Theme.accent : (root.hovered ? Theme.text : Theme.textDim)
            font.pixelSize:  BarConfig.clockFontSize
            font.family:     "monospace"
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape:  Qt.PointingHandCursor
        onEntered:    root.hovered = true
        onExited:     root.hovered = false
        onClicked:    root.clicked()
    }
}
