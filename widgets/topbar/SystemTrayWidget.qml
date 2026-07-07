import QtQuick
import Quickshell.Services.SystemTray
import Qt5Compat.GraphicalEffects
import "../../core"
import "../../components"

Row {
    id: trayRow
    property var bar
    spacing: 8

    Repeater {
        id: trayRepeater
        model: SystemTray.items.values

        delegate: Rectangle {
            width: 28
            height: 28
            radius: 6
            color: trayMouse.containsMouse ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2) : "transparent"
            Behavior on color { ColorAnimation { duration: 150 } }

            Image {
                id: trayIconImg
                anchors.centerIn: parent
                width: 20
                height: 20
                sourceSize: Qt.size(20, 20)
                source: modelData.icon ? modelData.icon : ""
                fillMode: Image.PreserveAspectFit
                smooth: true
                visible: status === Image.Ready || status === Image.Loading
                layer.enabled: true
                layer.effect: ColorOverlay {
                    color: Colors.fg
                }
            }

            MouseArea {
                id: trayMouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: (mouse) => {
                    if (bar) {
                        if (mouse.button === Qt.LeftButton) {
                            modelData.activate();
                        } else if (mouse.button === Qt.MiddleButton) {
                            modelData.secondaryActivate();
                        } else if (mouse.button === Qt.RightButton) {
                            if (modelData.hasMenu) {
                                let pos = mapToItem(bar, width / 2, 0);
                                bar.toggleTrayMenu(pos.x, modelData.menu);
                            }
                        }
                    }
                }
            }
        }
    }
}
