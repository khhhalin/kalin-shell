import QtQuick
import "."
import "../services"

// Hover/click trigger for the docked bluetuith panel (see ../DockedPanel.qml,
// instantiated in BottomBar.qml); icon is driven by BluetoothStatus.
Item {
    id: root

    property bool active: false
    property alias hovered: tui.hovered

    signal clicked()

    implicitWidth: tui.implicitWidth
    implicitHeight: tui.implicitHeight

    TuiLauncherWidget {
        id: tui
        anchors.fill: parent
        tabName: "bluetooth"
        icon: BluetoothStatus.icon
        active: root.active

        onClicked: root.clicked()
    }
}
