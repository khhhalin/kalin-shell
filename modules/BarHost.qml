import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

import "./services"

// ─────────────────────────────────────────────────────────────────────────────
// BarHost — the TUI-bar replacement for BottomBar (gated by
// BarConfig.useTuiBar, see WindowsBarScreen.qml). The bar's *content* is a
// real kitty terminal running `kalin-bar-tui bar` (kitty: the taskbar draws
// raster app icons over the kitty graphics protocol — foot+sixel corrupts
// rows under Textual and ghostty needs OpenGL 4.3 this host lacks). QML's
// only remaining jobs, which a terminal cannot do for itself:
//   1. reserve the strip (this PanelWindow's exclusiveZone), and
//   2. spawn the kitty process and keep it docked into the strip via the
//      same dockprep/dock IPC the DockedPanel TUIs use — plus respawn it if
//      it dies, mirroring DockedPanel's onExited self-heal.
// The PanelWindow itself stays fully transparent: the docked kitty toplevel
// is the visible bar.
// ─────────────────────────────────────────────────────────────────────────────
PanelWindow {
    id: host

    property int heightHint: BarConfig.barHeight

    readonly property string appId: "kalin-bar-" + host.screen.name

    // Strip rect in layout coordinates (same space the dock IPC expects).
    readonly property int stripX: host.screen.x
    readonly property int stripY: host.screen.y + host.screen.height - host.heightHint

    // Dev hook: KALIN_BAR_WRAP points at a script taking the app_id as its
    // only argument (used by nested test sessions where kitty/textual-image
    // aren't packaged yet). Unset = the packaged command.
    readonly property string devWrap: Quickshell.env("KALIN_BAR_WRAP") ?? ""
    readonly property var barCommand: devWrap !== ""
        ? [devWrap, host.appId]
        : ["kitty",
           "--config", "NONE",
           "--class=" + host.appId,
           "-o", "background=#1e1915",       // must equal Theme.bar / foot bg
           "-o", "background_opacity=0.88",  // kitty's matching-alpha semantics equal foot's
           "-o", "font_size=11",
           "-o", "font_family=JetBrainsMono Nerd Font",
           "kalin-bar-tui", "bar"]

    implicitHeight: heightHint
    color: "transparent"

    anchors {
        left: true
        right: true
        bottom: true
    }

    exclusiveZone: implicitHeight
    exclusionMode: ExclusionMode.Auto

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "windows-bar:bar-host"

    Process {
        id: proc
        // The bar must always exist: a crashed/quit bar TUI respawns after a
        // short beat (unlike DockedPanel, which just forgets the spawn until
        // the next hover — nobody hovers a dead bar back to life).
        onExited: function (exitCode, exitStatus) {
            respawnDelay.restart()
        }
    }

    Timer {
        id: respawnDelay
        interval: 2000   // breathing room so a crash-looping bar can't spin the CPU
        repeat: false
        onTriggered: host._spawn()
    }

    // The dock must hold even through a slow cold start (nix-shell dev wrap
    // has been observed taking >15s to first map): re-assert the dock rect
    // once a second until it sticks. Opposite polarity of DockedPanel's
    // lateSpawnSettle, which re-asserts *hidden* — the bar re-asserts
    // *visible*. Idempotent once docked.
    Timer {
        id: dockSettle
        interval: 1000
        repeat: true
        property int remaining: 0
        onTriggered: {
            if (remaining-- <= 0) {
                stop()
                return
            }
            KalinViewport.dock(host.appId, host.stripX, host.stripY,
                               host.screen.width, host.heightHint)
        }
    }

    function _spawn(): void {
        // Arm the strip rect before spawning so the bar's first-ever frame is
        // already docked (no flash at a floating position).
        KalinViewport.dockPrep(host.appId, host.stripX, host.stripY,
                               host.screen.width, host.heightHint)
        proc.command = host.barCommand
        proc.running = true
        dockSettle.remaining = 60
        dockSettle.restart()
    }

    Component.onCompleted: _spawn()

    // Monitor geometry changes (mode/scale/hotplug reposition) move the
    // strip: re-dock the running bar into the new rect.
    onStripYChanged: if (proc.running) dockSettle.restart()
}
