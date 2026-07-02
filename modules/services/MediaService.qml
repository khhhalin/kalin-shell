pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// ─────────────────────────────────────────────────────────────────────────────
// MediaService — picks an "active" MPRIS player (prefers one that's playing,
// else the first available) and exposes simple transport controls. Used by the
// bar's MediaWidget.
// ─────────────────────────────────────────────────────────────────────────────
Singleton {
    id: root

    readonly property var players: Mpris.players ? Mpris.players.values : []

    readonly property var active: {
        const list = root.players
        for (let i = 0; i < list.length; i++)
            if (list[i] && list[i].isPlaying) return list[i]
        return list.length ? list[0] : null
    }

    readonly property bool hasPlayer: active !== null
    readonly property bool isPlaying: active ? active.isPlaying : false
    readonly property string title:  active ? (active.trackTitle || active.identity || "") : ""
    readonly property string artist: active ? (active.trackArtist || "") : ""
    readonly property string artUrl: active ? (active.trackArtUrl || "") : ""

    function toggle(): void { if (active && active.canTogglePlaying) active.togglePlaying() }
    function next(): void    { if (active && active.canGoNext) active.next() }
    function prev(): void    { if (active && active.canGoPrevious) active.previous() }
}
