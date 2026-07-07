import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"
import "../components"

PanelWindow {
    id: rootWindow
    
    WlrLayershell.namespace: "qs-wallpaper"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 1920
    implicitHeight: 1080
    
    property bool isOpen: false
    property bool panelVisible: false
    readonly property int dockHeight: 280
    readonly property int dockWidth: Math.min(Screen.width - 200, 840) // Идеальная ширина для длинного дока
    visible: panelVisible
    
    // 🌟 ТЕКУЩАЯ ВКЛАДКА (0 - Локальные, 1 - Wallhaven)
    property int activeTab: 0
    property string wallhavenQuery: "" 
    property string localQuery: "" 
    property bool isSearchingRemote: false

    // 🌟 НАСТРОЙКИ ПУТИ
    property string wallDir: ""
    property bool useMatugen: true
    property var allFiles: []

    // 🌟 Хелпер для экранирования пробелов и спецсимволов в путях для Qt Image
    function toFileUrl(filePath) {
        if (!filePath) return "";
        if (filePath.startsWith("file://") || filePath.startsWith("http://") || filePath.startsWith("https://")) {
            return filePath;
        }
        // Заменяем решетку и экранируем пробелы
        return "file://" + encodeURI(filePath).replace(/#/g, "%23");
    }

    // ==========================================
    // ЛОГИКА СКАЧИВАНИЯ И УПРАВЛЕНИЯ ОБОЯМИ
    // ==========================================
    Process {
        id: fetchWallpapers
        
        property string fallbackDir: "/home/stul/Pictures/wallpapers"
        
        command: ["bash", "-c",
`
dir="${rootWindow.wallDir || fallbackDir}"
THUMB_DIR="$HOME/.cache/qs_wall_thumbs"
mkdir -p "$THUMB_DIR"

echo -n "["
for f in "$dir"/*; do
    [ -f "$f" ] || continue
    ext="\${f##*.}"
    case "\$ext" in
        jpg|png|jpeg|JPG|PNG|JPEG)
            n=\$(basename "\$f")
            thumb="\$THUMB_DIR/\$n.thumb.jpg"
            if [ ! -f "\$thumb" ]; then
                magick "\$f" -thumbnail 400x300^ -gravity center -extent 400x300 -quality 80 "$thumb" 2>/dev/null || convert "\$f" -thumbnail 400x300^ -gravity center -extent 400x300 -quality 80 "$thumb" 2>/dev/null &
            fi
            # Экранирование JSON спецсимволов
            n_esc=\$(echo -n "\$n" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
            f_esc=\$(echo -n "\$f" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
            t_esc=\$(echo -n "\$thumb" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
            echo -n "{\\"fileName\\":\\"\$n_esc\\",\\"filePath\\":\\"\$f_esc\\",\\"thumbPath\\":\\"\$t_esc\\",\\"isRemote\\":false},"
            ;;
    esac
done
echo -n "]"
`
        ]
        
        stdout: StdioCollector {
            onStreamFinished: {
                let text = this.text.trim();
                if (text.endsWith(",]")) {
                    text = text.substring(0, text.length - 2) + "]";
                }
                try {
                    let files = JSON.parse(text);
                    rootWindow.allFiles = files;
                    if (rootWindow.activeTab === 0) {
                        rootWindow.filterLocalModel(rootWindow.localQuery);
                    }
                } catch (e) {
                    console.log("Error parsing wallpapers JSON:", e);
                }
            }
        }
        
        function refresh() {
            running = false;
            running = true;
        }
    }

    Process {
        id: applyWall
        function run(filePath) {
            running = false;
            if (rootWindow.useMatugen) {
                command = ["/home/stul/.local/bin/swww-matugen.sh", filePath];
            } else {
                command = ["awww", "img", filePath, "--transition-type", "grow", "--transition-pos", "0.5,0.5"];
            }
            running = true;
        }
    }

    Process {
        id: downloadAndApply
        function run(url, name) {
            running = false;
            let ext = url.split('.').pop() || "jpg";
            let dest = "/home/stul/Pictures/wallpapers/" + name + "." + ext;
            command = [
                "bash", "-c",
                "notify-send 'Wallhaven' 'Скачиваю обои... ⏳' -a 'Wallpaper'; " +
                "wget -q -O '" + dest + "' '" + url + "'; " +
                "if [ $? -eq 0 ]; then " +
                "  notify-send 'Wallhaven' 'Обои установлены! ✅' -a 'Wallpaper'; " +
                "  /home/stul/.local/bin/swww-matugen.sh '" + dest + "'; " +
                "else " +
                "  notify-send 'Wallhaven' 'Ошибка скачивания ❌' -a 'Wallpaper' -u critical; " +
                "fi"
            ];
            running = true;
        }
    }

    function filterLocalModel(query) {
        wallModel.clear();
        let q = query.toLowerCase();
        for (let i = 0; i < allFiles.length; i++) {
            let fObj = allFiles[i];
            if (fObj.fileName.toLowerCase().includes(q)) {
                wallModel.append({ 
                    fileName: fObj.fileName, 
                    filePath: fObj.filePath, 
                    thumbPath: fObj.thumbPath,
                    isRemote: false
                });
            }
        }
    }

    // 🌟 ЗАПРОС К API WALLHAVEN
    function fetchWallhaven(query) {
        wallModel.clear();
        rootWindow.isSearchingRemote = true;
        let xhr = new XMLHttpRequest();
        let url = "https://wallhaven.cc/api/v1/search?purity=100&sorting=relevance";
        if (query.trim() !== "") {
            url += "&q=" + encodeURIComponent(query);
        }
        
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                rootWindow.isSearchingRemote = false;
                if (xhr.status === 200) {
                    try {
                        let json = JSON.parse(xhr.responseText);
                        let data = json.data;
                        if (data && data.length > 0) {
                            for (let i = 0; i < data.length; i++) {
                                let item = data[i];
                                wallModel.append({
                                    fileName: "wallhaven-" + item.id,
                                    filePath: item.path,
                                    thumbPath: item.thumbs.small || item.thumbs.original,
                                    isRemote: true
                                });
                            }
                        }
                    } catch(e) {
                        console.log("XHR parsing error:", e);
                    }
                }
            }
        }
        xhr.send();
    }

    Timer {
        id: wallhavenTimer
        interval: 650 
        repeat: false
        onTriggered: rootWindow.fetchWallhaven(rootWindow.wallhavenQuery)
    }

    onIsOpenChanged: {
        if (isOpen) {
            hideTimer.stop();
            panelVisible = true;
            activeTab = 0; 
            localQuery = "";
            wallhavenQuery = "";
            searchInput.text = "";
            fetchWallpapers.refresh();
        } else {
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 340
        repeat: false
        onTriggered: { if (!rootWindow.isOpen) rootWindow.panelVisible = false; }
    }

    // Закрытие по клику в любой пустой области экрана вокруг дока
    MouseArea {
        anchors.fill: parent
        onClicked: rootWindow.isOpen = false
    }

    // Перехват клавиши Escape для закрытия меню выбора обоев
    Shortcut {
        sequence: "Escape"
        enabled: rootWindow.isOpen
        onActivated: rootWindow.isOpen = false
    }

    // ==========================================
    // ВИЗУАЛ: ПРЕМИАЛЬНЫЙ НИЖНИЙ DOCK ДЛЯ ОБОЕВ
    // ==========================================
    Rectangle {
        id: backgroundOverlay
        anchors.fill: parent
        color: "black"
        opacity: rootWindow.isOpen ? 0.45 : 0 // Слегка затеняем остальной экран для фокуса
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
    }

    Rectangle {
        id: mainWindow
        width: rootWindow.dockWidth
        height: rootWindow.dockHeight
        x: (parent.width - width) / 2
        // Смещаем вниз так, чтобы нижние закруглённые углы уходили за экран (+20). Создаем эффект прикрепленности.
        y: rootWindow.isOpen ? parent.height - height + 20 : parent.height + 32
        radius: 32
        
        // Потрясающий стеклянный глубокий темный цвет независимо от системной темы для высокого контраста
        color: Qt.rgba(0.08, 0.08, 0.09, 0.95)

        Behavior on y { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        // Безопасность клика внутри дока
        MouseArea { anchors.fill: parent; onClicked: {} }

        // Нежный горизонтальный блик по верхнему краю дока
        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            height: 1
            color: Qt.rgba(1, 1, 1, 0.12)
        }

        // ==========================================
        // ВЕРХНЯЯ СЕКЦИЯ: ТАБЫ + ПОИСК + ЗАКРЫТИЕ
        // ==========================================
        RowLayout {
            id: topHeader
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 16
            height: 38
            spacing: 16

            // 🌟 1. КНОПКИ-ПЕРЕКЛЮЧАТЕЛИ (Local / Wallhaven)
            Rectangle {
                id: sourceSwitch
                width: 170
                height: 36
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.04)

                Rectangle {
                    width: (parent.width - 6) / 2
                    height: parent.height - 6
                    y: 3
                    x: rootWindow.activeTab === 0 ? 3 : parent.width / 2
                    radius: 15
                    color: Qt.rgba(1, 0.40, 0.65, 0.25) // Нежно-розовый акцент как на скриншоте
                    Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.InOutCubic } }
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 3
                    spacing: 0

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        StyledText { 
                            anchors.centerIn: parent 
                            text: "Local" 
                            color: "white" 
                            font.pixelSize: 12
                            font.bold: rootWindow.activeTab === 0 
                            opacity: rootWindow.activeTab === 0 ? 1.0 : 0.6 
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                        MouseArea { 
                            anchors.fill: parent 
                            cursorShape: Qt.PointingHandCursor 
                            onClicked: { 
                                rootWindow.activeTab = 0; 
                                searchInput.text = rootWindow.localQuery;
                                rootWindow.filterLocalModel(rootWindow.localQuery); 
                            } 
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        color: "transparent"
                        StyledText { 
                            anchors.centerIn: parent 
                            text: "Remote" 
                            color: "white" 
                            font.pixelSize: 12
                            font.bold: rootWindow.activeTab === 1 
                            opacity: rootWindow.activeTab === 1 ? 1.0 : 0.6 
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }
                        MouseArea { 
                            anchors.fill: parent 
                            cursorShape: Qt.PointingHandCursor 
                            onClicked: { 
                                rootWindow.activeTab = 1; 
                                searchInput.text = rootWindow.wallhavenQuery;
                                rootWindow.fetchWallhaven(rootWindow.wallhavenQuery); 
                            } 
                        }
                    }
                }
            }

            // 🌟 2. ПОЛНОЦЕННЫЙ КРАСИВЫЙ ПОИСКОВОЙ ИНПУТ С ВЫСОКИМ КОНТРАСТОМ
            Rectangle {
                Layout.fillWidth: true
                height: 36
                radius: 18
                color: Qt.rgba(1, 1, 1, 0.05)

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    StyledText {
                        text: "🔍"
                        font.pixelSize: 13
                        color: "white"
                        opacity: 0.5
                    }

                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        // Сам встроенный инпут
                        StyledTextInput {
                            id: searchInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: "white" // Строго белые шрифты для великолепного контраста
                            font.pixelSize: 13
                            selectByMouse: true
                            selectionColor: Qt.rgba(1, 0.40, 0.65, 0.4)
                            selectedTextColor: "white"
                            
                            onTextChanged: {
                                let t = text.trim();
                                if (rootWindow.activeTab === 0) {
                                    rootWindow.localQuery = t;
                                    rootWindow.filterLocalModel(t);
                                } else {
                                    rootWindow.wallhavenQuery = t;
                                    wallhavenTimer.restart();
                                }
                            }
                        }

                        // Плейсхолдер
                        StyledText {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            text: rootWindow.activeTab === 0 ? "Поиск локальных обоев..." : "Поиск обоев на Wallhaven..."
                            color: "white"
                            font.pixelSize: 13
                            opacity: searchInput.text.length === 0 ? 0.35 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 100 } }
                        }
                    }

                    // Кнопка быстрой очистки текста
                    StyledText {
                        text: "×"
                        font.pixelSize: 16
                        color: "white"
                        opacity: searchInput.text.length > 0 ? 0.5 : 0.0
                        visible: opacity > 0
                        font.bold: true
                        Layout.preferredWidth: 16
                        horizontalAlignment: Text.AlignHCenter
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: { searchInput.text = ""; searchInput.forceActiveFocus(); }
                        }
                    }
                }
            }

            // 🌟 3. КОМПАКТНАЯ КНОПКА ЗАКРЫТИЯ ДОКА
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: closeMouse.containsMouse ? Qt.rgba(0.9, 0.25, 0.3, 0.85) : Qt.rgba(1, 1, 1, 0.06)
                Behavior on color { ColorAnimation { duration: 150 } }
                
                StyledText { 
                    anchors.centerIn: parent 
                    text: "×" 
                    color: "white" 
                    font.pixelSize: 14 
                    font.bold: true 
                }
                
                MouseArea { 
                    id: closeMouse; 
                    anchors.fill: parent; 
                    hoverEnabled: true; 
                    cursorShape: Qt.PointingHandCursor; 
                    onClicked: rootWindow.isOpen = false 
                }
            }
        }

        // ==========================================
        // НИЖНЯЯ СЕКЦИЯ: ГОРИЗОНТАЛЬНЫЙ VIEW СКАЧАННЫХ/ПОЛУЧЕННЫХ КАРТОЧЕК
        // ==========================================
        ListView {
            id: grid
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: topHeader.bottom
            anchors.bottom: parent.bottom
            anchors.leftMargin: 24
            anchors.rightMargin: 24
            anchors.topMargin: 16
            anchors.bottomMargin: 32 // Оставляем занижение для полей уходящих за экран углов
            orientation: ListView.Horizontal
            spacing: 20
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 2000
            maximumFlickVelocity: 4000
            flickDeceleration: 2400
            model: ListModel { id: wallModel }

            // Перехватываем стандартное вертикальное колесо мыши для плавной горизонтальной прокрутки
            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.NoButton // Пропускаем клики мыши сквозь MouseArea
                onWheel: (wheel) => {
                    if (wheel.angleDelta.y !== 0) {
                        let newContentX = grid.contentX - wheel.angleDelta.y * 1.5;
                        grid.contentX = Math.max(grid.originX, Math.min(newContentX, grid.contentWidth - grid.width));
                        wheel.accepted = true;
                    }
                }
            }

            delegate: Item {
                width: 172
                height: grid.height

                Rectangle {
                    id: card
                    anchors.centerIn: parent
                    width: itemMouse.containsMouse ? 172 : 160
                    height: itemMouse.containsMouse ? 154 : 142
                    radius: 18
                    color: "#1c1c22"
                    
                    clip: true
                    scale: itemMouse.containsMouse ? 1.02 : 1.0

                    Behavior on width { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                    // Мгновенный hover для рамки, без анимации цвета

                    // Превью
                    Image {
                        id: thumb
                        anchors.fill: parent
                        anchors.margins: itemMouse.containsMouse ? 4 : 0
                        source: model.isRemote ? model.thumbPath : rootWindow.toFileUrl(model.thumbPath)
                        
                        // Бесшовный файловый фоллбэк на случай, если превью для картинки по какой-то причине отсутствует
                        onStatusChanged: {
                            if (status === Image.Error && !model.isRemote && source.toString().includes("thumb.jpg")) {
                                source = rootWindow.toFileUrl(model.filePath);
                            }
                        }
                        
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize: Qt.size(380, 280)
                        opacity: itemMouse.containsMouse ? 1.0 : 0.75
                        Behavior on opacity { NumberAnimation { duration: 160 } }
                        Behavior on anchors.margins { NumberAnimation { duration: 160 } }
                    }

                    // Накладываем нежный розовый градиент при наведении
                    Rectangle {
                        anchors.fill: parent
                        radius: parent.radius
                        color: Qt.rgba(1, 0.40, 0.65, itemMouse.containsMouse ? 0.08 : 0)
                        // Мгновенный hover, без анимации
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (model.isRemote) {
                                downloadAndApply.run(model.filePath, model.fileName);
                                rootWindow.isOpen = false;
                            } else {
                                applyWall.run(model.filePath);
                                rootWindow.isOpen = false;
                            }
                        }
                    }
                }
            }
        }

        // 🌟 ИНДИКАТОР ПУСТОГО СОСТОЯНИЯ ИЛИ ПОИСКА
            StyledText {
                anchors.centerIn: grid
                text: rootWindow.isSearchingRemote ? "Ищем вдохновение на Wallhaven..." : "Ничего не найдено 🤔"
                color: "white"
                font.pixelSize: 14
                opacity: wallModel.count === 0 ? 0.5 : 0.0
                visible: opacity > 0
                // Мгновенное изменение видимости
            }
    }
}
