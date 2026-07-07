import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import "../core"
import "../components"

PanelWindow {
    id: notifOverlay
    
    WlrLayershell.layer: WlrLayer.Overlay 
    WlrLayershell.namespace: "qs-notifications"
    
    anchors {
        top: true
        right: true
    }
    margins {
        top: 20
        right: 20
    }
    
    implicitWidth: 350
    implicitHeight: notifList.count > 0 ? notifList.contentHeight : 0
    color: "transparent"

    // 1. Создаем генератор уникальных номерков
    property int notifCounter: 0 

    NotificationServer {
        id: server
        onNotification: n => {
            notifOverlay.notifCounter++
            let currentId = notifOverlay.notifCounter // Запоминаем номерок
            
            notifModel.insert(0, { 
                "notif": n,
                "nAppName": n.appName !== "" ? n.appName : (n.desktopEntry !== "" ? n.desktopEntry : "Уведомление"),
                "nSummary": n.summary,
                "nBody": n.body,
                "myId": currentId // <--- Кладем номерок в модель
            })
            
            // Дублируем в глобальную историю (боковую шторку)
            if (shellRoot && shellRoot.globalNotifModel) {
                let d = new Date();
                let timeStr = ("0" + d.getHours()).slice(-2) + ":" + ("0" + d.getMinutes()).slice(-2);
                shellRoot.globalNotifModel.insert(0, {
                    "notif": n,
                    "nAppName": n.appName !== "" ? n.appName : (n.desktopEntry !== "" ? n.desktopEntry : "Уведомление"),
                    "nSummary": n.summary,
                    "nBody": n.body,
                    "nTime": timeStr
                });
                // Ограничиваем историю 50 уведомлениями
                if (shellRoot.globalNotifModel.count > 50) {
                    shellRoot.globalNotifModel.remove(shellRoot.globalNotifModel.count - 1);
                }
            }
            
            if (notifModel.count > 3) {
                notifModel.remove(notifModel.count - 1)
            }
        }
    }

    ListModel {
        id: notifModel
    }

    ListView {
        id: notifList
        anchors.fill: parent
        model: notifModel
        spacing: 15
        
        add: Transition {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
            NumberAnimation { property: "x"; from: 100; to: 0; duration: 300; easing.type: Easing.OutBack }
        }
        
        remove: Transition {
            NumberAnimation { property: "opacity"; to: 0; duration: 200 }
            NumberAnimation { property: "x"; to: 100; duration: 200 }
        }

        delegate: Rectangle {
            width: notifList.width
            height: contentCol.height + 24
            color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, shellRoot ? shellRoot.qsOpacity : 0.95)
            radius: 15
            clip: true

            property var n: model.notif
            property int myId: model.myId // <--- Достаем номерок для этой карточки

            Timer {
                interval: 5000
                running: true
                onTriggered: {
                    if (n) { n.dismiss() }
                    // 2. Теперь ищем ЖЕЛЕЗНО по номерку
                    for (var i = 0; i < notifModel.count; i++) {
                        if (notifModel.get(i).myId === myId) {
                            notifModel.remove(i)
                            break
                        }
                    }
                }
            }

            Row {
                id: contentCol
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                    margins: 12
                }
                spacing: 12

                Rectangle {
                    width: 40; height: 40
                    radius: 10
                    color: Colors.card
                    StyledText {
                        anchors.centerIn: parent
                        text: "󰂚"
                        color: Colors.accentBlue
                        font.pixelSize: 20
                    }
                }

                Column {
                    width: parent.width - 52
                    spacing: 4
                    
                    StyledText {
                        text: model.nAppName
                        color: Colors.textSub
                        font.pixelSize: 12
                    }
                    StyledText {
                        text: model.nSummary
                        color: Colors.textMain
                        font.pixelSize: 14
                        font.bold: true
                        wrapMode: Text.Wrap
                        width: parent.width
                    }
                    StyledText {
                        text: model.nBody
                        color: Colors.textSub
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                        width: parent.width
                        visible: text !== ""
                    }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (n) { n.dismiss() }
                    for (var i = 0; i < notifModel.count; i++) {
                        if (notifModel.get(i).myId === myId) {
                            notifModel.remove(i)
                            break
                        }
                    }
                }
            }
        }
    }
}