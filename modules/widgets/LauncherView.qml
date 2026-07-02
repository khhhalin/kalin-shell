import QtQuick

import "../services"

FocusScope {
    id: root

    property int maxResults: 40

    // When a command/app is launched.
    signal launched(var entry)

    implicitWidth:  BarConfig.launcherDefaultWidth
    implicitHeight: BarConfig.launcherDefaultHeight

    property string query: ""
    property int selectedIndex: 0

    property var results: []

    function refreshResults(): void {
        const q = String(root.query || "")
        const trimmed = q.trim()

        const base = LauncherIndex.search(trimmed, root.maxResults) || []
        // Bias ordering by usage (stable: keep fuzzy order within same usage count).
        const ranked = base.map((entry, idx) => ({ entry, idx, usage: UsageStats.score(entry) }))
        ranked.sort((a, b) => {
            if (a.usage !== b.usage) return b.usage - a.usage
            return a.idx - b.idx
        })
        root.results = ranked.map(r => r.entry)

        if (root.selectedIndex >= root.results.length) root.selectedIndex = Math.max(0, root.results.length - 1)
        if (root.selectedIndex < 0) root.selectedIndex = 0
    }

    function moveSelection(delta): void {
        if (!root.results || root.results.length === 0) return
        root.selectedIndex = Math.max(0, Math.min(root.selectedIndex + delta, root.results.length - 1))
        list.positionViewAtIndex(root.selectedIndex, ListView.Contain)
    }

    function _shQuote(s): string {
        const str = String(s ?? "")
        return "'" + str.replace(/'/g, "'\"'\"'") + "'"
    }

    function activateSelected(): void {
        if (!root.results || root.results.length === 0) return
        const idx = Math.max(0, Math.min(root.selectedIndex, root.results.length - 1))
        const entry = root.results[idx]
        if (entry.kind === "cmd") {
            const cmd = String(entry.exec ?? "").trim()
            if (!cmd.length) return
            // Open a terminal with an editable, prefilled command line.
            const bashScript = "read -e -i " + _shQuote(cmd) + " line; eval \"$line\"; exec bash"
            SystemActions.spawn("foot -e bash -lc " + _shQuote(bashScript))
        } else {
            // Route app launches into tmux: one persistent session, one window per app.
            TmuxService.launch(entry.name, entry.exec)
        }
        UsageStats.bump(entry)
        root.launched(entry)
    }

    onQueryChanged: refreshResults()
    onMaxResultsChanged: refreshResults()

    Connections {
        target: LauncherIndex
        function onUpdated() { root.refreshResults() }
    }

    Component.onCompleted: refreshResults()

    Rectangle {
        anchors.fill: parent
        radius: BarConfig.launcherContainerRadius
        color: "#2a2a2a"
        clip: true
        ListView {
                id: list
                anchors.fill: parent
                anchors.margins: BarConfig.launcherListMargin

                model: root.results
                spacing: BarConfig.launcherRowGap
                currentIndex: root.selectedIndex

                delegate: Rectangle {
                    id: row
                    required property var modelData

                    width: ListView.view.width
                    height: BarConfig.launcherRowHeight
                    radius: BarConfig.launcherRowRadius
                    color: ListView.isCurrentItem ? "#3a3a3a" : "transparent"

                    Row {
                        anchors.fill: parent
                        anchors.leftMargin: BarConfig.launcherRowHPadding
                        anchors.rightMargin: BarConfig.launcherRowHPadding
                        spacing: BarConfig.launcherRowSpacing

                        Rectangle {
                            width:  BarConfig.launcherIconSize
                            height: BarConfig.launcherIconSize
                            radius: BarConfig.launcherIconRadius
                            anchors.verticalCenter: parent.verticalCenter
                            color: (modelData.kind === "app") ? "#2f4a7a" : "#3a3a3a"

                            Text {
                                anchors.centerIn: parent
                                text: modelData.kind === "app" ? "A" : ">"
                                color: "#e6e6e6"
                                font.pixelSize: BarConfig.launcherNameFontSize
                            }
                        }

                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 1

                            Text {
                                text: modelData.name
                                color: "#e6e6e6"
                                font.pixelSize: BarConfig.launcherNameFontSize
                                elide: Text.ElideRight
                                width: list.width - BarConfig.launcherTextWidthInset
                            }

                            Text {
                                text: modelData.kind === "app" ? (modelData.desktopId || "") : modelData.exec
                                color: "#9a9a9a"
                                font.pixelSize: BarConfig.launcherSubFontSize
                                elide: Text.ElideRight
                                width: list.width - BarConfig.launcherTextWidthInset
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: {
                            // Calculate the row index without relying on the implicit `index`.
                            const idx = list.indexAt(row.x + row.width / 2, row.y + row.height / 2)
                            if (idx >= 0) root.selectedIndex = idx
                        }
                        onClicked: {
                            // Ensure selection follows the clicked row.
                            const idx = list.indexAt(row.x + row.width / 2, row.y + row.height / 2)
                            if (idx >= 0) root.selectedIndex = idx
                            root.activateSelected()
                        }
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    visible: root.results.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: LauncherIndex.ready ? "No matches" : "Indexing…"
                        color: "#9a9a9a"
                        font.pixelSize: BarConfig.launcherNameFontSize
                    }
                }
            }
    }
}
