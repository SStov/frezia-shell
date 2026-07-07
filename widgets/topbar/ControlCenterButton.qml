import QtQuick
import "../../core"
import "../../components"

Rectangle {
    id: sysBtn
    property var bar
    width: 90; height: 30; radius: 15
    color: (bar && bar.isSysMenuOpen) ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.6) 
           : (sysMouse.containsMouse ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4) : "transparent")
    scale: sysMouse.pressed ? 0.9 : (sysMouse.containsMouse ? 1.05 : 1.0)
    Row { anchors.centerIn: parent; spacing: 12; StyledText { text: " "; color: Colors.fg; font.pixelSize: 20 } }
    MouseArea {
        id: sysMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (bar) {
                let pos = mapToItem(bar, width / 2, 0)
                bar.toggleSysMenu(pos.x)
            }
        }
    }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
