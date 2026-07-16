import QtQuick
import "../services"

// ─────────────────────────────────────────────────────────────────────────────
// DiskUsageWidget — opens the docked disk-usage TUI (kalin-bar-tui disk),
// an ncdu-style "where did the space go" browser.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property bool hovered: false
    property bool active:  false
    signal clicked()

    readonly property string label: "󰋊"

    implicitWidth:  Math.max(iconText.implicitWidth + 20, 48)
    implicitHeight: BarConfig.barHeight

    // TUI-box treatment, same as TuiLauncherWidget.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 3
        radius:       BarConfig.buttonRadius
        color:        root.active ? Theme.surfaceAlt : "transparent"
        border.width: 1
        border.color: root.active ? Theme.accent
                    : (root.hovered ? Theme.accent : Theme.borderSubtle)

        Text {
            id:              iconText
            anchors.centerIn: parent
            text:            root.label
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
