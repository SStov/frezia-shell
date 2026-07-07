import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../core"

Item {
    id: root
    width: 420
    height: 520
    
    property bool isOpen: false
    property bool hasTesseract: false
    property string ocrText: ""
    property string ocrStatus: ""
    property string availableLangs: ""
    
    Component.onCompleted: {
        checkTesseract.running = true
    }
    
    Process {
        id: checkTesseract
        command: ["bash", "-c", "which tesseract >/dev/null 2>&1 && echo 'TESS_OK' || echo 'TESS_MISSING'; tesseract --list-langs 2>/dev/null | tail -n +2 | tr '\n' ' '"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) return;
                let lines = this.text.split('\n');
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i].trim();
                    if (line === "TESS_OK") {
                        root.hasTesseract = true;
                    } else if (line === "TESS_MISSING") {
                        root.hasTesseract = false;
                        root.ocrStatus = "Tesseract не установлен. Установите: nix-env -iA nixpkgs.tesseract";
                    } else if (line.length > 0 && root.hasTesseract) {
                        root.availableLangs = line;
                        // Проверяем есть ли нужные языки
                        let hasEng = line.includes("eng");
                        let hasRus = line.includes("rus");
                        if (!hasEng && !hasRus) {
                            root.ocrStatus = "Tesseract установлен, но языковые пакеты отсутствуют. Установите: nix-env -iA nixpkgs.tesseract5WithLanguages";
                        }
                    }
                }
            }
        }
    }
    
    Process {
        id: ocrProcess
        function runOcr(imagePath) {
            root.ocrStatus = "Распознаю текст...";
            root.ocrText = "";
            // Экранируем путь к изображению
            let safePath = imagePath.replace(/'/g, "'\"'\"'");
            // Определяем язык
            let langArg = "-l eng+rus";
            if (!root.availableLangs.includes("rus")) {
                langArg = root.availableLangs.includes("eng") ? "-l eng" : "";
            }
            command = ["bash", "-c", "tesseract '" + safePath + "' stdout " + langArg + " 2>/tmp/ocr_err.txt; echo '---OCR_EXIT_CODE:' $?"];
            running = true;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                if (!this.text) {
                    root.ocrStatus = "Ошибка: пустой вывод от tesseract.";
                    return;
                }
                let lines = this.text.split('\n');
                let exitCode = 0;
                let output = [];
                for (let i = 0; i < lines.length; i++) {
                    let line = lines[i];
                    if (line.startsWith("---OCR_EXIT_CODE:")) {
                        exitCode = parseInt(line.split(":")[1]) || 0;
                    } else {
                        output.push(line);
                    }
                }
                root.ocrText = output.join('\n').trim();
                if (root.ocrText !== "") {
                    root.ocrStatus = "Готово!";
                } else if (exitCode !== 0) {
                    root.ocrStatus = "Ошибка OCR (код " + exitCode + "). Проверьте изображение или языковые пакеты.";
                } else {
                    root.ocrStatus = "Текст не найден на изображении.";
                }
            }
        }
    }
    
    Process {
        id: pasteProcess
        function pasteFromClipboard() {
            root.ocrStatus = "Получаю изображение из буфера...";
            command = ["bash", "-c", "wl-paste --type image/png > /tmp/ocr_input.png 2>/dev/null && echo 'PASTE_OK' || echo 'PASTE_FAIL'"];
            running = true;
        }
        stdout: SplitParser {
            onRead: (line) => {
                if (line.trim() === "PASTE_OK") {
                    ocrProcess.runOcr("/tmp/ocr_input.png");
                } else {
                    root.ocrStatus = "В буфере нет изображения.";
                }
            }
        }
    }
    
    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, 0.95)
        clip: true
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15
            
            Text {
                text: "󰄛 OCR Распознавание"
                color: Colors.textMain
                font.pixelSize: 18
                font.bold: true
            }
            
            // Drop zone / Paste area
            Rectangle {
                Layout.fillWidth: true
                height: 160
                radius: 16
                color: dropArea.containsDrag ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.15) : Colors.card
                
                DropArea {
                    id: dropArea
                    anchors.fill: parent
                    keys: ["text/uri-list"]
                    
                    onDropped: (drop) => {
                        if (!root.hasTesseract) return;
                        let urls = drop.urls;
                        if (urls && urls.length > 0) {
                            let url = urls[0].toString();
                            if (url.startsWith("file://")) {
                                url = url.substring(7);
                            }
                            ocrProcess.runOcr(url);
                        }
                    }
                }
                
                Column {
                    anchors.centerIn: parent
                    spacing: 8
                    
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "󰋩"
                        color: Colors.textSub
                        font.pixelSize: 36
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "Перетащите изображение сюда"
                        color: Colors.textSub
                        font.pixelSize: 13
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "или"
                        color: Colors.textSub
                        font.pixelSize: 12
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: pasteBtnText.width + 24
                        height: 32
                        radius: 16
                        color: pasteMouse.containsMouse ? Colors.accentBlue : Colors.card
                        
                        Text {
                            id: pasteBtnText
                            anchors.centerIn: parent
                            text: "󰆓 Вставить из буфера"
                            color: pasteMouse.containsMouse ? Colors.bg : Colors.textMain
                            font.pixelSize: 13
                            font.bold: true
                        }
                        
                        MouseArea {
                            id: pasteMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: pasteProcess.pasteFromClipboard()
                        }
                    }
                }
            }
            
            // Status
            Text {
                text: root.ocrStatus
                color: root.ocrStatus.includes("Ошибка") || root.ocrStatus.includes("не установлен") || root.ocrStatus.includes("отсутствуют") ? Colors.error : Colors.textSub
                font.pixelSize: 12
                visible: root.ocrStatus !== ""
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            
            // Output area
            Rectangle {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: 12
                color: Colors.card
                clip: true
                
                Flickable {
                    id: flickArea
                    anchors.fill: parent
                    anchors.margins: 12
                    contentWidth: outputText.width
                    contentHeight: outputText.height
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    
                    TextEdit {
                        id: outputText
                        width: flickArea.width
                        text: root.ocrText
                        color: Colors.textMain
                        font.pixelSize: 14
                        wrapMode: TextEdit.Wrap
                        readOnly: true
                        selectByMouse: true
                        selectionColor: Colors.accentBlue
                        selectedTextColor: Colors.bg
                    }
                }
            }
            
            // Copy button
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Item { Layout.fillWidth: true }
                
                Rectangle {
                    width: copyText.width + 24
                    height: 34
                    radius: 17
                    color: copyMouse.containsMouse ? Colors.accentBlue : Colors.card
                    visible: root.ocrText !== ""
                    
                    Text {
                        id: copyText
                        anchors.centerIn: parent
                        text: "󰆏 Копировать текст"
                        color: copyMouse.containsMouse ? Colors.bg : Colors.textMain
                        font.pixelSize: 13
                        font.bold: true
                    }
                    
                    MouseArea {
                        id: copyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            copyProcess.command = ["bash", "-c", "echo '" + root.ocrText.replace(/'/g, "'\"'\"'") + "' | wl-copy"];
                            copyProcess.running = true;
                            root.ocrStatus = "Текст скопирован!";
                        }
                    }
                }
            }
        }
    }
    
    Process { id: copyProcess }
}
