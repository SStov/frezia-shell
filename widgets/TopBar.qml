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
        command: ["mmsg", "watch", "tags", rootBar.monitorName]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                let clean = line.trim();
                if (!clean) return;
                try {
                    let resp = JSON.parse(clean);
                    let tags = resp.tags || [];
                    let states = {};
                    for (let i = 0; i < tags.length; i++) {
                        states[tags[i].index] = tags[i];
                    }
                    rootBar.tagStates = states;
                } catch(e) {
                    console.log("TopBar: failed to parse tags watch:", e);
                }
            }
        }
    }
    
    property var tagIcons: ({})

    Process {
        id: clientsProcess
        command: ["mmsg", "watch", "all-clients"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                let clean = line.trim();
                if (!clean) return;
                try {
                    let resp = JSON.parse(clean);
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
                    console.log("TopBar: failed to parse clients watch:", e);
                }
            }
        }
    }
    
    Process {
        id: layoutCheckProcess
        command: ["mmsg", "watch", "keyboardlayout"]
        running: true
        stdout: SplitParser {
            onRead: (line) => {
                let clean = line.trim();
                if (!clean) return;
                try {
                    let resp = JSON.parse(clean);
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
                    console.log("TopBar: failed to parse layout watch:", e);
                }
            }
        }
    }
    
    // Процесс для переключения раскладки в MangoWM
    Process {
        id: switchLayoutProcess
        function switchLayout() {
            command = ["mmsg", "dispatch", "switch_keyboard_layout"]
            running = true;
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