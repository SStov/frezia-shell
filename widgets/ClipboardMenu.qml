import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"
import "../components"

Rectangle {
    id: clipWindow

    property bool isOpen: false
    property int maxW: 400
    property int maxH: 550
    property int panelH: 0

    width: maxW
    height: maxH
    radius: 20
    color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, shellRoot ? shellRoot.qsOpacity : 0.95)
    clip: true

    // При открытии окна очищаем модель и запрашиваем свежую историю
    onIsOpenChanged: {
        if (isOpen) {
            clipModel.clear()
            getHistoryProcess.running = false
            getHistoryProcess.running = true
        }
    }

    // ==========================================
    // ЛОГИКА ДАННЫХ И ПРОЦЕССОВ
    // ==========================================
    ListModel { id: clipModel }

    Process {
        id: getHistoryProcess
        command: ["cliphist", "list"]
        
        // В Quickshell вывод собирается именно так
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                
                let lines = this.text.split("\n");
                let count = 0;
                
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i];
                    if (line.trim() === "") continue;
                    
                    let separatorIndex = line.indexOf("\t");
                    if (separatorIndex !== -1) {
                        let id = line.substring(0, separatorIndex);
                        let textContent = line.substring(separatorIndex + 1);
                        
                        clipModel.append({ "clipId": id, "clipText": textContent });
                        
                        count++;
                        if (count >= 30) break; // Ограничение на 30 записей
                    }
                }
            }
        }
    }

    Process {
        id: copyProcess
        // Команда будет назначаться динамически при клике
    }

    Process {
        id: clearProcess
        command: ["cliphist", "wipe"]
    }

    // ==========================================
    // ИНТЕРФЕЙС
    // ==========================================

    // Перехватываем клики, чтобы меню не закрывалось при клике по фону самого виджета
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // --- ЗАГОЛОВОК ---
        RowLayout {
            Layout.fillWidth: true
            
            StyledText { text: "󰅌"; color: Colors.accentBlue; font.pixelSize: 24 }
            
            StyledText { 
                text: "История буфера"
                color: Colors.textMain
                font.pixelSize: 18
                font.bold: true
                Layout.fillWidth: true
            }
            
            // Кнопка очистки истории
            Rectangle {
                width: 30
                height: 30
                radius: 15
                // Добавил легкую подсветку при наведении на кнопку корзины
                color: clearMouseArea.containsMouse ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.5) : "transparent"
                Behavior on color { ColorAnimation { duration: 100 } }

                StyledText { 
                    anchors.centerIn: parent
                    text: "󰃢"
                    color: Colors.textSub
                    font.pixelSize: 16 
                }

                MouseArea {
                    id: clearMouseArea
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        clearProcess.running = true;
                        clipModel.clear();
                    }
                }
            }
        }

        // Разделитель
        Rectangle { 
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.3) 
        }

        // --- СПИСОК БУФЕРА ---
        ListView {
            id: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
            model: clipModel
            spacing: 8
            clip: true

            // Заглушка, когда пусто
            StyledText {
                anchors.centerIn: parent
                text: "Буфер пуст"
                color: Colors.textSub
                font.pixelSize: 16
                visible: listView.count === 0
            }

            // Делегат элемента списка
            delegate: Rectangle {
                id: delegateItem
                
                // Явно требуем свойства из ListModel (защита от "model is not defined")
                required property string clipId
                required property string clipText

                width: listView.width
                height: Math.max(40, textItem.implicitHeight + 20)
                radius: 10
                color: itemMouseArea.containsMouse ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.6) : "transparent"
                // Мгновенный hover, без анимации

                StyledText {
                    id: textItem
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 15
                    
                    // Обращаемся напрямую к свойству делегата
                    text: delegateItem.clipText
                    color: Colors.textMain
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                MouseArea {
                    id: itemMouseArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        // Формируем точную команду для конкретного ID
                        let cmd = "cliphist list | grep -E '^" + delegateItem.clipId + "[[:space:]]' | cliphist decode | wl-copy";
                        copyProcess.command = ["sh", "-c", cmd];
                        copyProcess.running = true;
                        
                        // Закрываем окно после успешного клика
                        clipWindow.isOpen = false;
                    }
                }
            }
        }
    }
}