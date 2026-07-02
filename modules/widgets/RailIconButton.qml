import QtQuick
import "../services"

Item {
    id: root

    // Prefer iconSource; falls back to glyph.
    property url iconSource: ""
    property string glyph: ""
    // Optional: if set, draws a simple built-in icon when SVG can't load.
    // Supported: "menu", "settings", "power"
    property string fallbackKind: ""
    property string tooltip: ""

    // Sizing (override per-use for pixel-perfect alignment with the bar)
    property int iconSize: BarConfig.railIconSize

    signal clicked()
    signal hoverEntered()
    signal hoverExited()
    readonly property alias hovered: mouse.containsMouse
    property bool active: false

    implicitWidth:  BarConfig.barHeight
    implicitHeight: BarConfig.barHeight

    readonly property bool _iconWanted: String(root.iconSource).length > 0
    readonly property bool _iconReady: icon.status === Image.Ready
    readonly property bool _showIcon: _iconWanted && _iconReady

    Rectangle {
        anchors.fill: parent
        radius: BarConfig.buttonRadius
        color: root.active ? "#2f2f2f" : (hover.hovered ? "#2a2a2a" : "transparent")
        border.width: root.active ? 1 : 0
        border.color: "#3a3a3a"

        Image {
            id: icon
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            source: root.iconSource
            visible: root._showIcon
            fillMode: Image.PreserveAspectFit
            smooth: true
            mipmap: true

            onStatusChanged: {
                if (status === Image.Error) {
                    console.warn("RailIconButton: failed to load icon", root.iconSource, errorString)
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: root.glyph
            visible: !root._showIcon && root.glyph.length > 0
            color: "#e6e6e6"
            font.pixelSize: BarConfig.railGlyphSize
        }

        Canvas {
            id: fallbackCanvas
            anchors.centerIn: parent
            width: root.iconSize
            height: root.iconSize
            visible: !root._showIcon && root.glyph.length === 0 && root.fallbackKind.length > 0

            onVisibleChanged: if (visible) requestPaint()

            onPaint: {
                const ctx = getContext("2d")
                ctx.save()
                if (ctx.resetTransform) ctx.resetTransform()
                else ctx.setTransform(1, 0, 0, 1, 0, 0)
                ctx.clearRect(0, 0, width, height)
                ctx.restore()

                ctx.strokeStyle = "#e6e6e6"
                ctx.fillStyle = "#e6e6e6"
                ctx.lineWidth = 1.8
                ctx.lineCap = "round"
                ctx.lineJoin = "round"

                const w = width
                const h = height

                function line(x1, y1, x2, y2) {
                    ctx.beginPath()
                    ctx.moveTo(x1, y1)
                    ctx.lineTo(x2, y2)
                    ctx.stroke()
                }

                if (root.fallbackKind === "menu") {
                    line(3, 4.5, w - 3, 4.5)
                    line(3, h / 2, w - 3, h / 2)
                    line(3, h - 4.5, w - 3, h - 4.5)
                } else if (root.fallbackKind === "power") {
                    // Arc
                    ctx.beginPath()
                    ctx.arc(w / 2, h / 2 + 0.5, 6.2, Math.PI * 0.25, Math.PI * 1.75, false)
                    ctx.stroke()
                    // Line
                    line(w / 2, 2.2, w / 2, 8.2)
                } else if (root.fallbackKind === "settings") {
                    // Symmetric cog icon
                    const cx = w / 2
                    const cy = h / 2
                    const outerR = Math.min(w, h) * 0.34
                    const innerR = Math.min(w, h) * 0.16
                    const toothOuter = Math.min(w, h) * 0.48
                    const toothInner = Math.min(w, h) * 0.40

                    // Teeth (8 directions)
                    const angles = [0, 45, 90, 135, 180, 225, 270, 315]
                    for (let i = 0; i < angles.length; i++) {
                        const a = angles[i] * Math.PI / 180
                        const x1 = cx + Math.cos(a) * toothInner
                        const y1 = cy + Math.sin(a) * toothInner
                        const x2 = cx + Math.cos(a) * toothOuter
                        const y2 = cy + Math.sin(a) * toothOuter
                        line(x1, y1, x2, y2)
                    }

                    // Outer + inner rings
                    ctx.beginPath()
                    ctx.arc(cx, cy, outerR, 0, Math.PI * 2)
                    ctx.stroke()

                    ctx.beginPath()
                    ctx.arc(cx, cy, innerR, 0, Math.PI * 2)
                    ctx.stroke()
                }
            }
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
        onEntered: root.hoverEntered()
        onExited: root.hoverExited()
    }

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) root.hoverEntered()
            else         root.hoverExited()
        }
    }
}
