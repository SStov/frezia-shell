import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import "../core"
import "../components"

PanelWindow {
    id: vinylWidget

    WlrLayershell.namespace: "qs-desktop-widget"
    WlrLayershell.layer: WlrLayer.Bottom
    
    anchors {
        bottom: true
        right: true
    }
    margins {
        bottom: 80
        right: 40
    }

    implicitWidth: 340
    implicitHeight: 104
    color: "transparent"

    property var playersList: Mpris.players.values
    property var player: playersList.length > 0 ? playersList[0] : null
    property bool isPlaying: player && player.playbackState === 1
    
    // Свойство для хранения обложки
    property string trackArt: ""

    // Изолируем обновление обложки через Connections, чтобы старая картинка 
    // не пропадала, пока плеер на миллисекунду передает пустой URL
    Connections {
        target: vinylWidget.player
        function onTrackArtUrlChanged() {
            if (vinylWidget.player && vinylWidget.player.trackArtUrl !== "") {
                vinylWidget.trackArt = vinylWidget.player.trackArtUrl
            }
        }
    }

    // Инициализация при появлении/смене плеера
    onPlayerChanged: {
        if (player && player.trackArtUrl) {
            trackArt = player.trackArtUrl
        } else {
            trackArt = ""
        }
    }

    // 🌟 ГЛАВНЫЙ КОНТЕЙНЕР (Прозрачность висит на нем)
    Item {
        id: rootItem
        anchors.fill: parent
        
        opacity: vinylWidget.player !== null ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 500; easing.type: Easing.InOutQuad } }

        // ==========================================
        // 🌟 1. ХАК В QML: ИСПОЛЬЗОВАНИЕ OPACITYMASK
        // ==========================================
        
        // Маскируемый контент (содержит ауру и пилюлю)
        Item {
            id: maskedContent
            anchors.fill: parent
            clip: true // Обязательно, чтобы маска не вылезала
            
            // ИСПРАВЛЕНИЕ 1: Скрываем сам элемент, так как его будет отрисовывать OpacityMask.
            // Иначе Wayland пытается отрендерить его дважды, вызывая сброс текстур.
            layer.enabled: true 
            visible: false

            // Оригинальная Магическая Аура (аура внутри маски)
            Image {
                id: hiddenArt
                source: vinylWidget.trackArt
             anchors.fill: parent
             fillMode: Image.PreserveAspectCrop  // ← было без fillMode
             layer.enabled: true
             visible: false
             cache: false
             asynchronous: true
            }
            
            MultiEffect {
                id: aura
                source: hiddenArt
                anchors.fill: parent
                blurEnabled: true
                blurMax: 64
                blur: 1.0
                saturation: 0.5
                brightness: -0.05
                opacity: vinylWidget.isPlaying ? 0.6 : 0.2
                Behavior on opacity { NumberAnimation { duration: 900; easing.type: Easing.InOutQuad } }
                
                SequentialAnimation on scale {
                    loops: Animation.Infinite
                    running: vinylWidget.isPlaying
                    NumberAnimation { to: 1.06; duration: 3000; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 0.97; duration: 3000; easing.type: Easing.InOutSine }
                }
            }

            // Матовая Пилюля (как в image_1.png)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: height / 2 
                
                color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, 0.65)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 20
                    anchors.topMargin: 10
                    anchors.bottomMargin: 10
                    spacing: 16

                    // Вращающийся Винил (как в image_1.png)
                    Item {
                        Layout.preferredWidth: 72
                        Layout.preferredHeight: 72
                        Layout.alignment: Qt.AlignVCenter

                        Rectangle {
                            id: vinylDisc
                            anchors.centerIn: parent
                            width: 72; height: 72; radius: 36
                            color: "#0f0f0f"
                            
                            RotationAnimation on rotation {
                                loops: Animation.Infinite
                                from: 0; to: 360; duration: 4000
                                running: vinylWidget.isPlaying
                            }
                            
                            // Концентрические дорожки (атмосфера виниловой пластинки)
                            Repeater {
                                model: [64, 56, 48, 40]
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: modelData; height: modelData
                                    radius: modelData / 2
                                    color: "transparent"
                                }
                            }

                            Rectangle {
                                anchors.centerIn: parent
                                width: 30; height: 30; radius: 15
                                color: Colors.bg
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    source: vinylWidget.trackArt
                                    fillMode: Image.PreserveAspectCrop
                                    visible: vinylWidget.trackArt !== ""
                                    cache: false
                                    asynchronous: true
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    width: 6; height: 6; radius: 3
                                    color: "#0f0f0f"
                                }
                            }
                        }
                    }

                    // Инфа о треке (как в image_1.png)
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: 4
                        
                        StyledText {
                            text: vinylWidget.player && vinylWidget.player.trackTitle ? vinylWidget.player.trackTitle : "Тишина..."
                            color: Colors.textMain
                            font.pixelSize: 15
                            font.bold: true
                            font.letterSpacing: 0.2
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        StyledText {
                            text: vinylWidget.player && vinylWidget.player.trackArtist ? vinylWidget.player.trackArtist : "Включи музыку"
                            color: Qt.rgba(Colors.textSub.r, Colors.textSub.g, Colors.textSub.b, 0.75)
                            font.pixelSize: 12
                            font.letterSpacing: 0.5
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }
                        
                        // Индикатор воспроизведения (анимированные бары)
                        Row {
                            spacing: 4
                            Layout.topMargin: 2
                            height: 22 // Фиксируем высоту ряда, чтобы полоски прыгали от нижнего края
                            opacity: vinylWidget.isPlaying ? 1 : 0
                            Behavior on opacity { NumberAnimation { duration: 400 } }

                            Repeater {
                                model: 5
                                Rectangle {
                                    anchors.bottom: parent.bottom // Привязка к низу!
                                    width: 4
                                    height: 6
                                    radius: 2
                                    color: Colors.accentPurple

                                    SequentialAnimation on height {
                                        loops: Animation.Infinite
                                        running: vinylWidget.isPlaying
                                        // Сдвиг фазы
                                        PauseAnimation { duration: index * 120 }
                                        NumberAnimation { to: 22; duration: 350; easing.type: Easing.InOutQuad }
                                        NumberAnimation { to: 6;  duration: 350; easing.type: Easing.InOutQuad }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // A non-visible rectangle that defines the shape of our mask
        Rectangle {
            id: maskShape
            width: vinylWidget.width
            height: vinylWidget.height
            radius: vinylWidget.height / 2
            color: "white"
            layer.enabled: true
            visible: false
        }

        // A GaussianBlur effect that uses the rectangle above as its source,
        // creating a blurred version of the shape. This will be our actual mask.
        GaussianBlur {
            id: blurredMask
            anchors.fill: maskShape
            source: maskShape
            radius: 8
            samples: 17
            layer.enabled: true // It's only used as a source for the OpacityMask
            visible: false
        }

        // Применение Маски
        OpacityMask {
            source: maskedContent
            maskSource: blurredMask
            anchors.fill: maskedContent
        }
    }
}