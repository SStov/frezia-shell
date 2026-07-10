import QtQuick
import "../../core"
import "../../components"

Rectangle {
    id: powerBtn
    property var bar
    width: 34; height: 30; radius: 15
    color: (bar && bar.isPowerOpen) ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.3) : (powerMouse.containsMouse ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2) : "transparent")
    scale: powerMouse.pressed ? 0.85 : (powerMouse.containsMouse ? 1.1 : 1.0)
    StyledText { anchors.centerIn: parent; text: "󰐥"; color: (bar && bar.isPowerOpen) ? Colors.error : Colors.fg; font.pixelSize: 18 }
    MouseArea {
        id: powerMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (bar) {
                let pos = mapToItem(bar, width / 2, 0)
                bar.togglePower(pos.x)
            }
        }
    }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
