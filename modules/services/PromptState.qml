pragma Singleton

import QtQuick
import Quickshell

// Global password-prompt state. UI surfaces request a password; PasswordDialog
// displays the prompt and reports the result back through this singleton.
Singleton {
    id: root

    property string pendingSsid: ""
    property bool visible: false

    signal passwordEntered(string ssid, string password)
    signal cancelled(string ssid)

    function requestPassword(ssid): void {
        root.pendingSsid = ssid
        root.visible = true
    }

    function submit(password): void {
        const ssid = root.pendingSsid
        root.visible = false
        root.pendingSsid = ""
        if (ssid.length) root.passwordEntered(ssid, password)
    }

    function cancel(): void {
        const ssid = root.pendingSsid
        root.visible = false
        root.pendingSsid = ""
        if (ssid.length) root.cancelled(ssid)
    }
}
