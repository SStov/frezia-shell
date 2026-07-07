import QtQuick
import "../../core"
import "../../components"

Rectangle {
    id: tamaBtn
    property var bar
    width: 34; height: 30; radius: 15
    color: (bar && bar.isTamagotchiOpen) ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.6) : "transparent"
    scale: tamaMouse.pressed ? 0.85 : (tamaMouse.containsMouse ? 1.1 : 1.0)
    StyledText { anchors.centerIn: parent; text: ""; color: Colors.fg; font.pixelSize: 16 }
    MouseArea {
        id: tamaMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onEntered: parent.color = Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4)
        onExited: if(bar && !bar.isTamagotchiOpen) parent.color = "transparent"
        onClicked: {
            if (bar) {
                let pos = mapToItem(bar, width / 2, 0)
                bar.isTamagotchiOpen = !bar.isTamagotchiOpen;
                bar.toggleTamagotchi(pos.x);
            }
        }
    }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
