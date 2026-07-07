import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import QtQuick.Effects
import "../core"

PanelWindow {
    id: vinylWidget

    WlrLayershell.namespace: "qs-desktop-widget"
    WlrLayershell.layer: WlrLayer.Bottom
    
    anchors {
        bottom: true
        right: true
        bottomMargin: 80
        rightMargin: 40
    }

    width: 320
    height: 110
    color: "transparent"

    // 🌟 ГЛАВНЫЙ КОНТЕЙНЕР (Он и будет плавно растворяться)
    Item {
        id: rootContent
        anchors.fill: parent
        
        // Показываем, только если плеер запущен
        opacity: MediaService.currentPlayer !== null ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

        // ==========================================
        // 🌟 1. МАГИЧЕСКАЯ АУРА (РАЗЛИВАЕТСЯ ВОКРУГ)
        // ==========================================
        Image {
            id: hiddenArt
            source: MediaService.trackArtUrl
            anchors.fill: parent
            visible: false 
        }

        MultiEffect {
            id: aura
            source: hiddenArt
            anchors.fill: parent
            anchors.margins: -60 
            blurEnabled: true
            blurMax: 80
            blur: 1.0
            
            opacity: MediaService.isPlaying ? 0.4 : 0.1 
            Behavior on opacity { NumberAnimation { duration: 800 } }

            SequentialAnimation on scale {
                loops: Animation.Infinite
                running: MediaService.isPlaying
                NumberAnimation { to: 1.08; duration: 2500; easing.type: Easing.InOutSine }
                NumberAnimation { to: 0.96; duration: 2500; easing.type: Easing.InOutSine }
            }
        }

        // ==========================================
        // 🌟 2. МАТОВАЯ ПИЛЮЛЯ (ФОН)
        // ==========================================
        Rectangle {
            anchors.fill: parent
            anchors.margins: 10
            radius: height / 2 
            
            color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, 0.5)
            border.color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.4)
            border.width: 1 * Theme.borderWidth

            RowLayout {
                anchors.fill: parent
                anchors.margins: 6
                spacing: 15

                // ==========================================
                // 🌟 3. ВРАЩАЮЩИЙСЯ ВИНИЛ
                // ==========================================
                Item {
                    Layout.preferredWidth: 80
                    Layout.preferredHeight: 80
                    Layout.alignment: Qt.AlignVCenter
                    
                    Rectangle {
                        id: vinylRecord
                        anchors.centerIn: parent
                        width: 80
                        height: 80
                        radius: 40
                        color: "#0f0f0f" 
                        border.color: "#262626"
                        border.width: 1
                        clip: true

                        RotationAnimation on rotation {
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 4000 
                            running: MediaService.isPlaying
                        }

                        Rectangle { anchors.centerIn: parent; width: 64; height: 64; radius: 32; border.color: "#1a1a1a"; border.width: 1; color: "transparent" }
                        Rectangle { anchors.centerIn: parent; width: 48; height: 48; radius: 24; border.color: "#1a1a1a"; border.width: 1; color: "transparent" }

                        Rectangle {
                            anchors.centerIn: parent
                            width: 32
                            height: 32
                            radius: 16
                            clip: true
                            color: Colors.bg

                            Image {
                                anchors.fill: parent
                                source: MediaService.trackArtUrl
                                fillMode: Image.PreserveAspectCrop
                                visible: MediaService.trackArtUrl !== ""
                            }
                            
                            Rectangle {
                                anchors.centerIn: parent
                                width: 6
                                height: 6
                                radius: 3
                                color: "#0f0f0f" 
                                border.color: "#333333"
                                border.width: 1
                            }
                        }
                    }
                }

                // ==========================================
                // 🌟 4. ИНФА О ТРЕКЕ
                // ==========================================
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    spacing: 2

                    Text {
                        text: MediaService.trackTitle || "Тишина..."
                        color: Colors.textMain
                        font.pixelSize: 15
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                    Text {
                        text: MediaService.trackArtist || "Включи музыку"
                        color: Colors.textSub
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
                
                Item { Layout.preferredWidth: 15 } 
            }
        }
    }
}