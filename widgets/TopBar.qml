import QtQuick
import Quickshell
import QtQuick.Window
import Quickshell.Io
import "../core"
import "../components"

Rectangle {
    id: rootBar
    
    // Фон панели — единая прозрачность как в SettingsMenu
    color: topBarStyle === "Dynamic" ? "transparent" : Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, shellRoot ? shellRoot.qsOpacity : 0.95)
    radius: 20

    property var hostWindow 

    signal toggleCalendar(real xPos)
    signal toggleSysMenu(real xPos)
    signal toggleTodo()
    signal toggleCalc(real xPos)
    signal toggleSettings()
    signal toggleClipboard(real xPos)
    signal toggleTamagotchi(real xPos)
    signal toggleMediaPlayer(real xPos)
    signal toggleOcr(real xPos)
    signal togglePower(real xPos)
    signal toggleNotificationCenter()
    signal toggleTrayMenu(real xPos, var menuHandle)
    signal showWorkspacePreview(int wsId, real xPos)
    signal hideWorkspacePreview()

    property bool isCalendarOpen: false
    property bool isSysMenuOpen: false
    property bool isTodoOpen: false 
    property bool isCalcOpen: false
    property bool isClipboardOpen: false
    property bool isTamagotchiOpen: false
    property bool isMediaPlayerOpen: false
    property bool isOcrOpen: false
    property bool isPowerOpen: false
    property bool isNotifCenterOpen: false
    property real bgOpacity: 0.7
    property var topBarOrder: [0, 1, 2]
    property int topBarTraySpacing: 10
    property int mediaPlayerWidth: 180
    property int mediaPlayerPosition: 0 // 0 = слева от часов, 1 = справа от часов
    property string topBarStyle: "Default"

    // MangoWM: состояния тегов (index -> { is_active, is_urgent, client_count, layout })
    property var tagStates: ({})
    property string monitorName: Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "HDMI-1"
    
    // Текущая раскладка клавиатуры
    property string currentLayout: "US"

    Process {
        id: tagsProcess
        command: ["mmsg", "get", "tags", rootBar.monitorName]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                try {
                    let tags = JSON.parse(this.text);
                    let states = {};
                    for (let i = 0; i < tags.length; i++) {
                        states[tags[i].index] = tags[i];
                    }
                    rootBar.tagStates = states;
                } catch(e) {
                    console.log("TopBar: failed to parse tags:", e);
                }
            }
        }
    }
    
    // Получение текущей раскладки клавиатуры
    // Используем file watcher для отслеживания изменений раскладки
    property string layoutFile: "/tmp/mango_current_layout"
    
    Timer {
        id: layoutCheckTimer
        interval: 200  // Частая проверка для быстрой реакции
        running: true
        repeat: true
        onTriggered: {
            layoutCheckProcess.running = false
            layoutCheckProcess.running = true
        }
    }
    
    Process {
        id: layoutCheckProcess
        command: ["cat", "/tmp/mango_current_layout"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.length > 0) {
                    let layout = this.text.trim().toUpperCase()
                    if (layout.length > 0 && layout !== rootBar.currentLayout) {
                        console.log("Layout changed to:", layout)
                        rootBar.currentLayout = layout.substring(0, 2)
                    }
                }
            }
        }
    }
    
    // Процесс для переключения раскладки
    Process {
        id: switchLayoutProcess
        function switchLayout() {
            command = ["hyprctl", "switchxkblayout", "all", "next"]
            running = true
            // Принудительно обновляем после переключения
            layoutCheckTimer.restart()
        }
    }

    Timer {
        interval: 500; running: true; repeat: true
        onTriggered: {
            tagsProcess.running = false
            tagsProcess.running = true
        }
    }

    // Expose layout switching to loaded widgets
    function switchLayout() {
        switchLayoutProcess.switchLayout()
    }

    // Dynamic TopBar Style Loader
    Loader {
        id: styleLoader
        anchors.fill: parent
        source: Qt.resolvedUrl("topbar/" + topBarStyle + ".qml")
        onStatusChanged: {
            if (status === Loader.Error) {
                console.log("TopBar loader error: failed to load", source)
            }
        }
        onLoaded: {
            if (item) {
                item.bar = rootBar;
            }
        }
    }
}