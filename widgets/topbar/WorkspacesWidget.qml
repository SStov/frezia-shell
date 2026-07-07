import QtQuick
import Quickshell
import Quickshell.Io
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

            // Строгая физика ширины для контейнера (без желе)
            width: (isActive || isUrgent) ? 25 : 12
            height: 12
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }

            Rectangle {
                anchors.centerIn: parent
                height: 12
                // Визуальная пластичная ширина (с желе!)
                width: (isActive || isUrgent) ? 25 : 12
                radius: 6

                // Алый цвет для urgent состояний, иначе стандартная тема
                color: isUrgent ? Colors.red : (isActive ? Colors.accentBlue : (hasWindows ? Qt.rgba(Colors.textMain.r, Colors.textMain.g, Colors.textMain.b, 0.5) : Qt.rgba(Colors.textSub.r, Colors.textSub.g, Colors.textSub.b, 0.35)))

                Behavior on width { SpringAnimation { spring: 2.0; damping: 0.4; mass: 0.9 } }
                Behavior on color { ColorAnimation { duration: 150 } }
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
