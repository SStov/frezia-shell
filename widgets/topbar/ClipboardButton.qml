import QtQuick
import "../../core"
import "../../components"

Rectangle {
    id: clipBtn
    property var bar
    width: 34; height: 30; radius: 15
    color: (bar && bar.isClipboardOpen) ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.6) : (clipMouse.containsMouse ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4) : "transparent")
    scale: clipMouse.pressed ? 0.85 : (clipMouse.containsMouse ? 1.1 : 1.0)
    StyledText { anchors.centerIn: parent; text: "󰅌"; color: Colors.fg; font.pixelSize: 18 }
    MouseArea {
        id: clipMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (bar) {
                let pos = mapToItem(bar, width / 2, 0)
                bar.toggleClipboard(pos.x)
            }
        }
    }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
