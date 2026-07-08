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
                    let resp = JSON.parse(this.text);
                    let tags = resp.tags || [];
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
    
    property var tagIcons: ({})

    Process {
        id: clientsProcess
        command: ["mmsg", "get", "all-clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                try {
                    let resp = JSON.parse(this.text);
                    let allClients = resp.clients || [];
                    let icons = {};
                    for (let i = 0; i < allClients.length; i++) {
                        let client = allClients[i];
                        if (client.tags) {
                            for (let t = 0; t < client.tags.length; t++) {
                                let tagId = client.tags[t];
                                if (!icons[tagId] || client.is_focused) {
                                    icons[tagId] = client.appid || "";
                                }
                            }
                        }
                    }
                    rootBar.tagIcons = icons;
                } catch(e) {
                    console.log("TopBar: failed to parse clients:", e);
                }
            }
        }
    }
    
    // Получение текущей раскладки клавиатуры
    Timer {
        id: layoutCheckTimer
        interval: 400  // Периодическая проверка раскладки
        running: true
        repeat: true
        onTriggered: {
            layoutCheckProcess.running = false
            layoutCheckProcess.running = true
        }
    }
    
    Process {
        id: layoutCheckProcess
        command: ["mmsg", "get", "keyboardlayout"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                try {
                    let resp = JSON.parse(this.text);
                    let layout = resp.layout || "US";
                    layout = layout.toUpperCase();
                    let shortCode = "US";
                    
                    if (layout.includes("RUSSIAN") || layout.includes("RU")) {
                        shortCode = "RU";
                    } else if (layout.includes("ENGLISH") || layout.includes("US")) {
                        shortCode = "US";
                    } else if (layout.includes("UKRAINIAN") || layout.includes("UA")) {
                        shortCode = "UA";
                    } else if (layout.includes("GERMAN") || layout.includes("DE")) {
                        shortCode = "DE";
                    } else if (layout.includes("FRENCH") || layout.includes("FR")) {
                        shortCode = "FR";
                    } else {
                        shortCode = layout.substring(0, 2);
                    }
                    
                    if (shortCode !== rootBar.currentLayout) {
                        rootBar.currentLayout = shortCode;
                    }
                } catch(e) {
                    console.log("TopBar: failed to parse layout:", e);
                }
            }
        }
    }
    
    // Процесс для переключения раскладки в MangoWM
    Process {
        id: switchLayoutProcess
        function switchLayout() {
            command = ["mmsg", "dispatch", "switch_keyboard_layout"]
            running = true
            // Принудительно запускаем опрос раскладки после клика
            layoutCheckProcess.running = false
            layoutCheckProcess.running = true
        }
    }

    Timer {
        interval: 150; running: true; repeat: true
        onTriggered: {
            tagsProcess.running = false
            tagsProcess.running = true
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: {
            clientsProcess.running = false
            clientsProcess.running = true
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