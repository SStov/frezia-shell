import QtQuick
import "../../core"
import "../../components"

Rectangle {
    id: notifBtn
    property var bar
    width: 34; height: 30; radius: 15
    color: (bar && bar.isNotifCenterOpen) ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.6) : (notifMouse.containsMouse ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4) : "transparent")
    scale: notifMouse.pressed ? 0.85 : (notifMouse.containsMouse ? 1.1 : 1.0)
    StyledText { anchors.centerIn: parent; text: "󰂚"; color: Colors.fg; font.pixelSize: 18 }
    MouseArea {
        id: notifMouse
        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
        onClicked: {
            if (bar) {
                bar.toggleNotificationCenter()
            }
        }
    }
    Behavior on color { ColorAnimation { duration: 150 } }
    Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
}
