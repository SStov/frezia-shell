import QtQuick
import "../../core"
import "../../components"

Rectangle {
    id: layoutBtn
    property var bar
    width: 34; height: 30; radius: 15
    color: layoutMouse.containsMouse ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4) : "transparent"
    scale: layoutMouse.pressed ? 0.85 : (layoutMouse.containsMouse ? 1.1 : 1.0)
    StyledText { 
        anchors.centerIn: parent
        text: bar ? bar.currentLayout : "US"
        color: Colors.fg
        font.pixelSize: 12
        font.bold: true
    }
    MouseArea {
        id: layoutMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (bar) {
                bar.switchLayout()
            }
        }
    }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
