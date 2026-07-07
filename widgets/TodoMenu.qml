import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"
import "../components"

PanelWindow {
    id: todoWindow
    
    WlrLayershell.namespace: "qs-todo"
    WlrLayershell.layer: WlrLayer.Top 
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore
    
    // 1. УБИРАЕМ БЕЛЫЕ УШИ: Делаем само окно Wayland полностью прозрачным
    color: "transparent"
    
    // 2. УБИРАЕМ ДЕРГАНИЕ: Фиксируем размер физического окна.
    // Оно всегда максимального размера, а анимируется только дропдаун внутри него.
    implicitWidth: dropdown.maxW
    implicitHeight: dropdown.maxH 
    
    visible: dropdown.panelH > 0
    property bool isOpen: false
    signal switchToCalendar()
    // ==========================================
    // ЛОГИКА ДАННЫХ
    // ==========================================
    Process {
        id: initTodoData
        command: ["bash", "-c", "if [ ! -f /tmp/TodoData.qml ]; then cp /home/stul/.config/quickshell/widgets/TodoData.qml /tmp/TodoData.qml; fi"]
        onExited: dataLoader.reload()
    }

    Loader {
        id: dataLoader
        Component.onCompleted: initTodoData.running = true
        function reload() {
            source = "file:///tmp/TodoData.qml?t=" + new Date().getTime();
        }
    }

    Process {
        id: rustBackend
        function run(act, a) {
            let cmd = ["/home/stul/.config/quickshell/todo_backend", act];
            if (a !== undefined && a !== "") cmd.push(a.toString());
            command = cmd;
            running = true; 
        }
        onExited: {
            running = false;
            dataLoader.reload(); 
        }
    }

    function toggle() {
        isOpen = !isOpen;
        if (isOpen) {
            dataLoader.reload();
            focusTimer.start();
        } else {
            taskInput.focus = false; // Безопасное снятие фокуса
        }
    }

    Timer {
        id: focusTimer
        interval: 100
        onTriggered: taskInput.forceActiveFocus()
    }

    // ==========================================
    // ВИЗУАЛ
    // ==========================================
    ElasticDropdown {
        id: dropdown
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        maxW: 480
        maxH: 450
        isOpen: todoWindow.isOpen
        bgOpacity: shellRoot ? shellRoot.qsOpacity : 0.95
        useRootBg: true

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ШАПКА 
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 70
                
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 15

                    // 1. НОВАЯ КНОПКА ВОЗВРАТА К КАЛЕНДАРЮ
                 StyledText {
                     text: "" // Иконка календаря (FontAwesome/NerdFont)
                     color: calMouse.containsMouse ? Colors.accentBlue : Colors.textSub
                     font.pixelSize: 18
                     // Мгновенный hover, без анимации

                     MouseArea {
                         id: calMouse
                         anchors.fill: parent
                         anchors.margins: -5
                         hoverEnabled: true
                         cursorShape: Qt.PointingHandCursor
                         onClicked: {
                             todoWindow.toggle(); // Схлопываем To-Do
                             todoWindow.switchToCalendar(); // Просим Shell открыть календарь
                         }
                     }
                 }

                 // Разделитель
                 Rectangle { width: 1; height: 16; color: Colors.card }

                 StyledText { text: ""; color: Colors.accentBlue; font.pixelSize: 18 }

                    StyledText { text: ""; color: Colors.accentPurple; font.pixelSize: 18 }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: taskInput.text === "" ? "Добавить задачу..." : ""
                            color: Colors.textSub
                            font.pixelSize: 16
                            opacity: 0.6
                        }

                        StyledTextInput {
                            id: taskInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: Colors.textMain
                            font.pixelSize: 16
                            selectionColor: Colors.accentBlue
                            selectedTextColor: Colors.bg
                            
                            onAccepted: {
                                if (text.trim() !== "") {
                                    rustBackend.run("add", text);
                                    text = "";
                                }
                            }
                            Keys.onEscapePressed: todoWindow.toggle() 
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom; width: parent.width; height: 1; 
                    color: Colors.card; opacity: 0.5 
                }
            }

            // СПИСОК ЗАДАЧ
            ListView {
                id: taskList
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.margins: 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                spacing: 5

                model: dataLoader.item

                delegate: Rectangle {
                    width: taskList.width
                    height: 50
                    radius: 12
                    color: mouseArea.containsMouse ? Colors.card : "transparent"
                    // Мгновенный hover, без анимации

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 15
                        spacing: 15

                        Rectangle {
                            Layout.preferredWidth: 20; Layout.preferredHeight: 20; radius: 10
                            color: model.isDone ? Colors.accentBlue : "transparent"
                            // Мгновенное изменение состояния

                            StyledText {
                                anchors.centerIn: parent; text: ""; color: Colors.bg
                                font.pixelSize: 12; opacity: model.isDone ? 1 : 0
                            }

                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: rustBackend.run("toggle", index)
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: model.taskText
                            color: model.isDone ? Colors.textSub : Colors.textMain
                            font.pixelSize: 15; font.strikeout: model.isDone; elide: Text.ElideRight
                        }

                        StyledText {
                            text: ""
                            color: delMouse.containsMouse ? Colors.error : "transparent"
                            font.pixelSize: 16;

                            MouseArea {
                                id: delMouse
                                anchors.fill: parent; anchors.margins: -5
                                hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: rustBackend.run("delete", index)
                            }
                        }
                    }
                    MouseArea { id: mouseArea; anchors.fill: parent; hoverEnabled: true; z: -1 }
                }
            }
        }
    }
}