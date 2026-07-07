import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"
import "../components"

PanelWindow {
    id: previewWindow
    
    WlrLayershell.namespace: "qs-wspreview"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    
    color: "transparent"
    
    property int targetWsId: -1
    property bool isOpen: false
    property real targetX: 0
    property real targetY: 0
    
    anchors {
        top: targetY >= 0
        bottom: targetY < 0
        left: true
    }
    
    margins {
        top: targetY >= 0 ? targetY : 0
        bottom: targetY < 0 ? -targetY : 0
        left: targetX
    }
    
    implicitWidth: contentRect.width
    implicitHeight: contentRect.height
    
    visible: isOpen
    
    onIsOpenChanged: {
        if (isOpen) updateClients()
    }
    onTargetWsIdChanged: {
        if (isOpen) updateClients()
    }
    
    ListModel { id: clientsModel }
    
    Process {
        id: fetchClientsProcess
        command: ["mmsg", "get", "all-clients"]

        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                try {
                    let resp = JSON.parse(this.text);
                    let allClients = resp.clients || [];
                    clientsModel.clear();
                    for (let i = 0; i < allClients.length; i++) {
                        let client = allClients[i];
                        // MangoWM tags возвращает массив индексов тегов
                        if (client.tags && client.tags.indexOf(previewWindow.targetWsId) !== -1) {
                            clientsModel.append({
                                "clientTitle": client.title || "Без названия",
                                "clientClass": client.appid || "unknown"
                            });
                        }
                    }
                } catch(e) {
                    console.log("Error parsing mmsg all-clients:", e);
                }
            }
        }
    }

    function updateClients() {
        clientsModel.clear()
        if (targetWsId === -1) return;
        
        fetchClientsProcess.running = false
        fetchClientsProcess.running = true
    }
    
    Rectangle {
        id: contentRect
        width: Math.max(180, listCol.implicitWidth + 30)
        height: listCol.implicitHeight + 30
        radius: 14
        
        color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, 0.95)
        clip: true
        
        opacity: previewWindow.isOpen ? 1.0 : 0.0
        scale: previewWindow.isOpen ? 1.0 : 0.95
        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        
        ColumnLayout {
            id: listCol
            anchors.centerIn: parent
            spacing: 8
            
            Repeater {
                model: clientsModel
                delegate: RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    
                    Rectangle {
                        width: 24; height: 24; radius: 6; color: "transparent"
                        Image {
                            anchors.fill: parent
                            source: model.clientClass !== "" ? "image://icon/" + model.clientClass : ""
                            sourceSize: Qt.size(24, 24)
                            visible: status === Image.Ready
                        }
                        StyledText {
                            anchors.centerIn: parent; text: "󰀲"
                            color: Colors.textSub; font.pixelSize: 16
                            visible: parent.children[0].status !== Image.Ready
                        }
                    }
                    
                    StyledText {
                        text: model.clientTitle
                        color: Colors.textMain
                        font.pixelSize: 13
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                        Layout.maximumWidth: 220
                    }
                }
            }
            
            StyledText {
                text: "Нет открытых окон"
                color: Colors.textSub
                font.pixelSize: 13
                Layout.alignment: Qt.AlignHCenter
                visible: clientsModel.count === 0
            }
        }
    }
}