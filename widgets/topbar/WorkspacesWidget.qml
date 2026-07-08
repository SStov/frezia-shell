import QtQuick
import Quickshell
import Quickshell.Io
import QtQuick.Effects
import "../../core"
import "../../components"

Row {
    id: wsRow
    property var bar

    leftPadding: 25
    rightPadding: 25
    spacing: 8
    
    Repeater {
        model: 9
        Item {
            id: wsItem
            readonly property int wsId: modelData + 1
            readonly property var tagState: (bar && bar.tagStates) ? (bar.tagStates[wsId] || { is_active: false, is_urgent: false, client_count: 0 }) : { is_active: false, is_urgent: false, client_count: 0 }
            readonly property bool isActive: tagState.is_active
            readonly property bool hasWindows: tagState.client_count > 0
            readonly property bool isUrgent: tagState.is_urgent
            readonly property string appIcon: (bar && bar.tagIcons) ? (bar.tagIcons[wsId] || "") : ""

            // Фиксированная высота контейнера, чтобы Row не прыгал
            height: 28
            width: targetSize
            
            readonly property real targetSize: (isActive || hasWindows) ? 28 : 10
            
            Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }

            Rectangle {
                anchors.centerIn: parent
                height: parent.width
                width: parent.width
                radius: parent.width / 2

                color: isActive ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2) : (hasWindows ? "transparent" : Qt.rgba(Colors.textSub.r, Colors.textSub.g, Colors.textSub.b, 0.4))
                
                border.width: isActive ? 1 : 0
                border.color: isActive ? Colors.accentBlue : "transparent"

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                Item {
                    anchors.centerIn: parent
                    width: 18
                    height: 18
                    visible: wsItem.hasWindows && wsItem.appIcon !== ""
                    
                    Rectangle {
                        id: wsMask
                        anchors.fill: parent
                        radius: width / 2
                        color: "black"
                        visible: false
                        layer.enabled: true
                    }
                    
                    Image {
                        id: wsIconImg
                        anchors.fill: parent
                        source: wsItem.appIcon !== "" ? "image://icon/" + wsItem.appIcon : ""
                        sourceSize: Qt.size(18, 18)
                        fillMode: Image.PreserveAspectCrop
                        visible: false
                    }
                    
                    MultiEffect {
                        source: wsIconImg
                        anchors.fill: parent
                        maskEnabled: true
                        maskSource: wsMask
                        visible: wsIconImg.status === Image.Ready
                    }
                }
                
                StyledText {
                    anchors.centerIn: parent
                    text: "󰀲"
                    color: isActive ? Colors.accentBlue : Colors.textMain
                    font.pixelSize: 14
                    visible: wsItem.hasWindows && wsIconImg.status !== Image.Ready
                }
            }

            // MangoWM: переключение тега через mmsg dispatch
            Process {
                id: wsDispatchProc
                function switchToTag(id) {
                    command = ["mmsg", "dispatch", "view," + id];
                    running = true;
                }
            }

            MouseArea {
                id: wsMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onEntered: {
                    if (bar) {
                        // Получаем точную X-координату кнопки относительно TopBar
                        let pos = mapToItem(bar, 0, 0)
                        bar.showWorkspacePreview(wsId, pos.x)
                    }
                }
                onExited: {
                    if (bar) {
                        bar.hideWorkspacePreview()
                    }
                }
                onClicked: wsDispatchProc.switchToTag(wsId)
            }

            scale: wsMouse.pressed ? 0.8 : (wsMouse.containsMouse ? 1.15 : 1.0)
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        }
    }
}
