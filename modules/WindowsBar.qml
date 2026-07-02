import QtQuick
import Quickshell

Variants {
    // Bar lives on a single monitor (the laptop panel) instead of one per
    // screen. Re-evaluates when screens change, so plugging/unplugging an
    // external display won't spawn a second bar. Falls back to the first
    // available screen so we're never left bar-less if LVDS-1 is absent.
    model: {
        const want = "LVDS-1"
        const all = Quickshell.screens
        for (let i = 0; i < all.length; i++)
            if (all[i].name === want) return [all[i]]
        return all.length > 0 ? [all[0]] : []
    }

    Scope {
        required property ShellScreen modelData

        WindowsBarScreen {
            screen: modelData
        }
    }
}
