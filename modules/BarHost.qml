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
    // only argument (nested test sessions iterating ahead of the packaged
    // wrapper). Unset = kalin-bar-kitty from home-config/desktop.nix, which
    // owns the kitty options and the absolute-python-path launch.
    readonly property string devWrap: Quickshell.env("KALIN_BAR_WRAP") ?? ""
    readonly property var barCommand: devWrap !== ""
        ? [devWrap, host.appId]
        : ["kalin-bar-kitty", host.appId]

    implicitHeight: heightHint
    color: "transparent"

    anchors {
        left: true
        right: true
        bottom: true
    }

    exclusiveZone: implicitHeight
    exclusionMode: ExclusionMode.Auto

    // Empty input region: this surface exists only to reserve the strip, but
    // it sits in the Top layer directly over the docked kitty — without the
    // mask it silently ate every click meant for the bar TUI (found in the
    // nested gate: taskbar/panel clicks never arrived).
    mask: Region {}

    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "windows-bar:bar-host"

    Process {
        id: proc
        // The bar TUI needs its output's name to place docked panels on the
        // right monitor (see bar.py's KALIN_BAR_OUTPUT).
        environment: ({ KALIN_BAR_OUTPUT: host.screen.name })
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
            // host.width (this anchored PanelWindow's real width), NOT
            // screen.width: at boot the QML screen object can lag the actual
            // mode (the VM gate found the bar docked at the fallback 640 for
            // good), while the layer surface itself is resized by the
            // compositor to the true output width.
            KalinViewport.dock(host.appId, host.stripX, host.stripY,
                               host.width, host.heightHint)
        }
    }

    function _spawn(): void {
        // Arm the strip rect before spawning so the bar's first-ever frame is
        // already docked (no flash at a floating position).
        KalinViewport.dockPrep(host.appId, host.stripX, host.stripY,
                               host.width, host.heightHint)
        proc.command = host.barCommand
        proc.running = true
        dockSettle.remaining = 60
        dockSettle.restart()
    }

    // Don't spawn until the QML screen object is actually populated: at
    // (nested) startup BarHost can be created while screen.name is still ""
    // and width is a fallback — the bar then docks under a truncated appid
    // ("kalin-bar-") at the wrong size, and the panel TUIs lose their output
    // key (KALIN_BAR_OUTPUT). Poll briefly instead of trusting creation-time
    // values.
    Timer {
        id: screenReady
        interval: 250
        repeat: true
        running: true
        onTriggered: {
            if (host.screen && host.screen.name !== "" && host.width > 0) {
                stop()
                host._spawn()
            }
        }
    }

    // Monitor geometry changes (boot mode settling, scale, hotplug
    // reposition) move/resize the strip: re-dock the running bar to fit.
    onStripYChanged: if (proc.running) { dockSettle.remaining = 10; dockSettle.restart() }
    onWidthChanged:  if (proc.running) { dockSettle.remaining = 10; dockSettle.restart() }
}
