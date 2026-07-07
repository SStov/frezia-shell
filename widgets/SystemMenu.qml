import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import QtQuick.Effects
import "../core"
import "../components"

ElasticDropdown {
    maxW: 400
    maxH: 450
    bgOpacity: shellRoot ? shellRoot.qsOpacity : 0.95
    useRootBg: true

    // Reference to settings menu
    property var settingsMenu: null

    // Переменная для открытия/закрытия меню аудиоустройств
    property bool showAudioDevices: false

    // Встроенный компонент QuickToggle
    component QuickToggle: Rectangle {
        property string icon: ""
        property string name: ""
        property bool isOn: false
        property color activeColor: Colors.accentBlue

        Layout.fillWidth: true
        height: 50
        radius: 12
        color: isOn ? activeColor : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.5)
        
        Behavior on color { ColorAnimation { duration: Anim.durationFast } }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            
            StyledText { text: icon; color: isOn ? Colors.bg : Colors.textMain; font.pixelSize: 18 }
            StyledText { text: name; color: isOn ? Colors.bg : Colors.textMain; font.bold: true }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: parent.isOn = !parent.isOn
        }
    }

    // ==========================================
    // СКРЫТЫЕ ПРОЦЕССЫ ДЛЯ КОМАНД
    // ==========================================
    Process { id: netOnProcess; command: ["nmcli", "networking", "on"] }
    Process { id: netOffProcess; command: ["nmcli", "networking", "off"] }
    
    // 🌟 BLUETOOTH PROCESSES
    Process {
        id: bluetoothCheckProcess
        command: ["bash", "-c", "bluetoothctl show | grep -q 'Powered: yes' && echo 'on' || echo 'off'"]
        onExited: {
            if (stdout && stdout.length > 0) {
                bluetoothToggle.isOn = (stdout[0].trim() === "on");
            }
        }
    }
    
    Process {
        id: bluetoothToggleProcess
        property bool turnOn: false
        function toggle(on) {
            turnOn = on;
            command = ["bash", "-c", turnOn ? "bluetoothctl power on" : "bluetoothctl power off"];
            running = true;
        }
    }
    
    // Check bluetooth status on startup
    Timer {
        id: bluetoothInitTimer
        interval: 2000 // Wait 2 seconds for system to be ready
        running: true
        repeat: false
        onTriggered: bluetoothCheckProcess.running = true
    }

    // 🌟 1. БЕЗОТКАЗНЫЙ UPTIME (Через Process, чтобы избежать ошибки XHR)
    Process {
        id: uptimeProcess
        command: ["cat", "/proc/uptime"]
        onExited: {
            if (stdout && stdout.length > 0) {
                var parts = stdout[0].split(" ");
                if (parts.length > 0) {
                    var totalSeconds = parseFloat(parts[0]);
                    var d = Math.floor(totalSeconds / 86400);
                    var h = Math.floor((totalSeconds % 86400) / 3600);
                    var m = Math.floor((totalSeconds % 3600) / 60);
                    
                    var upStr = "up ";
                    if (d > 0) upStr += d + "d ";
                    if (h > 0) upStr += h + "h ";
                    upStr += m + "m";
                    uptimeText.text = upStr;
                }
            }
        }
    }

    Timer {
        interval: 60000 // Раз в минуту
        running: true
        repeat: true
        triggeredOnStart: true // Вычислит uptime мгновенно при открытии
        onTriggered: uptimeProcess.running = true
    }

    // 🌟 2. БЕЗОТКАЗНАЯ АВАТАРКА
    Loader {
        id: avatarLoader
        // При старте Quickshell сразу грузит этот файл
        source: "file:///home/stul/.config/quickshell/avatar.qml"
    }

    Process {
        id: pickAvatarProcess
        command: [
            "bash", "-c",
            // Выбираем файл и сразу записываем готовый QML-код в конфиги
            "FILE=$(zenity --file-selection --title='Выберите аватарку' --file-filter='Images | *.png *.jpg *.jpeg'); if [ -n \"$FILE\" ]; then echo \"import QtQuick; QtObject { property string path: \\\"file://$FILE\\\" }\" > /home/stul/.config/quickshell/avatar.qml; fi"
        ]
        onExited: {
            // Перезагружаем Loader, чтобы новая картинка появилась моментально
            avatarLoader.source = "";
            avatarLoader.source = "file:///home/stul/.config/quickshell/avatar.qml?t=" + new Date().getTime();
        }
    }
    // 🌟 МАГИЯ АУДИО: Считываем устройства вывода и генерируем QML
    Process {
        id: fetchAudioDevices
        property int retryCount: 0
        property int maxRetries: 5
        
        command: [
            "bash", "-c",
            'pactl list sinks > /tmp/pactl_output.txt 2>&1'
        ]
        onExited: {
            // Always try to generate QML from output
            generateAudioQml.running = true;
        }
    }
    
    // Separate process to generate QML from pactl output
    Process {
        id: generateAudioQml
        command: [
            "bash", "-c",
            `
            echo 'import QtQuick' > /tmp/AudioData.qml
            echo 'QtObject { property var devices: [' >> /tmp/AudioData.qml
            
            while IFS= read -r line; do
                if echo "$line" | grep -q "^Sink #"; then
                    id=$(echo "$line" | sed 's/Sink #//')
                elif echo "$line" | grep -q "^[[:space:]]*Description:"; then
                    desc=$(echo "$line" | sed 's/^[[:space:]]*Description: //')
                    echo "{id: $id, name: \\\"$desc\\\"}," >> /tmp/AudioData.qml
                fi
            done < /tmp/pactl_output.txt
            
            echo '] }' >> /tmp/AudioData.qml
            `
        ]
        onExited: {
            audioLoader.source = "";
            audioLoader.source = "file:///tmp/AudioData.qml?t=" + new Date().getTime();
        }
    }
    
    // Process to create empty fallback
    Process {
        id: createEmptyAudioFallback
        command: [
            "bash", "-c",
            'echo "import QtQuick" > /tmp/AudioData.qml && echo "QtObject { property var devices: [] }" >> /tmp/AudioData.qml'
        ]
        onExited: {
            audioLoader.source = "";
            audioLoader.source = "file:///tmp/AudioData.qml?t=" + new Date().getTime();
        }
    }
    
    // Initial fetch after system is ready
    Timer {
        id: audioInitTimer
        interval: 3000
        running: true
        repeat: false
        onTriggered: {
            fetchAudioDevices.retryCount = 0;
            fetchAudioDevices.running = true;
        }
    }

    Loader { 
        id: audioLoader
        onStatusChanged: {
            if (status === Loader.Ready) {
                if (item && item.devices && item.devices.length > 0) {
                    console.log("Audio devices loaded: " + item.devices.length);
                    fetchAudioDevices.retryCount = 0;
                } else {
                    console.log("Audio devices empty");
                    if (fetchAudioDevices.retryCount < fetchAudioDevices.maxRetries) {
                        fetchAudioDevices.retryCount++;
                        console.log("Audio retry " + fetchAudioDevices.retryCount + "/" + fetchAudioDevices.maxRetries);
                        retryTimer.restart();
                    } else {
                        fetchAudioDevices.retryCount = 0;
                        createEmptyAudioFallback.running = true;
                    }
                }
            } else if (status === Loader.Error) {
                console.log("Audio loader error");
                if (fetchAudioDevices.retryCount < fetchAudioDevices.maxRetries) {
                    fetchAudioDevices.retryCount++;
                    retryTimer.restart();
                } else {
                    fetchAudioDevices.retryCount = 0;
                    createEmptyAudioFallback.running = true;
                }
            }
        }
    }
    
    Timer {
        id: retryTimer
        interval: 1500
        repeat: false
        onTriggered: fetchAudioDevices.running = true
    }

    // Процесс для смены устройства по клику
    Process {
        id: setAudioDevice
        function run(sinkId) {
            command = ["pactl", "set-default-sink", sinkId.toString()];
            running = true;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15

        // ==========================================
        // ПРОФИЛЬ
        // ==========================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 15
            
            // КЛИКАБЕЛЬНАЯ АВАТАРКА
            Rectangle {
                width: 50; height: 50; radius: 25; color: Colors.accentBlue
                // clip: true <-- Убрали, он здесь только вредит
                
                // 1. Создаем круглую маску-трафарет
                Rectangle {
                    id: maskRect
                    anchors.fill: parent
                    radius: 25
                    color: "black" // 🌟 Обязательно плотный цвет, чтобы маска работала
                    visible: false 
                    layer.enabled: true // 🌟 ЗАСТАВЛЯЕМ движок рендерить эту форму в память!
                }

                // 2. Исходная картинка
                Image {
                    id: avatarImage
                    anchors.fill: parent
                    fillMode: Image.PreserveAspectCrop
                    source: avatarLoader.item ? avatarLoader.item.path : ""
                    visible: false 
                }

                // 3. Отрисовываем картинку, обрезая ее по маске
                MultiEffect {
                    source: avatarImage
                    anchors.fill: avatarImage
                    maskEnabled: true
                    maskSource: maskRect
                }

                // Иконка Arch, если аватарка еще ни разу не выбиралась
                StyledText { 
                    anchors.centerIn: parent; text: "󰣇"; color: Colors.bg; font.pixelSize: 24 
                    visible: avatarImage.status !== Image.Ready 
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: pickAvatarProcess.running = true
                    
                    // Стильный эффект затемнения и карандашик при наведении
                    Rectangle {
                        anchors.fill: parent
                        radius: 25 // 🌟 ДОБАВЛЕНО: чтобы затемнение тоже было идеальным кругом!
                        color: "black"
                        opacity: parent.containsMouse ? 0.4 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        
                        StyledText {
                            anchors.centerIn: parent
                            text: "󰄄" 
                            color: Colors.bg
                            font.pixelSize: 20
                            visible: parent.opacity > 0
                        }
                    }
                }
            }
            
            ColumnLayout {
                spacing: 2
                StyledText { text: "STUL"; color: Colors.textMain; font.pixelSize: 18; font.bold: true }
                
                // ДИНАМИЧЕСКИЙ UPTIME
                StyledText { 
                    id: uptimeText
                    text: "up ..." // Перекроется таймером за 1 миллисекунду
                    color: Colors.subtext; font.pixelSize: 12 
                }
            }
            
            Item { Layout.fillWidth: true }
            
            // КНОПКА НАСТРОЕК (перенесена сюда)
            Rectangle {
                width: 36; height: 30; radius: 15
                color: setMouse.containsMouse ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4) : "transparent"
                scale: setMouse.pressed ? 0.9 : (setMouse.containsMouse ? 1.05 : 1.0)
                StyledText { anchors.centerIn: parent; text: ""; color: Colors.fg; font.pixelSize: 16 }
                MouseArea {
                    id: setMouse
                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                    onEntered: parent.color = Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4)
                    onExited: parent.color = "transparent"
                    onClicked: {
                        if (settingsMenu) {
                            settingsMenu.toggle();
                            isOpen = false; // Close system menu when opening settings
                        }
                    }
                }
                // Мгновенный hover, без анимации цвета
                Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
            }
        }
            

        // ==========================================
        // БЫСТРЫЕ ПЕРЕКЛЮЧАТЕЛИ
        // ==========================================
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 10; columnSpacing: 10
            
            QuickToggle { 
                id: killSwitch
                icon: isOn ? "󰈀" : "󰈂" 
                name: "Network" 
                isOn: true 
                activeColor: Colors.accentBlue 
                
                MouseArea {
                    anchors.fill: parent
                    z: 1 
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        killSwitch.isOn = !killSwitch.isOn
                        if (killSwitch.isOn) netOnProcess.running = true
                        else netOffProcess.running = true
                    }
                }
            }

            QuickToggle {
                id: bluetoothToggle
                icon: isOn ? "󰂯" : "󰂲"; name: "Bluetooth"; isOn: false; activeColor: Colors.accentPurple
                MouseArea {
                    anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        bluetoothToggle.isOn = !bluetoothToggle.isOn;
                        bluetoothToggleProcess.toggle(bluetoothToggle.isOn);
                    }
                }
            }
            QuickToggle {
                icon: "󰒲"; name: "DND"; isOn: false; activeColor: Colors.accentPurple
                MouseArea {
                    anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor
                    onClicked: parent.isOn = !parent.isOn
                }
            }
            QuickToggle {
                icon: "󰖔"; name: "Night Light"; isOn: true; activeColor: Colors.accentPurple
                MouseArea {
                    anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor
                    onClicked: parent.isOn = !parent.isOn
                }
            }
        }

        // ==========================================
        // ГРОМКОСТЬ И ВЫБОР УСТРОЙСТВА
        // ==========================================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

            // ПОЛЗУНОК ГРОМКОСТИ И MUTE
            RowLayout {
                id: volumeSliderRoot
                Layout.fillWidth: true
                spacing: 15

                PwObjectTracker {
                    objects: [ Pipewire.defaultAudioSink ]
                }

                property var sink: Pipewire.defaultAudioSink
                property real currentVolume: sink && sink.audio ? sink.audio.volume : 0.0
                property bool isMuted: sink && sink.audio ? sink.audio.muted : false

                StyledText {
                    text: volumeSliderRoot.isMuted || volumeSliderRoot.currentVolume === 0 ? "󰖁" : (volumeSliderRoot.currentVolume > 0.5 ? "󰕾" : "󰖀")
                    color: volumeSliderRoot.isMuted ? Colors.textSub : Colors.accentBlue
                    font.pixelSize: 20
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (volumeSliderRoot.sink && volumeSliderRoot.sink.audio) {
                                volumeSliderRoot.sink.audio.muted = !volumeSliderRoot.sink.audio.muted
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 12
                    radius: 6
                    color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.5)

                    Rectangle {
                        anchors.left: parent.left; anchors.top: parent.top; anchors.bottom: parent.bottom
                        width: parent.width * volumeSliderRoot.currentVolume
                        radius: 6
                        color: volumeSliderRoot.isMuted ? Colors.textSub : Colors.accentBlue
                        Behavior on width { NumberAnimation { duration: 60 } }
                    }

                    MouseArea {
                        anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                        function updateVolume(mouseX) {
                            if (volumeSliderRoot.sink && volumeSliderRoot.sink.audio) {
                                let newVol = Math.max(0.0, Math.min(1.0, mouseX / width))
                                volumeSliderRoot.sink.audio.volume = newVol
                                if (newVol > 0 && volumeSliderRoot.sink.audio.muted) volumeSliderRoot.sink.audio.muted = false
                            }
                        }
                        onClicked: (mouse) => updateVolume(mouse.x)
                        onPositionChanged: (mouse) => { if (pressed) updateVolume(mouse.x) }
                    }
                }
                
                StyledText { text: Math.round(volumeSliderRoot.currentVolume * 100) + "%"; color: Colors.textMain; font.pixelSize: 14; Layout.preferredWidth: 40; horizontalAlignment: Text.AlignRight }
            }

                // КНОПКА ОТКРЫТИЯ СПИСКА УСТРОЙСТВ
                Rectangle {
                    width: 44
                    height: 44
                    radius: 14
                    
                    // Стиль матового стекла
                    color: (pavuMouse.containsMouse || showAudioDevices) ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.8) : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.4)
                    
                    
                    // Мгновенный hover, без анимации

                    StyledText {
                        anchors.centerIn: parent
                        text: showAudioDevices ? "󰅖" : "󰓃" // Меняем иконку при открытии меню (Крестик / Эквалайзер)
                        color: (pavuMouse.containsMouse || showAudioDevices) ? Colors.accentBlue : Colors.textMain
                        font.pixelSize: 22
                        // Мгновенный hover, без анимации
                    }

                    MouseArea {
                        id: pavuMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            showAudioDevices = !showAudioDevices;
                            if (showAudioDevices) fetchAudioDevices.running = true; // Запрашиваем устройства при открытии
                        }
                    }
                }
            }

            // 🌟 ВЫПАДАЮЩИЙ СПИСОК УСТРОЙСТВ (Аккордеон)
            Rectangle {
                Layout.fillWidth: true
                // Вычисляем высоту динамически (40px на устройство + 10px отступы). Если закрыто - 0.
                Layout.preferredHeight: showAudioDevices && audioLoader.item ? (audioLoader.item.devices.length * 40 + 10) : 0
                visible: Layout.preferredHeight > 0
                clip: true
                radius: 14
                color: Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.5)
                
                // Плавная анимация выезда
                Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }

                Column {
                    anchors.fill: parent
                    anchors.margins: 5
                    spacing: 0
                    
                    Repeater {
                        model: audioLoader.item ? audioLoader.item.devices : []
                        delegate: Rectangle {
                            width: parent.width
                            height: 40
                            radius: 10
                            color: devMouse.containsMouse ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.6) : "transparent"
                            // Мгновенный hover, без анимации

                            RowLayout {
                                anchors.fill: parent
                                anchors.margins: 12
                                spacing: 12
                                
                                StyledText { 
                                    text: "󰋋" // Иконка устройства (наушники)
                                    color: Colors.accentBlue
                                    font.pixelSize: 16 
                                }
                                
                                StyledText { 
                                    text: modelData.name // Человекочитаемое имя от pactl
                                    color: Colors.textMain
                                    font.pixelSize: 13
                                    elide: Text.ElideRight // Обрезаем длинные имена точечками
                                    Layout.fillWidth: true
                                }
                            }

                            MouseArea {
                                id: devMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    setAudioDevice.run(modelData.id); // Переключаем звук!
                                    showAudioDevices = false; // Автоматически сворачиваем меню
                                }
                            }
                        }
                    }
                }
            }
        }

        Item { Layout.fillHeight: true }
    }
}