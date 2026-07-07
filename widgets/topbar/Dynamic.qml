import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import "../../core"
import "../../components"
import ".."
import "."

Item {
    id: dynamicRoot
    anchors.fill: parent
    property var bar

    // ==========================================
    // ЛЕВЫЙ БЛОК: ВОРКСПЕЙСЫ
    // ==========================================
    RowLayout {
        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        
        Rectangle {
            id: wsBackground
            Layout.preferredHeight: 32
            Layout.preferredWidth: wsRow.implicitWidth + 24
            radius: 16
            color: Colors.card
            border.width: 1
            border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
            
            RowLayout {
                id: wsRow
                anchors.centerIn: parent
                spacing: 6
                
                Repeater {
                    model: 9
                    Item {
                        id: wsItem
                        readonly property int wsId: modelData + 1
                        readonly property var tagState: (dynamicRoot.bar && dynamicRoot.bar.tagStates) ? (dynamicRoot.bar.tagStates[wsId] || { is_active: false, is_urgent: false, client_count: 0 }) : { is_active: false, is_urgent: false, client_count: 0 }
                        readonly property bool isActive: tagState.is_active
                        readonly property bool hasWindows: tagState.client_count > 0
                        readonly property bool isUrgent: tagState.is_urgent
                        readonly property bool isHovered: wsMouse.containsMouse
                        
                        Layout.preferredWidth: isActive ? 32 : (hasWindows ? 12 : 12)
                        Layout.preferredHeight: 12
                        
                        Rectangle {
                            anchors.centerIn: parent
                            width: parent.width
                            height: parent.height
                            radius: 6
                            color: isUrgent ? Colors.error : (isActive ? Colors.accentBlue : (hasWindows ? Colors.textMain : Qt.rgba(Colors.textSub.r, Colors.textSub.g, Colors.textSub.b, 0.3)))
                            
                            Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                            Behavior on color { ColorAnimation { duration: 200 } }
                            
                            // Subtle shadow for active workspace
                            layer.enabled: isActive
                            layer.effect: Component { MultiEffect { shadowEnabled: true; shadowColor: Qt.rgba(0,0,0,0.3); shadowBlur: 0.5; shadowVerticalOffset: 2 } }
                        }
                        
                        StyledText {
                            anchors.centerIn: parent
                            text: wsId
                            font.pixelSize: 10
                            font.family: "Outfit Medium"
                            color: Colors.bg
                            visible: isActive
                            opacity: isActive ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                        
                        // Tooltip for non-active workspaces
                        Rectangle {
                            anchors.bottom: parent.top
                            anchors.bottomMargin: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 24; height: 24; radius: 12
                            color: Colors.card
                            border.width: 1
                            border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
                            visible: isHovered && !isActive
                            opacity: isHovered && !isActive ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                            
                            StyledText {
                                anchors.centerIn: parent
                                text: wsId
                                font.pixelSize: 11
                                font.family: "Outfit Medium"
                                color: Colors.textMain
                            }
                        }
                        
                        MouseArea {
                            id: wsMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                let p = Qt.createQmlObject('import Quickshell.Io; Process { command: ["mmsg", "dispatch", "view," + ' + wsId + '] }', wsItem)
                                p.running = true
                                p.onRunningChanged = function() { if(!p.running) p.destroy() }
                            }
                            onEntered: { if (dynamicRoot.bar) dynamicRoot.bar.showWorkspacePreview(wsId, mapToItem(dynamicRoot.bar, 0, 0).x) }
                            onExited: { if (dynamicRoot.bar) dynamicRoot.bar.hideWorkspacePreview() }
                        }
                    }
                }
            }
        }
    }

    // ==========================================
    // ЦЕНТРАЛЬНЫЙ БЛОК: DYNAMIC ISLAND
    // ==========================================
    RowLayout {
        anchors.centerIn: parent
        
        Rectangle {
            id: dynamicIsland
            Layout.preferredHeight: 32
            
            readonly property bool isMusic: MediaService.currentPlayer !== null && MediaService.trackTitle !== ""
            readonly property bool isHovered: islandMouse.containsMouse
            readonly property int baseWidth: 100
            readonly property int musicWidth: 200
            readonly property int expandedMusicWidth: 320
            readonly property int expandedBaseWidth: 160
            
            Layout.preferredWidth: isHovered ? (isMusic ? expandedMusicWidth : expandedBaseWidth) : (isMusic ? musicWidth : baseWidth)
            radius: 16
            color: Colors.card
            border.width: 1
            border.color: isHovered ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.4) : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
            
            Behavior on Layout.preferredWidth { SpringAnimation { spring: 3; damping: 0.6; mass: 0.8 } }
            Behavior on border.color { ColorAnimation { duration: 200 } }
            
            Item {
                anchors.fill: parent
                anchors.margins: 4
                
                // РЕЖИМ БЕЗ МУЗЫКИ (Часы и дата)
                RowLayout {
                    anchors.fill: parent
                    visible: !dynamicIsland.isMusic
                    spacing: 8
                    
                    StyledText {
                        text: Qt.formatDateTime(new Date(), "HH:mm")
                        font.pixelSize: 13
                        font.family: "Outfit Medium"
                        color: Colors.textMain
                        Layout.alignment: Qt.AlignHCenter
                        Timer { interval: 1000; running: true; repeat: true; onTriggered: parent.text = Qt.formatDateTime(new Date(), "HH:mm") }
                    }
                    
                    StyledText {
                        text: Qt.formatDateTime(new Date(), "dddd, MMMM d")
                        font.pixelSize: 12
                        font.family: "Outfit"
                        color: Colors.textSub
                        visible: dynamicIsland.isHovered
                        opacity: dynamicIsland.isHovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        Layout.fillWidth: true
                    }
                }
                
                // РЕЖИМ С МУЗЫКОЙ
                RowLayout {
                    anchors.fill: parent
                    visible: dynamicIsland.isMusic
                    spacing: 8
                    
                    Rectangle {
                        width: 24; height: 24; radius: 12
                        clip: true
                        color: Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2)
                        Layout.leftMargin: 2
                        
                        Image {
                            source: MediaService.trackArtUrl
                            anchors.fill: parent
                            fillMode: Image.PreserveAspectCrop
                            visible: MediaService.trackArtUrl !== ""
                        }
                        
                        StyledText {
                            anchors.centerIn: parent
                            text: "󰎆"
                            font.pixelSize: 12
                            color: Colors.accentBlue
                            visible: MediaService.trackArtUrl === ""
                        }
                        
                        RotationAnimation on rotation {
                            running: MediaService.isPlaying
                            loops: Animation.Infinite
                            from: 0; to: 360; duration: 10000
                        }
                    }
                    
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        
                        StyledText {
                            text: MediaService.trackTitle
                            font.pixelSize: 11
                            font.family: "Outfit Medium"
                            color: Colors.textMain
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                        
                        StyledText {
                            text: MediaService.trackArtist
                            font.pixelSize: 9
                            font.family: "Outfit"
                            color: Colors.textSub
                            visible: dynamicIsland.isHovered
                            opacity: dynamicIsland.isHovered ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }
                    }
                    
                    // Эквалайзер (когда не наведено)
                    Row {
                        visible: !dynamicIsland.isHovered && MediaService.isPlaying
                        spacing: 2
                        Layout.rightMargin: 8
                        Layout.alignment: Qt.AlignVCenter
                        Repeater {
                            model: 3
                            Rectangle {
                                id: vbar
                                width: 2; height: 10
                                radius: 1; color: Colors.accentBlue
                                Timer {
                                    interval: 150
                                    running: MediaService.isPlaying && !dynamicIsland.isHovered
                                    repeat: true
                                    onTriggered: vbar.height = 4 + Math.random() * 8
                                }
                                Behavior on height { NumberAnimation { duration: 150; easing.type: Easing.InOutQuad } }
                            }
                        }
                    }
                    
                    // Контролы (когда наведено)
                    RowLayout {
                        visible: dynamicIsland.isHovered
                        opacity: dynamicIsland.isHovered ? 1 : 0
                        Behavior on opacity { NumberAnimation { duration: 200 } }
                        spacing: 6
                        Layout.rightMargin: 4
                        
                        component CBtn: Rectangle {
                            property string txt: ""
                            signal clicked()
                            width: 24; height: 24; radius: 12
                            color: cbMa.containsMouse ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.15) : "transparent"
                            scale: cbMa.pressed ? 0.9 : 1.0
                            Behavior on color { ColorAnimation { duration: 150 } }
                            Behavior on scale { NumberAnimation { duration: 150 } }
                            StyledText {
                                anchors.centerIn: parent
                                text: parent.txt
                                font.pixelSize: 12
                                color: cbMa.containsMouse ? Colors.accentBlue : Colors.textSub
                            }
                            MouseArea {
                                id: cbMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: parent.clicked()
                            }
                        }
                        
                        CBtn { txt: "󰒮"; onClicked: MediaService.previous() }
                        CBtn { txt: MediaService.isPlaying ? "󰏤" : "󰐊"; onClicked: MediaService.playPause() }
                        CBtn { txt: "󰒭"; onClicked: MediaService.next() }
                    }
                }
            }
            
            // Тонкий прогресс-бар внизу капсулы
            Rectangle {
                height: 2
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.right: parent.right
                color: Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2)
                visible: dynamicIsland.isMusic && dynamicIsland.isHovered
                radius: 1
                clip: true
                
                Rectangle {
                    height: parent.height
                    width: parent.width * (MediaService.trackLength > 0 ? (MediaService.currentPosition / MediaService.trackLength) : 0)
                    color: Colors.accentBlue
                    radius: 1
                }
            }
            
            MouseArea {
                id: islandMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (dynamicRoot.bar && !dynamicIsland.isMusic) {
                        dynamicRoot.bar.toggleCalendar(mapToItem(dynamicRoot.bar, width/2, 0).x)
                    } else if (dynamicRoot.bar && dynamicIsland.isMusic) {
                        dynamicRoot.bar.toggleMediaPlayer(mapToItem(dynamicRoot.bar, width/2, 0).x)
                    }
                }
            }
        }
    }

    // ==========================================
    // ПРАВЫЙ БЛОК: DOCK ИЗ ТРЕЯ И КОНТРОЛОВ
    // ==========================================
    RowLayout {
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        
        Rectangle {
            id: dockBackground
            Layout.preferredHeight: 32
            Layout.preferredWidth: dockRow.implicitWidth + 24
            radius: 16
            color: Colors.card
            border.width: 1
            border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
            
            RowLayout {
                id: dockRow
                anchors.centerIn: parent
                spacing: 8
                
                // Системный трей
                SystemTrayWidget {
                    id: trayInstance
                    bar: dynamicRoot.bar
                    Layout.alignment: Qt.AlignVCenter
                }
                
                // Раскладка клавиатуры
                Rectangle {
                    width: 26; height: 26; radius: 13
                    color: langMa.containsMouse ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.15) : "transparent"
                    Layout.alignment: Qt.AlignVCenter
                    
                    StyledText {
                        anchors.centerIn: parent
                        text: (dynamicRoot.bar ? dynamicRoot.bar.currentLayout : "US").substring(0, 2)
                        font.pixelSize: 11
                        font.family: "Outfit Medium"
                        color: langMa.containsMouse ? Colors.accentBlue : Colors.textMain
                    }
                    MouseArea {
                        id: langMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if(dynamicRoot.bar) dynamicRoot.bar.switchLayout()
                    }
                    Behavior on color { ColorAnimation { duration: 150 } }
                }
                
                Rectangle {
                    Layout.preferredWidth: 1
                    Layout.preferredHeight: 14
                    color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
                    Layout.alignment: Qt.AlignVCenter
                }
                
                // Сетка быстрых настроек
                RowLayout {
                    spacing: 4
                    
                    component WhiskerIconButton: Rectangle {
                        id: btn
                        property string iconText: ""
                        property bool active: false
                        property color activeBg: Colors.accentBlue
                        property color activeFg: Colors.bg
                        signal clicked()
                        
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 26
                        radius: 13
                        
                        property color bgDefault: "transparent"
                        property color bgHovered: Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.15)
                        property color bgPressed: Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.25)
                        
                        color: active ? activeBg : (btnArea.pressed ? bgPressed : (btnArea.containsMouse ? bgHovered : bgDefault))
                        scale: btnArea.pressed ? 0.85 : (btnArea.containsMouse ? 1.05 : 1.0)
                        
                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on scale { SpringAnimation { spring: 4; damping: 0.5; mass: 0.8 } }
                        
                        StyledText {
                            anchors.centerIn: parent
                            text: btn.iconText
                            font.pixelSize: 14
                            color: btn.active ? btn.activeFg : Colors.textMain
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }
                        
                        MouseArea {
                            id: btnArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: btn.clicked()
                        }
                    }
                    
                    WhiskerIconButton {
                        iconText: "󰆚"
                        active: dynamicRoot.bar && dynamicRoot.bar.isCalcOpen
                        onClicked: if(dynamicRoot.bar) dynamicRoot.bar.toggleCalc(mapToItem(dynamicRoot.bar, width/2, 0).x)
                    }
                    WhiskerIconButton {
                        iconText: "󰆒"
                        active: dynamicRoot.bar && dynamicRoot.bar.isClipboardOpen
                        onClicked: if(dynamicRoot.bar) dynamicRoot.bar.toggleClipboard(mapToItem(dynamicRoot.bar, width/2, 0).x)
                    }
                    WhiskerIconButton {
                        iconText: "󰕮"
                        active: dynamicRoot.bar && dynamicRoot.bar.isNotifCenterOpen
                        onClicked: if(dynamicRoot.bar) dynamicRoot.bar.toggleNotificationCenter()
                    }
                    WhiskerIconButton {
                        iconText: ""
                        active: dynamicRoot.bar && dynamicRoot.bar.isTamagotchiOpen
                        onClicked: if(dynamicRoot.bar) dynamicRoot.bar.toggleTamagotchi(mapToItem(dynamicRoot.bar, width/2, 0).x)
                    }
                    WhiskerIconButton {
                        iconText: ""
                        active: dynamicRoot.bar && dynamicRoot.bar.isSysMenuOpen
                        onClicked: if(dynamicRoot.bar) dynamicRoot.bar.toggleSysMenu(mapToItem(dynamicRoot.bar, width/2, 0).x)
                    }
                    WhiskerIconButton {
                        iconText: ""
                        active: dynamicRoot.bar && dynamicRoot.bar.isPowerOpen
                        activeBg: Colors.error
                        activeFg: Colors.textMain
                        bgHovered: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2)
                        bgPressed: Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.35)
                        onClicked: if(dynamicRoot.bar) dynamicRoot.bar.togglePower(mapToItem(dynamicRoot.bar, width/2, 0).x)
                    }
                }
            }
        }
    }
}
