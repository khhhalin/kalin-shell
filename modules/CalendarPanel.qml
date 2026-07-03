import QtQuick
import QtQuick.Layouts
import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// CalendarPanel — month grid backed by Google Calendar via gcalcli.
// ─────────────────────────────────────────────────────────────────────────────
Item {
    id: root

    property date viewDate: new Date()
    property int selectedDay: viewDate.getDate()

    readonly property int daysInMonth: {
        const d = new Date(viewDate)
        d.setMonth(d.getMonth() + 1)
        d.setDate(0)
        return d.getDate()
    }

    readonly property int firstWeekday: {
        const d = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1)
        return d.getDay()
    }

    function eventsForDay(day) {
        const dateStr = Qt.formatDate(new Date(viewDate.getFullYear(), viewDate.getMonth(), day), "yyyy-MM-dd")
        return CalendarService.events.filter(e => e.startDate === dateStr)
    }

    Component.onCompleted: {
        const now = new Date()
        CalendarService.refresh(now.getFullYear(), now.getMonth() + 1)
    }

    onViewDateChanged: {
        CalendarService.refresh(viewDate.getFullYear(), viewDate.getMonth() + 1)
    }

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ── Header ──────────────────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 28

            Rectangle {
                anchors.left: parent.left
                width: 28; height: 28; radius: 6
                color: prevMa.containsMouse ? "#2a2a2a" : "#1e1e1e"
                Text { anchors.centerIn: parent; text: "‹"; color: "#e6e6e6"; font.pixelSize: 18 }
                MouseArea {
                    id: prevMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = new Date(root.viewDate)
                        d.setMonth(d.getMonth() - 1)
                        root.viewDate = d
                    }
                }
            }

            Text {
                anchors.centerIn: parent
                text: Qt.formatDate(root.viewDate, "MMMM yyyy")
                color: "#e6e6e6"
                font.pixelSize: 15
                font.weight: Font.Medium
            }

            Rectangle {
                anchors.right: parent.right
                width: 28; height: 28; radius: 6
                color: nextMa.containsMouse ? "#2a2a2a" : "#1e1e1e"
                Text { anchors.centerIn: parent; text: "›"; color: "#e6e6e6"; font.pixelSize: 18 }
                MouseArea {
                    id: nextMa
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        const d = new Date(root.viewDate)
                        d.setMonth(d.getMonth() + 1)
                        root.viewDate = d
                    }
                }
            }
        }

        // ── Weekday labels ──────────────────────────────────────────────────────
        Row {
            width: parent.width
            height: 18
            spacing: 0
            Repeater {
                model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
                delegate: Text {
                    required property string modelData
                    width: parent.width / 7
                    horizontalAlignment: Text.AlignHCenter
                    text: modelData
                    color: "#888888"
                    font.pixelSize: 11
                }
            }
        }

        // ── Month grid ──────────────────────────────────────────────────────────
        Grid {
            id: dayGrid
            width: parent.width
            height: parent.width * 0.85
            columns: 7
            rows: 6
            spacing: 4

            Repeater {
                model: 42

                delegate: Rectangle {
                    id: cell
                    required property int index

                    readonly property int dayNumber: index - root.firstWeekday + 1
                    readonly property bool inMonth: dayNumber >= 1 && dayNumber <= root.daysInMonth
                    readonly property bool isSelected: inMonth && dayNumber === root.selectedDay
                    readonly property var dayEvents: inMonth ? root.eventsForDay(dayNumber) : []

                    width: (dayGrid.width - 6 * dayGrid.spacing) / 7
                    height: (dayGrid.height - 5 * dayGrid.spacing) / 6
                    radius: 6
                    color: isSelected ? "#1a3a5a" : (cellMa.containsMouse ? "#252525" : "transparent")
                    border.width: isSelected ? 1 : 0
                    border.color: "#4fc3f7"

                    Column {
                        anchors.fill: parent
                        anchors.margins: 4
                        spacing: 2

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: cell.inMonth ? cell.dayNumber : ""
                            color: cell.isSelected ? "#4fc3f7" : "#e6e6e6"
                            font.pixelSize: 12
                        }

                        Row {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 3
                            Repeater {
                                model: Math.min(cell.dayEvents.length, 3)
                                delegate: Rectangle {
                                    width: 5; height: 5; radius: 2.5
                                    color: "#4fc3f7"
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: cellMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (cell.inMonth) root.selectedDay = cell.dayNumber
                    }
                }
            }
        }

        // ── Selected day detail ─────────────────────────────────────────────────
        Item {
            width: parent.width
            height: 90

            Column {
                anchors.fill: parent
                spacing: 6

                Text {
                    text: root.eventsForDay(root.selectedDay).length > 0
                          ? Qt.formatDate(new Date(root.viewDate.getFullYear(), root.viewDate.getMonth(), root.selectedDay), "dddd, MMMM d")
                          : "No events"
                    color: "#888888"
                    font.pixelSize: 11
                    font.capitalization: Font.AllUppercase
                }

                Flickable {
                    width: parent.width
                    height: parent.height - 20
                    contentHeight: detailCol.height
                    clip: true

                    Column {
                        id: detailCol
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: root.eventsForDay(root.selectedDay)

                            delegate: Text {
                                required property var modelData
                                text: (modelData.startTime ? modelData.startTime + "  " : "") + modelData.title
                                color: "#e6e6e6"
                                font.pixelSize: 12
                                elide: Text.ElideRight
                                width: parent.width
                            }
                        }
                    }
                }
            }
        }

        // ── Error / auth message ────────────────────────────────────────────────
        Text {
            width: parent.width
            visible: CalendarService.error !== ""
            text: CalendarService.error.includes("auth")
                  ? "Run ‘gcalcli list’ in a terminal to authenticate."
                  : CalendarService.error
            color: "#ff6b6b"
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }

        // ── Quick-add input ─────────────────────────────────────────────────────
        Rectangle {
            width: parent.width
            height: 34
            radius: 8
            color: "#1e1e1e"
            border.width: 1
            border.color: input.activeFocus ? "#4fc3f7" : "#2a2a2a"

            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: 8
                color: "#e6e6e6"
                font.pixelSize: 13
                verticalAlignment: Text.AlignVCenter
                clip: true

                Keys.onReturnPressed: {
                    if (text.trim().length) {
                        CalendarService.addEvent(text.trim())
                        text = ""
                    }
                }

                Text {
                    anchors.fill: parent
                    text: "Add event…"
                    color: "#555555"
                    font.pixelSize: 13
                    verticalAlignment: Text.AlignVCenter
                    visible: input.text.length === 0 && !input.activeFocus
                }
            }
        }
    }
}
