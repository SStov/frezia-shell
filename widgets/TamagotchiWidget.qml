import QtQuick
import Quickshell
import Quickshell.Io
import "../core"
import "../components"

Item {
    id: tamaWidget
    
    width: 280
    height: 380

    // --- ЛОГИКА ТАМАГОЧИ ---
    property real hunger: 80
    property real energy: 100
    property real mood: 90
    property bool isSleeping: false
    property string tempState: "" // Временные состояния: "eating", "loved", "petted"
    
    // ВЫЧИСЛЯЕМОЕ СОСТОЯНИЕ (гарантирует реактивность в QML)
    property string animState: {
        if (isSleeping) return "sleep"
        if (tempState !== "") return tempState
        if (hunger < 30 || energy < 20 || mood < 30) return "sad"
        if (mood > 80 && hunger > 70) return "happy"
        return "idle"
    } 
     
    // Сброс временных анимаций
    Timer {
        id: stateTimer
        interval: 3000
        onTriggered: tempState = ""
    }
    
    // Жизненный цикл питомца
    Timer {
        id: lifeTimer
        interval: 5000 // Каждые 5 секунд показатели падают
        repeat: true
        running: true
        onTriggered: {
            if (isSleeping) {
                energy = Math.min(100, energy + 8)
                hunger = Math.max(0, hunger - 0.5)
            } else {
                energy = Math.max(0, energy - 1.5)
                hunger = Math.max(0, hunger - 2)
                mood = Math.max(0, mood - 1)
                
                if (hunger < 30) mood = Math.max(0, mood - 2)
                if (energy < 30) mood = Math.max(0, mood - 2)
            }
        }
    }

    function getKaomoji() {
        let s = animState
        if (s === "sleep") return "( ˘ ɜ˘) 💤"
        if (s === "eating") return "(๑>؂<๑) 🍙"
        if (s === "loved") return "(♥ω♥*)"
        if (s === "petted") return "(´｡• ᵕ •｡`)"
        if (s === "sad") return "(ಥ﹏ಥ)"
        if (s === "happy") return "(≧◡≦) ✨"
        return "(◕‿◕✿)" // idle
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, 0.9)
        radius: 20
        
        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            // Заголовок
            StyledText {
                text: "mishka"
                color: Colors.accentBlue
                font.pixelSize: 18
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }
            
            // Зона анимации / Персонажа
            Rectangle {
                width: 140
                height: 140
                radius: 70
                color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.4)
                anchors.horizontalCenter: parent.horizontalCenter
                clip: true
                
                // Анимация из GIF
                AnimatedImage {
                    id: petImg
                    source: "file://" + Quickshell.env("HOME") + "/.config/quickshell/assets/tama_" + tamaWidget.animState + ".gif"
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    // Если файл не найден, GIF скроется
                    visible: status === AnimatedImage.Ready

                    // Если GIF берется из кеша при смене, запускаем его с первого кадра
                    onSourceChanged: {
                        if (status === AnimatedImage.Ready) {
                            currentFrame = 0
                            playing = true
                        }
                    }
                    
                    // Запускаем анимацию сразу после успешной загрузки файла
                    onStatusChanged: {
                        if (status === AnimatedImage.Ready) {
                            currentFrame = 0
                            playing = true
                        }
                    }
                    
                    // Если GIF не зациклен внутренне и остановился, зацикливаем вручную
                    onPlayingChanged: {
                        if (!playing && status === AnimatedImage.Ready) {
                            currentFrame = 0
                            playing = true
                        }
                    }
                }
                
                // Текстовый фоллбэк (милые Kaomoji), если GIF файлов нет
                StyledText {
                    anchors.centerIn: parent
                    text: getKaomoji()
                    color: Colors.textMain
                    font.pixelSize: 30
                    visible: petImg.status !== AnimatedImage.Ready
                    
                    Behavior on scale { SpringAnimation { spring: 5; damping: 0.2 } }
                    scale: tempState !== "" ? 1.2 : 1.0
                }
            }
            
            // Статусы
            Column {
                width: parent.width
                spacing: 8
                
                StatBar { icon: "🍖"; value: hunger; fillColor: hunger > 30 ? Colors.accentBlue : Colors.error }
                StatBar { icon: "⚡"; value: energy; fillColor: energy > 30 ? Colors.secondary : Colors.error }
                StatBar { icon: "💖"; value: mood; fillColor: mood > 30 ? Colors.accentPurple : Colors.error }
            }
            
            // Кнопки действий
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                
                // Кнопка: Покормить
                ActionBtn {
                    icon: "🍱"
                    label: "Кормить"
                    onClicked: {
                        if (isSleeping) return
                        hunger = Math.min(100, hunger + 25)
                        tempState = "eating"
                        stateTimer.restart()
                    }
                }
                // Кнопка: Гладить
                ActionBtn {
                    icon: "✋"
                    label: "Гладить"
                    onClicked: {
                        if (isSleeping) return
                        mood = Math.min(100, mood + 15)
                        tempState = "petted"
                        stateTimer.restart()
                    }
                }
                // Кнопка: Любить/Играть
                ActionBtn {
                    icon: "💕"
                    label: "Любить"
                    onClicked: {
                        if (isSleeping) return
                        mood = Math.min(100, mood + 25)
                        energy = Math.max(0, energy - 15)
                        tempState = "loved"
                        stateTimer.restart()
                    }
                }
                // Кнопка: Спать
                ActionBtn {
                    icon: "🌙"
                    label: "Спать"
                    isActive: isSleeping
                    onClicked: isSleeping = !isSleeping
                }
            }
        }
    }

    // Компонент кастомной шкалы
    component StatBar: Row {
        id: bar
        spacing: 10
        property string icon: ""
        property real value: 0
        property string fillColor: Colors.accentPurple
        
        StyledText { text: bar.icon; font.pixelSize: 14; width: 20; color: Colors.textMain }
        Rectangle {
            width: 190; height: 12; radius: 6; color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.6)
            anchors.verticalCenter: parent.verticalCenter
            Rectangle {
                height: parent.height; radius: 6; color: bar.fillColor
                width: (bar.value / 100) * parent.width
                Behavior on width { NumberAnimation { duration: 300; easing.type: Easing.OutExpo } }
                Behavior on color { ColorAnimation { duration: 300 } }
            }
        }
    }

    // Компонент кастомной кнопки
    component ActionBtn: Rectangle {
        id: btn
        property string icon: ""
        property string label: ""
        property bool isActive: false
        signal clicked()
        
        width: 50; height: 50; radius: 12
        color: isActive ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.6) : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.8)
        
        Column {
            anchors.centerIn: parent
            spacing: 2
            StyledText { text: btn.icon; font.pixelSize: 18; anchors.horizontalCenter: parent.horizontalCenter }
            StyledText { text: btn.label; color: Colors.textMain; font.pixelSize: 9; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
        }
        
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onEntered: btn.scale = 1.05
            onExited: btn.scale = 1.0
            onClicked: btn.clicked()
        }
        Behavior on scale { SpringAnimation { spring: 6; damping: 0.2 } }
        Behavior on color { ColorAnimation { duration: 150 } }
    }
}