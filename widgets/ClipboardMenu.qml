import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"
import "../components"

Rectangle {
    id: clipWindow

    // --- API & State ---
    property bool isOpen: false
    property int maxW: 400
    property int maxH: isExpanded ? 580 : 220
    property real panelH: 0.0

    // Dynamic expanded mode toggle
    property bool isExpanded: false
    property bool isAnimationFinished: false
    property bool isExpandedAnimationFinished: false

    // Search and filter state
    property string searchQuery: ""
    property string activeFilter: "all" // all, pinned, text, url, color, command
    property var rawItems: [] // Data cache for staggered waterfall streaming

    // Compact featured snippet state
    property string latestText: ""
    property string latestId: ""
    property string latestType: "text"
    property bool isLatestPinned: false
    property string latestImagePath: ""

    // Sizing and visual setup
    width: maxW
    height: panelH
    radius: 20
    color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, shellRoot ? shellRoot.qsOpacity : 0.95)
    border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.15)
    border.width: 1
    clip: true

    // Smooth physics-like height animations
    Behavior on panelH {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutQuad
        }
    }
    Behavior on maxH {
        NumberAnimation {
            duration: 250
            easing.type: Easing.OutQuad
        }
    }

    // Reactively update height tracking when panel state changes
    onIsOpenChanged: {
        if (isOpen) {
            // Reset to clean, compact state when opened
            isExpanded = false;
            searchQuery = "";
            searchInput.text = "";
            activeFilter = "all";
            panelH = maxH; // Assign height to trigger expand transition!
            isAnimationFinished = false;
            animationTimer.start(); // Defer history fetching until animation finishes!
        } else {
            panelH = 0.0;
            isAnimationFinished = false;
            animationTimer.stop();
        }
    }

    Timer {
        id: animationTimer
        interval: 270 // 250ms height animation + 20ms buffer
        repeat: false
        onTriggered: {
            clipWindow.isAnimationFinished = true;
            // Now run the history process to refresh the list asynchronously
            clipModel.clear();
            getHistoryProcess.running = false;
            getHistoryProcess.running = true;
        }
    }

    onMaxHChanged: {
        if (isOpen) {
            panelH = maxH;
        }
    }

    onIsExpandedChanged: {
        if (isExpanded) {
            isExpandedAnimationFinished = false;
            expandTimer.start();
            refilterList();
        } else {
            isExpandedAnimationFinished = false;
            isAnimationFinished = false;
            animationTimer.start(); // Re-trigger animation timer to fade in compact content after collapse!
            clipModel.clear();
        }
    }

    Timer {
        id: expandTimer
        interval: 270 // 250ms height animation + 20ms buffer
        repeat: false
        onTriggered: {
            isExpandedAnimationFinished = true;
        }
    }

    // ==========================================
    // ЛОГИКА ДАННЫХ И ПРОЦЕССЫ
    // ==========================================
    ListModel { id: clipModel }
    ListModel { id: pinnedModel }

    // Read pinned snippets from persistent JSON
    FileView {
        id: pinnedFile
        path: Quickshell.env("HOME") + "/.config/quickshell/pinned_snippets.json"
        watchChanges: true
        onFileChanged: pinnedFile.reload()
        onLoaded: {
            pinnedModel.clear();
            try {
                let textVal = typeof pinnedFile.text === 'function' ? pinnedFile.text() : pinnedFile.text;
                if (textVal && textVal.trim() !== "") {
                    let data = JSON.parse(textVal);
                    for (let i = 0; i < data.length; i++) {
                        pinnedModel.append({
                            "clipId": data[i].clipId || ("pinned_" + Date.now() + "_" + i),
                            "clipText": data[i].clipText,
                            "clipType": data[i].clipType || "text",
                            "pinned": true
                        });
                    }
                }
            } catch (e) {
                console.log("Clipboard: Error loading pinned snippets:", e);
            }
        }
    }

    // Write pinned snippets back to JSON disk
    Process {
        id: writePinnedProcess
    }

    // Fetch history from cliphist
    Process {
        id: getHistoryProcess
        command: ["sh", "-c", "cliphist list | head -n 80"]
        stdout: StdioCollector {
            id: historyCollector
            onStreamFinished: {
                loadHistory(historyCollector.text);
            }
        }
    }

    // Copy action
    Process {
        id: copyProcess
    }

    // Wipe action (only affects cliphist; pinned items persist!)
    Process {
        id: clearProcess
        command: ["cliphist", "wipe"]
    }

    // Delete item action
    Process {
        id: deleteProcess
    }

    // Open URL action
    Process {
        id: openUrlProcess
    }

    Process {
        id: decodeLatestProcess
        property string targetPath: ""
        command: ["sh", "-c", "path='" + (targetPath ? targetPath.replace("file://", "") : "").replace(/'/g, "'\\''") + "'; [ -f \"$path\" ] || (mkdir -p ~/.cache/quickshell && printf '%s\\t%s' '" + latestId + "' '" + latestText.replace(/'/g, "'\\''") + "' | cliphist decode > \"$path\")"]
        running: latestType === "image" && latestImagePreview.status === Image.Error
        onRunningChanged: {
            if (!running && latestImagePreview.status === Image.Error && targetPath !== "") {
                // Refresh the source to make sure QML forces reload
                let temp = targetPath;
                latestImagePath = "";
                latestImagePath = temp;
            }
        }
    }



    // Debounce search text input
    Timer {
        id: searchDebounceTimer
        interval: 200
        repeat: false
        onTriggered: {
            refilterList();
        }
    }

    // ==========================================
    // ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ (JS)
    // ==========================================

    // Classify clipboard item content types
    function getClipType(text) {
        if (!text) return "text";
        let trimmed = text.trim();

        // 0. Binary images
        if (trimmed.startsWith("[[ binary data")) {
            return "image";
        }

        // 1. HEX / RGB color codes
        let hexRegex = /^#([A-Fa-f0-9]{3,4}|[A-Fa-f0-9]{6}|[A-Fa-f0-9]{8})$/;
        let rgbRegex = /^rgba?\s*\(\s*\d+\s*,\s*\d+\s*,\s*\d+\s*(,\s*(0(\.\d+)?|1(\.0)?))?\s*\)$/i;
        if (hexRegex.test(trimmed) || rgbRegex.test(trimmed)) {
            return "color";
        }

        // 2. URLs
        let urlRegex = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/;
        if (trimmed.startsWith("http://") || trimmed.startsWith("https://") || trimmed.startsWith("www.") || urlRegex.test(trimmed)) {
            return "url";
        }

        // 3. Shell commands
        let cmdPrefixes = ["$", "sudo", "yay", "pacman", "systemctl", "nix", "git", "cd", "ls", "grep", "cargo", "npm", "pip", "python", "curl", "wget"];
        let firstWord = trimmed.split(" ")[0];
        if (cmdPrefixes.indexOf(firstWord) !== -1 || trimmed.startsWith("./") || trimmed.startsWith("sh ")) {
            return "command";
        }

        return "text";
    }

    // Merge pinned JSON items and cliphist items into the cache
    function loadHistory(text) {
        clipWindow.rawItems = [];

        // Add pinned items first to anchor them at the top
        for (let i = 0; i < pinnedModel.count; i++) {
            let pItem = pinnedModel.get(i);
            rawItems.push({
                "clipId": pItem.clipId,
                "clipText": pItem.clipText,
                "clipType": pItem.clipType,
                "pinned": true
            });
        }

        // Parse recent history from cliphist
        if (text) {
            let lines = text.split("\n");
            let count = 0;
            for (let i = 0; i < lines.length; i++) {
                let line = lines[i];
                if (line.trim() === "") continue;

                let separatorIndex = line.indexOf("\t");
                if (separatorIndex !== -1) {
                    let id = line.substring(0, separatorIndex);
                    let textContent = line.substring(separatorIndex + 1);

                    // Filter duplicates against active pinned items
                    let isAlreadyPinned = false;
                    for (let j = 0; j < pinnedModel.count; j++) {
                        if (pinnedModel.get(j).clipText === textContent) {
                            isAlreadyPinned = true;
                            break;
                        }
                    }

                    if (!isAlreadyPinned) {
                        let type = getClipType(textContent);
                        rawItems.push({
                            "clipId": id,
                            "clipText": textContent,
                            "clipType": type,
                            "pinned": false
                        });
                    }

                    count++;
                    if (count >= 50) break; // Limit size for peak UI fluidity
                }
            }
        }

        // Update latest card preview properties based on index 0
        if (rawItems.length > 0) {
            latestId = rawItems[0].clipId;
            latestText = rawItems[0].clipText;
            latestType = rawItems[0].clipType;
            isLatestPinned = rawItems[0].pinned;

            if (latestType === "image") {
                let path = Quickshell.env("HOME") + "/.cache/quickshell/clip_" + latestId + ".png";
                decodeLatestProcess.targetPath = "file://" + path;
                latestImagePath = "file://" + path;
            } else {
                latestImagePath = "";
                decodeLatestProcess.targetPath = "";
            }
        } else {
            latestId = "";
            latestText = "";
            latestType = "text";
            isLatestPinned = false;
            latestImagePath = "";
            decodeLatestProcess.targetPath = "";
        }

        // Launch staggered stream to display model
        refilterList();
    }

    // Run cascade filling from cached rawItems matching filter & search
    function refilterList() {
        clipModel.clear();
        if (!isExpanded) return;
        for (let i = 0; i < rawItems.length; i++) {
            let item = rawItems[i];
            if (shouldInclude(item)) {
                clipModel.append({
                    "clipId": item.clipId,
                    "clipText": item.clipText,
                    "clipType": item.clipType,
                    "pinned": item.pinned
                });
            }
        }
    }

    // Determine matching status for a list item
    function shouldInclude(item) {
        if (activeFilter === "pinned") {
            if (!item.pinned) return false;
        } else if (activeFilter !== "all") {
            if (item.clipType !== activeFilter) return false;
        }

        if (searchQuery.trim() !== "") {
            let text = item.clipText.toLowerCase();
            let query = searchQuery.toLowerCase();
            if (text.indexOf(query) === -1) return false;
        }

        return true;
    }

    // Save current state of pinnedModel to disk JSON
    function savePinnedSnippets() {
        let list = [];
        for (let i = 0; i < pinnedModel.count; i++) {
            let item = pinnedModel.get(i);
            list.push({
                "clipId": item.clipId,
                "clipText": item.clipText,
                "clipType": item.clipType
            });
        }
        let jsonStr = JSON.stringify(list);
        let escapedJson = jsonStr.replace(/'/g, "'\\''");
        writePinnedProcess.command = ["sh", "-c", "echo '" + escapedJson + "' > " + Quickshell.env("HOME") + "/.config/quickshell/pinned_snippets.json"];
        writePinnedProcess.running = true;
    }

    // Copy to clipboard execution
    function copyToClipboard(text, id) {
        if (getClipType(text) === "image") {
            let path = Quickshell.env("HOME") + "/.cache/quickshell/clip_" + id + ".png";
            copyProcess.command = ["sh", "-c", "wl-copy < " + path];
        } else {
            if (id && id.startsWith("pinned_")) {
                let escapedText = text.replace(/'/g, "'\\''");
                copyProcess.command = ["sh", "-c", "echo -n '" + escapedText + "' | wl-copy"];
            } else {
                let escapedText = text.replace(/'/g, "'\\''");
                let cmd = "printf '%s\\t%s' '" + id + "' '" + escapedText + "' | cliphist decode | wl-copy";
                copyProcess.command = ["sh", "-c", cmd];
            }
        }
        copyProcess.running = true;

        // Dismiss menu
        clipWindow.isOpen = false;
    }

    // Delete item from history/pinned list
    function deleteItem(id, text) {
        if (id.startsWith("pinned_")) {
            for (let i = 0; i < pinnedModel.count; i++) {
                if (pinnedModel.get(i).clipId === id) {
                    pinnedModel.remove(i);
                    break;
                }
            }
            savePinnedSnippets();
        } else {
            let escapedText = text.replace(/'/g, "'\\''");
            let cmd = "printf '%s\\t%s' '" + id + "' '" + escapedText + "' | cliphist delete";
            deleteProcess.command = ["sh", "-c", cmd];
            deleteProcess.running = true;
        }

        // Remove from rawItems cache
        for (let i = 0; i < rawItems.length; i++) {
            if (rawItems[i].clipId === id) {
                rawItems.splice(i, 1);
                break;
            }
        }

        // Instant UI response - remove from the visual list
        for (let i = 0; i < clipModel.count; i++) {
            if (clipModel.get(i).clipId === id) {
                clipModel.remove(i);
                break;
            }
        }

        // Update latest card if deleted the top item
        if (latestId === id) {
            if (rawItems.length > 0) {
                latestId = rawItems[0].clipId;
                latestText = rawItems[0].clipText;
                latestType = rawItems[0].clipType;
                isLatestPinned = rawItems[0].pinned;
            } else {
                latestId = "";
                latestText = "";
                latestType = "text";
                isLatestPinned = false;
            }
        }
    }

    // Toggle pin on the latest item
    function togglePinLatest() {
        if (!latestText) return;

        if (isLatestPinned) {
            // Unpin
            for (let i = 0; i < pinnedModel.count; i++) {
                if (pinnedModel.get(i).clipText === latestText) {
                    pinnedModel.remove(i);
                    break;
                }
            }
            isLatestPinned = false;
        } else {
            // Pin
            let newId = "pinned_" + Date.now();
            pinnedModel.append({
                "clipId": newId,
                "clipText": latestText,
                "clipType": latestType,
                "pinned": true
            });
            isLatestPinned = true;
        }
        savePinnedSnippets();
        loadHistory(getHistoryProcess.stdout.text);
    }

    // Toggle pin on list items
    function togglePinItem(id, text, type, pinned) {
        if (pinned) {
            // Unpin
            for (let i = 0; i < pinnedModel.count; i++) {
                if (pinnedModel.get(i).clipText === text) {
                    pinnedModel.remove(i);
                    break;
                }
            }
        } else {
            // Pin
            let newId = "pinned_" + Date.now();
            pinnedModel.append({
                "clipId": newId,
                "clipText": text,
                "clipType": type,
                "pinned": true
            });
        }
        savePinnedSnippets();
        loadHistory(getHistoryProcess.stdout.text);
    }

    // ==========================================
    // ИНТЕРФЕЙС И МАКЕТИРОВАНИЕ
    // ==========================================

    // Avoid menu dismissal on backdrop clicks
    MouseArea { anchors.fill: parent }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        opacity: isOpen ? 1.0 : 0.0
        visible: opacity > 0.0
        Behavior on opacity { NumberAnimation { duration: 150 } }

        // --- 1. HEADER (Shared) ---
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            
            StyledText { text: "󰅌"; color: Colors.accentBlue; font.pixelSize: 22 }
            
            StyledText { 
                text: "Clipboard Hub"
                color: Colors.textMain
                font.pixelSize: 16
                font.bold: true
                Layout.fillWidth: true
            }

            // Items count pill
            Rectangle {
                height: 20
                implicitWidth: countText.implicitWidth + 14
                radius: 10
                color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.4)
                border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
                border.width: 1

                StyledText {
                    id: countText
                    anchors.centerIn: parent
                    text: rawItems.length + " записей"
                    font.pixelSize: 10
                    color: Colors.textSub
                }
            }
            
            // Clear history button
            Rectangle {
                width: 28
                height: 28
                radius: 14
                color: clearMouse.containsMouse ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.15) : "transparent"
                border.color: clearMouse.containsMouse ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.3) : "transparent"
                border.width: 1

                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }

                StyledText { 
                    anchors.centerIn: parent
                    text: "󰃢"
                    color: clearMouse.containsMouse ? Colors.error : Colors.textSub
                    font.pixelSize: 14
                    Behavior on color { ColorAnimation { duration: 150 } }
                }

                MouseArea {
                    id: clearMouse
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    hoverEnabled: true
                    onClicked: {
                        clearProcess.running = true;
                        clipModel.clear();
                        loadHistory(""); // re-fill with only pinned snippets
                    }
                }
            }
        }

        // Header Divider
        Rectangle { 
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.2) 
        }

        // --- 2. BODY CONTAINER (Toggles between Compact and Expanded) ---
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // COMPACT STATE: Shows Latest Copied Snippet Card
            ColumnLayout {
                id: compactContent
                anchors.fill: parent
                spacing: 12
                opacity: !isExpanded && isOpen && isAnimationFinished ? 1.0 : 0.0
                visible: opacity > 0.0

                Behavior on opacity { NumberAnimation { duration: 150 } }

                // Featured Latest Snippet Card
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 14
                    color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.3)
                    border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.15)
                    border.width: 1

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 14
                        spacing: 10

                        // Card Header
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            
                            StyledText {
                                text: {
                                    if (latestType === "color") return "🎨";
                                    if (latestType === "url") return "🔗";
                                    if (latestType === "command") return "󰆍";
                                    return "📝";
                                }
                                font.pixelSize: 14
                                color: Colors.accentBlue
                            }

                            StyledText {
                                text: {
                                    if (latestType === "color") return "Цвет HEX/RGB";
                                    if (latestType === "url") return "Веб-ссылка";
                                    if (latestType === "command") return "Командная строка";
                                    if (latestType === "image") return "Изображение";
                                    return "Последний сниппет";
                                }
                                font.pixelSize: 11
                                font.bold: true
                                color: Colors.textSub
                                Layout.fillWidth: true
                            }

                            StyledText {
                                text: latestText ? (latestText.length + " симв.") : ""
                                font.pixelSize: 10
                                color: Qt.rgba(Colors.textSub.r, Colors.textSub.g, Colors.textSub.b, 0.6)
                            }
                        }

                        // Text/Image Preview container
                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            // Text preview (visible for text/color/url/command)
                            StyledText {
                                anchors.fill: parent
                                text: latestType === "image" ? "" : (latestText ? latestText.trim() : "Буфер обмена пуст")
                                font.pixelSize: 13
                                color: Colors.textMain
                                wrapMode: Text.Wrap
                                verticalAlignment: Text.AlignVCenter
                                maximumLineCount: 3
                                elide: Text.ElideRight
                                visible: latestType !== "image"
                            }

                            // Image preview (visible for images)
                            Image {
                                id: latestImagePreview
                                anchors.fill: parent
                                fillMode: Image.PreserveAspectFit
                                source: latestImagePath
                                visible: latestType === "image" && status === Image.Ready
                            }

                            // Decoding indicator
                            StyledText {
                                anchors.centerIn: parent
                                text: "Декодирование..."
                                font.pixelSize: 11
                                color: Colors.textSub
                                visible: latestType === "image" && latestImagePreview.status !== Image.Ready
                            }
                        }

                        // Card Action footer
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            visible: latestText !== ""

                            // Color chip box if type is color
                            Rectangle {
                                width: 22
                                height: 22
                                radius: 11
                                color: latestType === "color" ? latestText : "transparent"
                                border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.3)
                                border.width: 1
                                visible: latestType === "color"
                            }

                            StyledText {
                                text: {
                                    if (latestType === "color") return latestText;
                                    if (latestType === "url") return "Открыть в браузере";
                                    if (latestType === "command") return "Терминал";
                                    return "Скопировать сниппет";
                                }
                                font.pixelSize: 11
                                font.bold: true
                                color: Colors.accentBlue
                                Layout.fillWidth: true
                                visible: latestType === "color" || latestType === "url" || latestType === "command"
                                elide: Text.ElideRight
                            }

                            Item {
                                Layout.fillWidth: true
                                visible: !(latestType === "color" || latestType === "url" || latestType === "command")
                            }

                            // URL Specific action
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: compactUrlMouse.containsMouse ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2) : "transparent"
                                visible: latestType === "url"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: "󰏌"
                                    font.pixelSize: 14
                                    color: Colors.accentBlue
                                }
                                MouseArea {
                                    id: compactUrlMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        openUrlProcess.command = ["xdg-open", latestText.trim()];
                                        openUrlProcess.running = true;
                                    }
                                }
                            }

                            // Pin Latest
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: compactPinMouse.containsMouse ? Qt.rgba(Colors.accentPurple.r, Colors.accentPurple.g, Colors.accentPurple.b, 0.2) : "transparent"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: isLatestPinned ? "󰐃" : "󰐥"
                                    font.pixelSize: 14
                                    color: isLatestPinned ? Colors.accentPurple : Colors.textSub
                                }
                                MouseArea {
                                    id: compactPinMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        togglePinLatest();
                                    }
                                }
                            }

                            // Copy Latest
                            Rectangle {
                                width: 28
                                height: 28
                                radius: 14
                                color: compactCopyMouse.containsMouse ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2) : "transparent"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: "󰅌"
                                    font.pixelSize: 14
                                    color: Colors.accentBlue
                                }
                                MouseArea {
                                    id: compactCopyMouse
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    hoverEnabled: true
                                    onClicked: {
                                        copyToClipboard(latestText, latestId);
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // EXPANDED STATE: Shows Search input, Filter pills, and Staggered ListView
            ColumnLayout {
                id: expandedContent
                anchors.fill: parent
                spacing: 12
                opacity: isExpanded && isOpen && isExpandedAnimationFinished ? 1.0 : 0.0
                visible: opacity > 0.0

                Behavior on opacity { NumberAnimation { duration: 150 } }

                // 1. Search Box
                Rectangle {
                    Layout.fillWidth: true
                    height: 38
                    radius: 10
                    color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.4)
                    border.color: searchInput.activeFocus 
                        ? Colors.accentBlue 
                        : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.15)
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 12
                        anchors.rightMargin: 12
                        spacing: 8

                        StyledText {
                            text: "󰍉"
                            font.pixelSize: 15
                            color: searchInput.activeFocus ? Colors.accentBlue : Colors.textSub
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        StyledTextInput {
                            id: searchInput
                            Layout.fillWidth: true
                            color: Colors.textMain
                            font.pixelSize: 13
                            clip: true

                            Text {
                                text: "Поиск в истории..."
                                color: Qt.rgba(Colors.textSub.r, Colors.textSub.g, Colors.textSub.b, 0.4)
                                font.family: Theme.fontFamily
                                font.pixelSize: 13
                                visible: !searchInput.text && !searchInput.activeFocus
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                            }

                            onTextChanged: {
                                searchQuery = text;
                                searchDebounceTimer.restart();
                            }
                        }

                        // Clean search input
                        Rectangle {
                            width: 20
                            height: 20
                            radius: 10
                            color: clearSearchMouse.containsMouse ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.6) : "transparent"
                            visible: searchInput.text !== ""

                            StyledText {
                                anchors.centerIn: parent
                                text: "󰅖"
                                font.pixelSize: 12
                                color: Colors.textSub
                            }
                            MouseArea {
                                id: clearSearchMouse
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                hoverEnabled: true
                                onClicked: {
                                    searchInput.text = "";
                                }
                            }
                        }
                    }
                }

                // 2. Category Filter Pills (Horizontal scrollable row)
                ListView {
                    id: categoriesList
                    Layout.fillWidth: true
                    height: 30
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    
                    model: ListModel {
                        ListElement { name: "Все"; icon: "📂"; filterType: "all" }
                        ListElement { name: "Закреп"; icon: "📌"; filterType: "pinned" }
                        ListElement { name: "Текст"; icon: "📝"; filterType: "text" }
                        ListElement { name: "Ссылки"; icon: "🔗"; filterType: "url" }
                        ListElement { name: "Цвета"; icon: "🎨"; filterType: "color" }
                        ListElement { name: "Изобр."; icon: "󰋩"; filterType: "image" }
                        ListElement { name: "Команды"; icon: "󰆍"; filterType: "command" }
                    }

                    delegate: Rectangle {
                        id: pillRect
                        implicitWidth: pillRow.implicitWidth + 20
                        height: 28
                        radius: 14
                        color: activeFilter === filterType 
                            ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2)
                            : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.3)
                        border.color: activeFilter === filterType 
                            ? Colors.accentBlue 
                            : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
                        border.width: 1

                        Behavior on color { ColorAnimation { duration: 150 } }
                        Behavior on border.color { ColorAnimation { duration: 150 } }

                        RowLayout {
                            id: pillRow
                            anchors.centerIn: parent
                            spacing: 6
                            
                            StyledText {
                                text: icon
                                font.pixelSize: 11
                                color: activeFilter === filterType ? Colors.accentBlue : Colors.textSub
                            }
                            StyledText {
                                text: name
                                font.pixelSize: 11
                                font.bold: activeFilter === filterType
                                color: activeFilter === filterType ? Colors.textMain : Colors.textSub
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                activeFilter = filterType;
                                refilterList();
                            }
                        }
                    }
                }

                // 3. Scrollable History List
                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ListView {
                        id: listView
                        anchors.fill: parent
                        model: clipModel
                        spacing: 8
                        clip: true

                        // Staggered puff-out fade add animation
                        add: Transition {
                            NumberAnimation { properties: "opacity"; from: 0.0; to: 1.0; duration: 180; easing.type: Easing.OutQuad }
                            NumberAnimation { properties: "scale"; from: 0.92; to: 1.0; duration: 220; easing.type: Easing.OutBack }
                        }

                        delegate: Rectangle {
                            id: delegateItem

                            required property string clipId
                            required property string clipText
                            required property string clipType
                            required property bool pinned
                            required property int index

                            width: listView.width
                            height: Math.max(48, itemContentLayout.implicitHeight + 16)
                            radius: 12

                            // Composite hover state (combines row click area and action buttons)
                            property bool isHovered: itemMouseArea.containsMouse || itemUrlMouse.containsMouse || itemPinMouse.containsMouse || itemDelMouse.containsMouse

                            // Click row to copy (placed first so it is rendered below child layouts/buttons)
                            MouseArea {
                                id: itemMouseArea
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    copyToClipboard(delegateItem.clipText, delegateItem.clipId);
                                }
                            }

                            // Row background color transition
                            color: delegateItem.isHovered 
                                ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.5) 
                                : (delegateItem.pinned ? Qt.rgba(Colors.accentPurple.r, Colors.accentPurple.g, Colors.accentPurple.b, 0.06) : "transparent")

                            border.color: delegateItem.pinned 
                                ? Qt.rgba(Colors.accentPurple.r, Colors.accentPurple.g, Colors.accentPurple.b, 0.25) 
                                : (delegateItem.isHovered ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.15) : "transparent")
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: delegateItem.isHovered ? 100 : 0 } }
                            Behavior on border.color { ColorAnimation { duration: delegateItem.isHovered ? 100 : 0 } }

                            // Internal visual container for custom slide-up stagger animation
                            Item {
                                id: delegateInnerWrapper
                                anchors.fill: parent

                                // Initial values for entry cascade animation
                                y: 15
                                opacity: 0.0
                                scale: 0.94

                                Component.onCompleted: {
                                    entryAnim.start();
                                }

                                SequentialAnimation {
                                    id: entryAnim
                                    // Cascade stagger delay based on list index, capped at 8 items
                                    PauseAnimation { duration: Math.max(0, Math.min(delegateItem.index !== undefined ? delegateItem.index : 0, 8)) * 30 }
                                    ParallelAnimation {
                                        NumberAnimation { target: delegateInnerWrapper; property: "y"; to: 0; duration: 480; easing.type: Easing.OutQuint }
                                        NumberAnimation { target: delegateInnerWrapper; property: "opacity"; to: 1.0; duration: 500; easing.type: Easing.OutQuint }
                                        NumberAnimation { target: delegateInnerWrapper; property: "scale"; to: 1.0; duration: 480; easing.type: Easing.OutBack }
                                    }
                                }

                                Process {
                                    id: itemDecodeProcess
                                    command: ["sh", "-c", "path='" + Quickshell.env("HOME") + "/.cache/quickshell/clip_" + delegateItem.clipId + ".png'; [ -f \"$path\" ] || (mkdir -p ~/.cache/quickshell && printf '%s\\t%s' '" + delegateItem.clipId + "' '" + delegateItem.clipText.replace(/'/g, "'\\''") + "' | cliphist decode > \"$path\")"]
                                    running: delegateItem.clipType === "image" && clipWindow.isAnimationFinished && itemImagePreview.status === Image.Error
                                    onRunningChanged: {
                                        if (!running && itemImagePreview.status === Image.Error) {
                                            itemImagePreview.reload();
                                        }
                                    }
                                }

                                RowLayout {
                                    id: itemContentLayout
                                    anchors.fill: parent
                                    anchors.leftMargin: 12
                                    anchors.rightMargin: 12
                                    spacing: 12

                                    // Type Icon/Preview Indicator
                                    Rectangle {
                                        width: delegateItem.clipType === "image" ? 44 : 28
                                        height: 28
                                        radius: delegateItem.clipType === "image" ? 6 : 14
                                        color: delegateItem.clipType === "color" 
                                            ? delegateItem.clipText 
                                            : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.4)
                                        border.color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2)
                                        border.width: 1
                                        clip: true

                                        Behavior on width { NumberAnimation { duration: 150 } }

                                        StyledText {
                                            anchors.centerIn: parent
                                            text: {
                                                if (delegateItem.clipType === "color" || delegateItem.clipType === "image") return "";
                                                if (delegateItem.clipType === "url") return "🔗";
                                                if (delegateItem.clipType === "command") return "󰆍";
                                                return "📝";
                                            }
                                            font.pixelSize: 11
                                            color: Colors.accentBlue
                                            visible: delegateItem.clipType !== "color" && delegateItem.clipType !== "image"
                                        }

                                        // Image thumbnail
                                        Image {
                                            id: itemImagePreview
                                            anchors.fill: parent
                                            fillMode: Image.PreserveAspectCrop
                                            source: "file://" + Quickshell.env("HOME") + "/.cache/quickshell/clip_" + delegateItem.clipId + ".png"
                                            visible: delegateItem.clipType === "image" && status === Image.Ready

                                            function reload() {
                                                let temp = source;
                                                source = "";
                                                source = temp;
                                            }
                                        }

                                        // Placeholder icon when image is loading
                                        StyledText {
                                            anchors.centerIn: parent
                                            text: "󰋩"
                                            font.pixelSize: 11
                                            color: Colors.textSub
                                            visible: delegateItem.clipType === "image" && itemImagePreview.status !== Image.Ready
                                        }
                                    }

                                    // Item details
                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        StyledText {
                                            text: {
                                                if (delegateItem.clipType === "image") {
                                                    let text = delegateItem.clipText;
                                                    let format = "Изображение";
                                                    if (text.includes("png")) format = "Изображение PNG";
                                                    else if (text.includes("jpg") || text.includes("jpeg")) format = "Изображение JPEG";
                                                    return format;
                                                }
                                                return delegateItem.clipText.trim();
                                            }
                                            color: Colors.textMain
                                            font.pixelSize: 13
                                            wrapMode: Text.Wrap
                                            Layout.fillWidth: true
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        StyledText {
                                            text: {
                                                let typeName = "Текст";
                                                if (delegateItem.clipType === "url") typeName = "Ссылка";
                                                if (delegateItem.clipType === "color") typeName = "Цвет";
                                                if (delegateItem.clipType === "command") typeName = "Команда";
                                                if (delegateItem.clipType === "image") {
                                                    let matches = delegateItem.clipText.match(/\d+x\d+/);
                                                    let size = matches ? (" • " + matches[0]) : "";
                                                    return "Картинка" + size + (delegateItem.pinned ? " • Закреплено" : "");
                                                }
                                                let status = delegateItem.pinned ? " • Закреплено" : "";
                                                return typeName + " (" + delegateItem.clipText.length + " симв.)" + status;
                                            }
                                            color: delegateItem.pinned ? Colors.accentPurple : Colors.textSub
                                            font.pixelSize: 10
                                            opacity: 0.7
                                        }
                                    }

                                    // Hover Actions
                                    RowLayout {
                                        spacing: 4
                                        opacity: delegateItem.isHovered || delegateItem.pinned ? 1.0 : 0.0
                                        visible: opacity > 0.0
                                        Behavior on opacity {
                                            NumberAnimation { duration: (delegateItem.isHovered || delegateItem.pinned) ? 100 : 0 }
                                        }

                                        // URL Specific action
                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 13
                                            color: itemUrlMouse.containsMouse ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2) : "transparent"
                                            visible: delegateItem.clipType === "url"

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: "󰏌"
                                                font.pixelSize: 12
                                                color: Colors.accentBlue
                                            }
                                            MouseArea {
                                                id: itemUrlMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: {
                                                    openUrlProcess.command = ["xdg-open", delegateItem.clipText.trim()];
                                                    openUrlProcess.running = true;
                                                }
                                            }
                                        }

                                        // Pin Action
                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 13
                                            color: itemPinMouse.containsMouse ? Qt.rgba(Colors.accentPurple.r, Colors.accentPurple.g, Colors.accentPurple.b, 0.2) : "transparent"

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: delegateItem.pinned ? "󰐃" : "󰐥"
                                                font.pixelSize: 12
                                                color: delegateItem.pinned ? Colors.accentPurple : Colors.textSub
                                            }
                                            MouseArea {
                                                id: itemPinMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: {
                                                    togglePinItem(delegateItem.clipId, delegateItem.clipText, delegateItem.clipType, delegateItem.pinned);
                                                }
                                            }
                                        }

                                        // Delete Action
                                        Rectangle {
                                            width: 26
                                            height: 26
                                            radius: 13
                                            color: itemDelMouse.containsMouse ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2) : "transparent"

                                            StyledText {
                                                anchors.centerIn: parent
                                                text: "󰃢"
                                                font.pixelSize: 12
                                                color: itemDelMouse.containsMouse ? Colors.error : Colors.textSub
                                            }
                                            MouseArea {
                                                id: itemDelMouse
                                                anchors.fill: parent
                                                cursorShape: Qt.PointingHandCursor
                                                hoverEnabled: true
                                                onClicked: {
                                                    deleteItem(delegateItem.clipId, delegateItem.clipText);
                                                }
                                            }
                                        }
                                    }
                                }
                            }


                        }
                    }

                    // Minimal Custom Scrollbar
                    Rectangle {
                        id: scrollbar
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: 4
                        radius: 2
                        color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
                        visible: listView.contentHeight > listView.height

                        Rectangle {
                            width: parent.width
                            height: Math.max(30, listView.height * (listView.height / listView.contentHeight))
                            y: listView.contentY * (listView.height / listView.contentHeight)
                            radius: 2
                            color: Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.4)
                        }
                    }

                    // Empty state fallback
                    StyledText {
                        anchors.centerIn: parent
                        text: searchInput.text !== "" ? "Совпадений не найдено" : "История буфера пуста"
                        color: Colors.textSub
                        font.pixelSize: 13
                        visible: listView.count === 0 && clipWindow.isAnimationFinished
                    }
                }
            }
        }

        // Divider above Footer
        Rectangle { 
            Layout.fillWidth: true
            height: 1
            color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.2) 
        }

        // --- 3. FOOTER BUTTON (Toggle compact/expanded layout) ---
        Rectangle {
            Layout.fillWidth: true
            height: 32
            radius: 8
            color: footerMouse.containsMouse ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.4) : "transparent"

            RowLayout {
                anchors.centerIn: parent
                spacing: 6
                
                StyledText {
                    text: isExpanded ? "󰅃" : "󰅀"
                    font.pixelSize: 13
                    color: Colors.accentBlue
                }
                StyledText {
                    text: isExpanded ? "Свернуть историю" : "Показать всю историю"
                    font.pixelSize: 12
                    font.bold: true
                    color: Colors.textSub
                }
            }

            MouseArea {
                id: footerMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: {
                    isExpanded = !isExpanded;
                }
            }
        }
    }
}