import QtQuick
import "../../core"
import "../../components"

Rectangle {
    id: calcBtn
    property var bar
    width: 34; height: 30; radius: 15
    color: (bar && bar.isCalcOpen) ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.6) : (calcMouse.containsMouse ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4) : "transparent")
    scale: calcMouse.pressed ? 0.85 : (calcMouse.containsMouse ? 1.1 : 1.0)
    StyledText { anchors.centerIn: parent; text: "󰃬"; color: Colors.fg; font.pixelSize: 18 }
    MouseArea {
        id: calcMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (bar) {
                let pos = mapToItem(bar, width / 2, 0)
                bar.toggleCalc(pos.x)
            }
        }
    }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
