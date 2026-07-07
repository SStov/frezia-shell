import QtQuick
import "../../core"
import "../../components"

Rectangle {
    id: ocrBtn
    property var bar
    width: 34; height: 30; radius: 15
    color: (bar && bar.isOcrOpen) ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.6) : "transparent"
    scale: ocrMouse.pressed ? 0.85 : (ocrMouse.containsMouse ? 1.1 : 1.0)
    StyledText { anchors.centerIn: parent; text: ""; color: Colors.fg; font.pixelSize: 18 }
    MouseArea {
        id: ocrMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: parent.color = Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4)
        onExited: if(bar && !bar.isOcrOpen) parent.color = "transparent"
        onClicked: {
            if (bar) {
                let pos = mapToItem(bar, width / 2, 0)
                bar.isOcrOpen = !bar.isOcrOpen;
                bar.toggleOcr(pos.x);
            }
        }
    }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
