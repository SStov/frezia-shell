import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"
import "../components"

PanelWindow {
    id: rootWindow
    
    WlrLayershell.namespace: "qs-wallpaper"
    WlrLayershell.layer: WlrLayer.Overlay
    
    // Dynamically grab exclusive focus when opened, so Esc and typing works instantly
    WlrLayershell.keyboardFocus: rootWindow.isOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    exclusionMode: ExclusionMode.Ignore
    
    // ==========================================
    // PROPERTIES & GLOBAL STATE
    // ==========================================
    property bool isOpen: false
    property bool panelVisible: false
    visible: panelVisible
    
    property string wallDir: ""
    property bool useMatugen: true
    
    property int activeTab: 0 // 0 = Local Archive, 1 = Wallhaven, 2 = Konachan
    property string localQuery: ""
    property string wallhavenQuery: ""
    property string konachanQuery: ""
    property bool isSearchingRemote: false
    
    // Wallhaven API advanced search settings
    property bool catGeneral: true
    property bool catAnime: true
    property bool catPeople: false
    property string wallhavenSort: "relevance" // relevance, date, views, favorites, toplist, random
    property int wallhavenPage: 1
    property int wallhavenLastPage: 1
    
    // Konachan API settings
    property int konachanPage: 1
    
    // Scanned local files cache
    property var allFiles: []
    
    // Active preview wallpaper state
    property string activePreviewPath: ""
    property string activePreviewName: ""
    property string activePreviewResolution: ""
    property string activePreviewFileSize: ""
    property string activePreviewSource: ""
    property string activePreviewDomColor: "#89b4fa"
    property bool activePreviewIsRemote: false
    property var activePreviewRawItem: null
    
    // Theme DNA colors extracted from the selected wallpaper
    property var dnaPalette: ["#1e1e2e", "#313244", "#89b4fa", "#cba6f7", "#a6adc8", "#cdd6f4"]

    // Slide-in controls
    property bool startAnim: false
    
    // File view to read the currently active wallpaper path on load
    FileView {
        id: currentWallFile
        path: Quickshell.env("HOME") + "/.config/quickshell/core/current_wallpaper.txt"
        watchChanges: true
        onLoaded: {
            // Select active wallpaper on start if local scan finished
            selectActiveWallpaperOnOpen();
        }
    }

    // Helper to format file paths for Qt Image source
    function toFileUrl(filePath) {
        if (!filePath) return "";
        if (filePath.startsWith("file://") || filePath.startsWith("http://") || filePath.startsWith("https://")) {
            return filePath;
        }
        return "file://" + encodeURI(filePath).replace(/#/g, "%23");
    }
    
    // Helper to format rgb values to hex
    function rgbToHex(r, g, b) {
        let rs = Math.round(r).toString(16).padStart(2, '0');
        let gs = Math.round(g).toString(16).padStart(2, '0');
        let bs = Math.round(b).toString(16).padStart(2, '0');
        return "#" + rs + gs + bs;
    }
    
    // Generate dynamic 6-color palette based on dominant color
    function updateDnaPalette(baseHex) {
        if (!baseHex || baseHex.length < 7) return;
        let r = parseInt(baseHex.substring(1,3), 16);
        let g = parseInt(baseHex.substring(3,5), 16);
        let b = parseInt(baseHex.substring(5,7), 16);
        
        let c1 = baseHex;
        let c2 = rgbToHex(Math.min(r + 50, 255), Math.min(g + 20, 255), Math.min(b + 20, 255));
        let c3 = rgbToHex(Math.max(r - 35, 0), Math.max(g - 35, 0), Math.max(b - 15, 0));
        let c4 = rgbToHex(Math.min(g + 40, 255), Math.min(b + 60, 255), Math.min(r + 40, 255));
        let c5 = rgbToHex(Math.min(b + 50, 255), Math.min(r + 50, 255), Math.min(g + 50, 255));
        let c6 = rgbToHex(255 - r, 255 - g, 255 - b);
        
        dnaPalette = [c1, c2, c3, c4, c5, c6];
    }
    
    function selectWallpaper(item) {
        if (!item || item.isLoadMore) return;
        activePreviewRawItem = item;
        activePreviewPath = item.filePath;
        activePreviewName = item.fileName;
        activePreviewResolution = item.resolution || "Unknown";
        activePreviewFileSize = item.fileSize || "Unknown";
        activePreviewIsRemote = item.isRemote;
        activePreviewDomColor = item.dominantColor || "#1c1c22";
        activePreviewSource = item.isRemote ? (item.fileName.startsWith("konachan") ? "Konachan Portal" : "Wallhaven Portal") : "Local Archive";
        
        updateDnaPalette(activePreviewDomColor);
    }
    
    function selectActiveWallpaperOnOpen() {
        let textVal = typeof currentWallFile.text === 'function' ? currentWallFile.text() : currentWallFile.text;
        let activePath = textVal ? textVal.trim() : "";
        if (activePath === "" && allFiles.length > 0) {
            selectWallpaper(allFiles[0]);
            return;
        }
        
        for (let i = 0; i < allFiles.length; i++) {
            if (allFiles[i].filePath === activePath) {
                selectWallpaper(allFiles[i]);
                return;
            }
        }
        
        if (allFiles.length > 0) {
            selectWallpaper(allFiles[0]);
        }
    }

    // ==========================================
    // BASH PROCESSES (CORE SYSTEM ACTIONS)
    // ==========================================
    
    // Fast scanner that builds thumbnails + metadata file caches and outputs JSON (stripping newlines)
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
            
            # Check for system XDG thumbnail (xx-large 1024x1024, x-large 512x512, large 256x256, normal 128x128)
            real_f=\$(realpath "\$f")
            uri="file://\$real_f"
            md5_hash=\$(echo -n "\$uri" | md5sum | cut -d' ' -f1)
            xdg_thumb="\$HOME/.cache/thumbnails/xx-large/\$md5_hash.png"
            [ -f "\$xdg_thumb" ] || xdg_thumb="\$HOME/.cache/thumbnails/x-large/\$md5_hash.png"
            [ -f "\$xdg_thumb" ] || xdg_thumb="\$HOME/.cache/thumbnails/large/\$md5_hash.png"
            [ -f "\$xdg_thumb" ] || xdg_thumb="\$HOME/.cache/thumbnails/normal/\$md5_hash.png"
            
            if [ -f "\$xdg_thumb" ]; then
                # System thumbnail exists, use it!
                t_esc=\$(echo -n "\$xdg_thumb" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
            else
                # Generate our own custom thumbnail (optimized 640x480 for sharp grid rendering)
                thumb="\$THUMB_DIR/\$n.thumb.jpg"
                if [ ! -f "\$thumb" ]; then
                    # Try using fast system packages for thumbnailing
                    if command -v vipsthumbnail >/dev/null 2>&1; then
                        vipsthumbnail -s 640x480 -o "\$thumb" "\$f" 2>/dev/null &
                    elif command -v gdk-pixbuf-thumbnailer >/dev/null 2>&1; then
                        gdk-pixbuf-thumbnailer -s 640 "\$f" "\$thumb" 2>/dev/null &
                    elif command -v magick >/dev/null 2>&1; then
                        magick "\$f" -thumbnail 640x480^ -gravity center -extent 640x480 -quality 80 "\$thumb" 2>/dev/null &
                    else
                        convert "\$f" -thumbnail 640x480^ -gravity center -extent 640x480 -quality 80 "\$thumb" 2>/dev/null &
                    fi
                    t_esc=\$(echo -n "\$f" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
                else
                    t_esc=\$(echo -n "\$thumb" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
                fi
            fi
            
            meta_file="\$THUMB_DIR/\$n.meta"
            # Read cached metadata or extract (res, size, dominant color) - with strict newline removal
            if [ -f "$meta_file" ]; then
                IFS='|' read -r res size dom_c_hex < "$meta_file"
            else
                res=\$( (magick identify -format "%wx%h" "$f" 2>/dev/null || identify -format "%wx%h" "$f" 2>/dev/null || echo "Unknown") | tr -d '\\n')
                size=\$(stat -c %s "$f" 2>/dev/null | tr -d '\\n')
                dom_c=\$( (magick "$f" -scale 1x1\\! -format "%[hex:u]" info: 2>/dev/null || convert "$f" -scale 1x1\\! -format "%[hex:u]" info: 2>/dev/null || echo "1c1c22") | tr -d '\\n')
                dom_c_hex="#\${dom_c:0:6}"
                echo -n "\$res|\$size|\$dom_c_hex" > "$meta_file"
            fi

            n_esc=\$(echo -n "\$n" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
            f_esc=\$(echo -n "\$f" | sed 's/\\\\/\\\\\\\\/g; s/"/\\\\"/g')
            
            echo -n "{\\"fileName\\":\\"\$n_esc\\",\\"filePath\\":\\"\$f_esc\\",\\"thumbPath\\":\\"\$t_esc\\",\\"dominantColor\\":\\"\$dom_c_hex\\",\\"resolution\\":\\"\$res\\",\\"fileSize\\":\\"\$size\\",\\"isRemote\\":false},"
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

    // Apply local wallpaper
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

    // Download Wallhaven/Konachan wallpaper and set it
    Process {
        id: downloadAndApply
        function run(url, name) {
            running = false;
            let ext = url.split('.').pop() || "jpg";
            // Clean filename and ensure extension is valid
            if (ext.includes("?")) ext = ext.split('?')[0];
            let dest = "/home/stul/Pictures/wallpapers/" + name + "." + ext;
            command = [
                "bash", "-c",
                "notify-send 'Wallpaper' 'Скачиваю обои... ⏳' -a 'Wallpaper'; " +
                "wget -q -O '" + dest + "' '" + url + "'; " +
                "if [ $? -eq 0 ]; then " +
                "  notify-send 'Wallpaper' 'Обои установлены! ✅' -a 'Wallpaper'; " +
                "  /home/stul/.local/bin/swww-matugen.sh '" + dest + "'; " +
                "else " +
                "  notify-send 'Wallpaper' 'Ошибка скачивания ❌' -a 'Wallpaper' -u critical; " +
                "fi"
            ];
            running = true;
        }
    }

    // ==========================================
    // FILTER & SEARCH LOGIC
    // ==========================================
    // Chunked loading state to prevent UI freeze during large folder loads
    property var pendingAppendItems: []
    property int appendIndex: 0

    Timer {
        id: appendTimer
        interval: 16 // spacing insertion to execute over multiple screen frames
        repeat: true
        onTriggered: {
            let batchSize = 8;
            let end = Math.min(appendIndex + batchSize, pendingAppendItems.length);
            for (let i = appendIndex; i < end; i++) {
                wallModel.append(pendingAppendItems[i]);
            }
            appendIndex = end;
            if (appendIndex >= pendingAppendItems.length) {
                appendTimer.stop();
                if (wallModel.count > 0 && activePreviewPath === "") {
                    selectWallpaper(wallModel.get(0));
                }
            }
        }
    }

    function filterLocalModel(query) {
        appendTimer.stop();
        wallModel.clear();
        
        let temp = [];
        let q = query.toLowerCase();
        for (let i = 0; i < allFiles.length; i++) {
            let fObj = allFiles[i];
            if (fObj.fileName.toLowerCase().includes(q)) {
                let sizeMb = fObj.fileSize ? (fObj.fileSize / (1024 * 1024)).toFixed(1) + " MB" : "Unknown";
                temp.push({ 
                    fileName: fObj.fileName, 
                    filePath: fObj.filePath, 
                    thumbPath: fObj.thumbPath,
                    dominantColor: fObj.dominantColor || "#1c1c22",
                    resolution: fObj.resolution || "Unknown",
                    fileSize: sizeMb,
                    isRemote: false,
                    isLoadMore: false
                });
            }
        }
        
        pendingAppendItems = temp;
        appendIndex = 0;
        appendTimer.start();
    }

    // Remote source 1: Wallhaven CC
    function fetchWallhaven(query, append = false) {
        if (!append) {
            appendTimer.stop();
            wallModel.clear();
            wallhavenPage = 1;
        }
        rootWindow.isSearchingRemote = true;
        
        let xhr = new XMLHttpRequest();
        let url = "https://wallhaven.cc/api/v1/search?purity=100";
        let categories = (catGeneral ? "1" : "0") + (catAnime ? "1" : "0") + (catPeople ? "1" : "0");
        url += "&categories=" + categories;
        url += "&sorting=" + wallhavenSort;
        url += "&page=" + wallhavenPage;
        
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
                        let meta = json.meta;
                        if (meta) {
                            wallhavenLastPage = meta.last_page;
                        }
                        
                        // Remove temporary "Load More" capsule
                        if (append && wallModel.count > 0 && wallModel.get(wallModel.count - 1).isLoadMore) {
                            wallModel.remove(wallModel.count - 1);
                        }
                        
                        if (data && data.length > 0) {
                            for (let i = 0; i < data.length; i++) {
                                let item = data[i];
                                let domColor = (item.colors && item.colors.length > 0) ? item.colors[0] : "#1c1c22";
                                let sizeMb = (item.file_size / (1024 * 1024)).toFixed(1) + " MB";
                                wallModel.append({
                                    fileName: "wallhaven-" + item.id,
                                    filePath: item.path,
                                    thumbPath: item.thumbs.small || item.thumbs.original,
                                    dominantColor: domColor,
                                    resolution: item.resolution || "Unknown",
                                    fileSize: sizeMb,
                                    isRemote: true,
                                    isLoadMore: false
                                });
                            }
                            
                            // If more pages exist, append the load-more node
                            if (wallhavenPage < wallhavenLastPage) {
                                wallModel.append({
                                    fileName: "Load More",
                                    filePath: "",
                                    thumbPath: "",
                                    dominantColor: Colors.accentPurple,
                                    resolution: "",
                                    fileSize: "",
                                    isRemote: true,
                                    isLoadMore: true
                                });
                            }
                        }
                        
                        // Autoselect first item if preview is empty
                        if (wallModel.count > 0 && activePreviewPath === "") {
                            selectWallpaper(wallModel.get(0));
                        }
                    } catch(e) {
                        console.log("XHR parsing error:", e);
                    }
                }
            }
        }
        xhr.send();
    }
    
    function fetchNextWallhavenPage() {
        wallhavenPage++;
        fetchWallhaven(rootWindow.wallhavenQuery, true);
    }

    // Remote source 2: Konachan.net (SFW mirror of Konachan.com)
    function fetchKonachan(query, append = false) {
        if (!append) {
            appendTimer.stop();
            wallModel.clear();
            konachanPage = 1;
        }
        rootWindow.isSearchingRemote = true;
        
        let xhr = new XMLHttpRequest();
        let url = "https://konachan.net/post.json?limit=24";
        url += "&page=" + konachanPage;
        
        if (query.trim() !== "") {
            url += "&tags=" + encodeURIComponent(query);
        }
        
        xhr.open("GET", url);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                rootWindow.isSearchingRemote = false;
                if (xhr.status === 200) {
                    try {
                        let data = JSON.parse(xhr.responseText);
                        
                        // Remove temporary "Load More" capsule
                        if (append && wallModel.count > 0 && wallModel.get(wallModel.count - 1).isLoadMore) {
                            wallModel.remove(wallModel.count - 1);
                        }
                        
                        if (data && data.length > 0) {
                            for (let i = 0; i < data.length; i++) {
                                let item = data[i];
                                // Filter SFW ratings (s = safe)
                                if (item.rating !== 's') continue;
                                
                                let sizeMb = (item.file_size / (1024 * 1024)).toFixed(1) + " MB";
                                wallModel.append({
                                    fileName: "konachan-" + item.id,
                                    filePath: item.file_url,
                                    thumbPath: item.preview_url || item.sample_url,
                                    dominantColor: "#cba6f7", // Konachan brand color (pastel purple)
                                    resolution: item.width + "x" + item.height,
                                    fileSize: sizeMb,
                                    isRemote: true,
                                    isLoadMore: false
                                });
                            }
                            
                            // Append Load More node
                            wallModel.append({
                                fileName: "Load More",
                                filePath: "",
                                thumbPath: "",
                                dominantColor: Colors.accentPurple,
                                resolution: "",
                                fileSize: "",
                                isRemote: true,
                                isLoadMore: true
                            });
                        }
                        
                        // Autoselect first item if preview is empty
                        if (wallModel.count > 0 && activePreviewPath === "") {
                            selectWallpaper(wallModel.get(0));
                        }
                    } catch(e) {
                        console.log("Konachan JSON parsing error:", e);
                    }
                }
            }
        }
        xhr.send();
    }
    
    function fetchNextKonachanPage() {
        konachanPage++;
        fetchKonachan(rootWindow.konachanQuery, true);
    }

    Timer {
        id: wallhavenTimer
        interval: 650 
        repeat: false
        onTriggered: rootWindow.fetchWallhaven(rootWindow.wallhavenQuery)
    }

    Timer {
        id: konachanTimer
        interval: 650 
        repeat: false
        onTriggered: rootWindow.fetchKonachan(rootWindow.konachanQuery)
    }

    function applySelected() {
        if (!activePreviewPath) return;
        if (activePreviewIsRemote) {
            downloadAndApply.run(activePreviewPath, activePreviewName);
        } else {
            applyWall.run(activePreviewPath);
        }
        rootWindow.isOpen = false;
    }

    // ==========================================
    // WINDOW OPEN/CLOSE TRANSITIONS
    // ==========================================
    onIsOpenChanged: {
        if (isOpen) {
            hideTimer.stop();
            panelVisible = true;
            activeTab = 0; 
            localQuery = "";
            wallhavenQuery = "";
            konachanQuery = "";
            searchInput.text = "";
            startAnim = true;
            fetchWallpapers.refresh();
            currentWallFile.reload();
            
            // Force focus on opening
            Qt.callLater(() => {
                searchInput.forceActiveFocus();
            });
        } else {
            startAnim = false;
            hideTimer.restart();
        }
    }

    Timer {
        id: hideTimer
        interval: 450
        repeat: false
        onTriggered: { if (!rootWindow.isOpen) rootWindow.panelVisible = false; }
    }

    // ==========================================
    // EVENT FILTERING & ESCAPE KEYS
    // ==========================================
    MouseArea {
        anchors.fill: parent
        onClicked: rootWindow.isOpen = false
    }

    Shortcut {
        sequence: "Escape"
        enabled: rootWindow.isOpen
        onActivated: rootWindow.isOpen = false
    }

    Item {
        id: layoutContainer
        anchors.fill: parent
        
        state: rootWindow.isOpen ? "open" : "closed"
        
        states: [
            State {
                name: "closed"
                PropertyChanges { target: backdropDim; opacity: 0.0 }
                PropertyChanges { target: leftPanel; opacity: 0.0; yOffset: 100.0 }
                PropertyChanges { target: rightPanel; opacity: 0.0; yOffset: 100.0 }
            },
            State {
                name: "open"
                PropertyChanges { target: backdropDim; opacity: 0.65 }
                PropertyChanges { target: leftPanel; opacity: 1.0; yOffset: 0.0 }
                PropertyChanges { target: rightPanel; opacity: 1.0; yOffset: 0.0 }
            }
        ]
        
        transitions: [
            Transition {
                from: "closed"; to: "open"
                ParallelAnimation {
                    NumberAnimation {
                        target: backdropDim
                        property: "opacity"
                        duration: 350
                        easing.type: Easing.OutCubic
                    }
                    
                    SequentialAnimation {
                        ParallelAnimation {
                            NumberAnimation { target: leftPanel; property: "opacity"; duration: 400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: leftPanel; property: "yOffset"; duration: 550; easing.type: Easing.OutQuint }
                        }
                    }
                    
                    SequentialAnimation {
                        PauseAnimation { duration: 100 }
                        ParallelAnimation {
                            NumberAnimation { target: rightPanel; property: "opacity"; duration: 400; easing.type: Easing.OutCubic }
                            NumberAnimation { target: rightPanel; property: "yOffset"; duration: 550; easing.type: Easing.OutQuint }
                        }
                    }
                }
            },
            Transition {
                from: "open"; to: "closed"
                ParallelAnimation {
                    NumberAnimation { target: backdropDim; property: "opacity"; duration: 250; easing.type: Easing.InCubic }
                    NumberAnimation { target: leftPanel; property: "opacity"; duration: 250; easing.type: Easing.InCubic }
                    NumberAnimation { target: leftPanel; property: "yOffset"; duration: 300; easing.type: Easing.InCubic }
                    NumberAnimation { target: rightPanel; property: "opacity"; duration: 250; easing.type: Easing.InCubic }
                    NumberAnimation { target: rightPanel; property: "yOffset"; duration: 300; easing.type: Easing.InCubic }
                }
            }
        ]

        // Screen-dimming background
        Rectangle {
            id: backdropDim
            anchors.fill: parent
            color: "#070709"
            opacity: 0.0
        }

    // ==========================================
    // MAIN HUD WORKSPACE
    // ==========================================
    
    // LEFT PANEL: The Canvas Preview & DNA Analyzer
    Rectangle {
        id: leftPanel
        width: 440
        height: parent.height - 80
        x: 40
        y: 40
        radius: 24
        color: Colors.opacify(Colors.card, 0.70)
        border.color: Colors.opacify(Colors.outline, 0.15)
        border.width: 1
        opacity: 0.0

        property real yOffset: 100.0
        transform: Translate { y: leftPanel.yOffset }
        
        // Prevent click events from propagating to backdropDim
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 20

            // Panel header
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    text: "THE CANVAS"
                    font.pixelSize: 11
                    font.bold: true
                    color: Colors.accentBlue
                }
                StyledText {
                    text: "Workspace Preview"
                    font.pixelSize: 18
                    font.bold: true
                    color: Colors.textMain
                }
            }

            // Desktop Mockup Frame
            Rectangle {
                id: monitorMock
                Layout.fillWidth: true
                Layout.preferredHeight: width * 9 / 16
                radius: 16
                color: "#16161a"
                clip: true
                border.color: Colors.opacify(Colors.outline, 0.3)
                border.width: 2

                Image {
                    id: mockWallpaper
                    anchors.fill: parent
                    source: rootWindow.activePreviewIsRemote ? rootWindow.activePreviewPath : rootWindow.toFileUrl(rootWindow.activePreviewPath)
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(800, 450)
                    asynchronous: true
                    
                    onStatusChanged: {
                        if (status === Image.Error && !rootWindow.activePreviewIsRemote && source.toString().includes("thumb.jpg")) {
                            source = rootWindow.toFileUrl(rootWindow.activePreviewPath);
                        }
                    }
                }

                // Diagonal glass reflection mockup overlay
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    color: "transparent"
                    border.width: 0
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.08) }
                        GradientStop { position: 0.4; color: Qt.rgba(1, 1, 1, 0.02) }
                        GradientStop { position: 0.41; color: "transparent" }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                // Replica TopBar
                Rectangle {
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 6
                    height: 18
                    radius: 6
                    color: Qt.rgba(0.05, 0.05, 0.07, 0.7)
                    border.color: Qt.rgba(1, 1, 1, 0.1)
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 8
                        anchors.rightMargin: 8
                        spacing: 0

                        // Mini workspaces
                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter
                            Rectangle { width: 8; height: 4; radius: 2; color: Colors.accentBlue }
                            Rectangle { width: 4; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.3) }
                            Rectangle { width: 4; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.3) }
                        }

                        Item { Layout.fillWidth: true }

                        // Mini Clock
                        Text {
                            text: "12:00"
                            color: "white"
                            font.pixelSize: 8
                            font.bold: true
                            Layout.alignment: Qt.AlignVCenter
                        }

                        Item { Layout.fillWidth: true }

                        // Mini icons
                        Row {
                            spacing: 4
                            Layout.alignment: Qt.AlignVCenter
                            Text { text: "📶"; color: "white"; font.pixelSize: 8 }
                            Text { text: "🔋"; color: "white"; font.pixelSize: 8 }
                        }
                    }
                }
            }

            // Theme DNA (Palette Analyzer)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                StyledText {
                    text: "PALETTE DNA"
                    font.pixelSize: 11
                    font.bold: true
                    color: Colors.textSub
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 12

                    Repeater {
                        model: 6
                        Rectangle {
                            width: 32
                            height: 32
                            radius: 16
                            color: rootWindow.dnaPalette[index] || "#2c2c35"
                            border.color: Colors.opacify(Colors.outline, 0.2)
                            border.width: 1

                            Behavior on color {
                                ColorAnimation { duration: 350; easing.type: Easing.OutQuad }
                            }

                            // Scaling on hover/state shift
                            scale: 1.0
                            Behavior on scale { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }

            // Divider line
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.opacify(Colors.outline, 0.15)
            }

            // Metadata Grid Info
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12
                Layout.fillHeight: true

                StyledText {
                    text: "FILE META"
                    font.pixelSize: 11
                    font.bold: true
                    color: Colors.textSub
                }

                // Table grid of keys and values
                GridLayout {
                    columns: 2
                    Layout.fillWidth: true
                    rowSpacing: 8
                    columnSpacing: 16

                    StyledText { text: "Name"; color: Colors.textSub; font.pixelSize: 12; Layout.fillWidth: true }
                    StyledText { 
                        text: rootWindow.activePreviewName ? (rootWindow.activePreviewName.length > 25 ? rootWindow.activePreviewName.substring(0, 22) + "..." : rootWindow.activePreviewName) : "None selected"
                        color: Colors.textMain
                        font.pixelSize: 12
                        font.bold: true
                        Layout.alignment: Qt.AlignRight
                    }

                    StyledText { text: "Source"; color: Colors.textSub; font.pixelSize: 12; Layout.fillWidth: true }
                    StyledText { 
                        text: rootWindow.activePreviewSource || "Unknown"
                        color: Colors.textMain
                        font.pixelSize: 12
                        font.bold: true
                        Layout.alignment: Qt.AlignRight
                    }

                    StyledText { text: "Resolution"; color: Colors.textSub; font.pixelSize: 12; Layout.fillWidth: true }
                    StyledText { 
                        text: rootWindow.activePreviewResolution || "Unknown"
                        color: Colors.textMain
                        font.pixelSize: 12
                        font.bold: true
                        Layout.alignment: Qt.AlignRight
                    }

                    StyledText { text: "File Size"; color: Colors.textSub; font.pixelSize: 12; Layout.fillWidth: true }
                    StyledText { 
                        text: rootWindow.activePreviewFileSize || "Unknown"
                        color: Colors.textMain
                        font.pixelSize: 12
                        font.bold: true
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }

            // Actions panel buttons
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 12

                // Primary apply button
                Rectangle {
                    id: btnApply
                    Layout.fillWidth: true
                    height: 48
                    radius: 14
                    color: applyMouse.containsMouse ? Colors.accentBlue : Colors.opacify(Colors.accentBlue, 0.8)
                    border.color: Colors.opacify(Colors.outline, 0.1)
                    border.width: 1

                    Behavior on color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8
                        Text { text: "⚡"; font.pixelSize: 14 }
                        StyledText {
                            text: "Apply Wallpaper"
                            font.pixelSize: 14
                            font.bold: true
                            color: Colors.bg // Dark text on bright button for high contrast
                        }
                    }

                    MouseArea {
                        id: applyMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootWindow.applySelected()
                    }
                }

                // Secondary cancel button
                Rectangle {
                    id: btnCancel
                    Layout.fillWidth: true
                    height: 44
                    radius: 14
                    color: "transparent"
                    border.color: cancelMouse.containsMouse ? Colors.textMain : Colors.opacify(Colors.outline, 0.4)
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    StyledText {
                        anchors.centerIn: parent
                        text: "Dismiss Curator"
                        font.pixelSize: 13
                        font.bold: true
                        color: Colors.textMain
                    }

                    MouseArea {
                        id: cancelMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: rootWindow.isOpen = false
                    }
                }
            }
        }
    }

    // RIGHT PANEL: The Wallpaper Explorer
    Rectangle {
        id: rightPanel
        width: parent.width - leftPanel.width - 120
        height: parent.height - 80
        x: leftPanel.x + leftPanel.width + 40
        y: 40
        radius: 24
        color: Colors.opacify(Colors.card, 0.70)
        border.color: Colors.opacify(Colors.outline, 0.15)
        border.width: 1
        opacity: 0.0

        property real yOffset: 100.0
        transform: Translate { y: rightPanel.yOffset }

        // Prevent propagation
        MouseArea { anchors.fill: parent; onClicked: {} }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 24
            spacing: 16

            // Header panel: title and stats count
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true
                    StyledText {
                        text: "THE VAULT"
                        font.pixelSize: 11
                        font.bold: true
                        color: Colors.accentPurple
                    }
                    StyledText {
                        text: rootWindow.activeTab === 0 ? "Local Archive Gallery" : (rootWindow.activeTab === 1 ? "Wallhaven Portal curator" : "Konachan Portal curator")
                        font.pixelSize: 18
                        font.bold: true
                        color: Colors.textMain
                    }
                }

                // Quick stats pill
                Rectangle {
                    height: 28
                    width: contentStats.width + 20
                    radius: 14
                    color: Colors.opacify(Colors.bg, 0.4)
                    border.color: Colors.opacify(Colors.outline, 0.2)
                    border.width: 1

                    RowLayout {
                        id: contentStats
                        anchors.centerIn: parent
                        spacing: 6
                        StyledText {
                            text: rootWindow.activeTab === 0 ? "📁" : (rootWindow.activeTab === 1 ? "🌐" : "⛩️")
                            font.pixelSize: 11
                        }
                        StyledText {
                            text: rootWindow.activeTab === 0 ? (rootWindow.allFiles.length + " walls") : "Connected"
                            font.pixelSize: 11
                            font.bold: true
                            color: Colors.textSub
                        }
                    }
                }
            }

            // Controls Toolbar (Search input + Tab selection Switch)
            RowLayout {
                Layout.fillWidth: true
                spacing: 16

                // Neon-glowing Search Input
                Rectangle {
                    id: searchBox
                    Layout.fillWidth: true
                    height: 44
                    radius: 14
                    color: Colors.opacify(Colors.bg, 0.4)
                    border.color: searchInput.activeFocus ? Colors.accentPurple : Colors.opacify(Colors.outline, 0.2)
                    border.width: 1

                    Behavior on border.color { ColorAnimation { duration: 150 } }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        spacing: 10

                        StyledText {
                            text: "🔍"
                            font.pixelSize: 14
                            opacity: 0.5
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            StyledTextInput {
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.textMain
                                font.pixelSize: 13
                                selectByMouse: true
                                selectionColor: Colors.opacify(Colors.accentPurple, 0.3)
                                selectedTextColor: "white"

                                onTextChanged: {
                                    let t = text.trim();
                                    if (rootWindow.activeTab === 0) {
                                        rootWindow.localQuery = t;
                                        rootWindow.filterLocalModel(t);
                                    } else if (rootWindow.activeTab === 1) {
                                        rootWindow.wallhavenQuery = t;
                                        wallhavenTimer.restart();
                                    } else {
                                        rootWindow.konachanQuery = t;
                                        konachanTimer.restart();
                                    }
                                }
                            }

                            // Placeholder
                            StyledText {
                                anchors.fill: parent
                                verticalAlignment: Text.AlignVCenter
                                text: rootWindow.activeTab === 0 ? "Search local wallpapers..." : (rootWindow.activeTab === 1 ? "Query Wallhaven API..." : "Query Konachan API...")
                                color: Colors.textSub
                                font.pixelSize: 13
                                opacity: searchInput.text.length === 0 ? 0.4 : 0.0
                                visible: opacity > 0
                                Behavior on opacity { NumberAnimation { duration: 100 } }
                            }
                        }

                        // Clear input button
                        StyledText {
                            text: "×"
                            font.pixelSize: 18
                            color: Colors.textSub
                            opacity: searchInput.text.length > 0 ? 0.6 : 0.0
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

                // Custom segmented tab switcher slider (3 segments now)
                Rectangle {
                    id: sourceTabSelector
                    width: 320
                    height: 44
                    radius: 14
                    color: Colors.opacify(Colors.bg, 0.4)
                    border.color: Colors.opacify(Colors.outline, 0.2)
                    border.width: 1

                    // Sliding selector highlight rectangle
                    Rectangle {
                        id: tabHighlight
                        width: (parent.width - 8) / 3
                        height: parent.height - 6
                        y: 3
                        x: rootWindow.activeTab === 0 ? 3 : (rootWindow.activeTab === 1 ? (parent.width - 6) / 3 + 3 : 2 * (parent.width - 6) / 3 + 3)
                        radius: 11
                        color: Colors.opacify(Colors.accentPurple, 0.2)
                        border.color: Colors.opacify(Colors.accentPurple, 0.4)
                        border.width: 1

                        Behavior on x { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
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
                                font.pixelSize: 12
                                font.bold: rootWindow.activeTab === 0
                                color: rootWindow.activeTab === 0 ? Colors.accentPurple : Colors.textSub
                                opacity: rootWindow.activeTab === 0 ? 1.0 : 0.6
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootWindow.activeTab = 0;
                                    searchInput.text = rootWindow.localQuery;
                                    rootWindow.filterLocalModel(rootWindow.localQuery);
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            
                            StyledText {
                                anchors.centerIn: parent
                                text: "Wallhaven"
                                font.pixelSize: 12
                                font.bold: rootWindow.activeTab === 1
                                color: rootWindow.activeTab === 1 ? Colors.accentPurple : Colors.textSub
                                opacity: rootWindow.activeTab === 1 ? 1.0 : 0.6
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootWindow.activeTab = 1;
                                    searchInput.text = rootWindow.wallhavenQuery;
                                    rootWindow.fetchWallhaven(rootWindow.wallhavenQuery);
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            color: "transparent"
                            
                            StyledText {
                                anchors.centerIn: parent
                                text: "Konachan"
                                font.pixelSize: 12
                                font.bold: rootWindow.activeTab === 2
                                color: rootWindow.activeTab === 2 ? Colors.accentPurple : Colors.textSub
                                opacity: rootWindow.activeTab === 2 ? 1.0 : 0.6
                                Behavior on color { ColorAnimation { duration: 150 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    rootWindow.activeTab = 2;
                                    searchInput.text = rootWindow.konachanQuery;
                                    rootWindow.fetchKonachan(rootWindow.konachanQuery);
                                    searchInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            // Expandable advanced Wallhaven filters toolbar (only if Wallhaven active)
            Rectangle {
                id: advancedFiltersBar
                Layout.fillWidth: true
                Layout.preferredHeight: (rootWindow.activeTab === 1) ? 44 : 0
                clip: true
                color: "transparent"
                border.width: 0
                opacity: (rootWindow.activeTab === 1) ? 1.0 : 0.0

                Behavior on Layout.preferredHeight { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                Behavior on opacity { NumberAnimation { duration: 250 } }

                RowLayout {
                    anchors.fill: parent
                    spacing: 16

                    // Categories switcher
                    RowLayout {
                        spacing: 6
                        StyledText { text: "Cat:"; font.pixelSize: 11; color: Colors.textSub; font.bold: true }

                        // General toggle chip
                        Rectangle {
                            width: textGen.width + 16; height: 26; radius: 8
                            color: rootWindow.catGeneral ? Colors.opacify(Colors.accentPurple, 0.2) : Colors.opacify(Colors.bg, 0.4)
                            border.color: rootWindow.catGeneral ? Colors.accentPurple : Colors.opacify(Colors.outline, 0.2)
                            border.width: 1
                            StyledText { id: textGen; text: "General"; font.pixelSize: 10; font.bold: true; anchors.centerIn: parent; color: rootWindow.catGeneral ? Colors.textMain : Colors.textSub }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { rootWindow.catGeneral = !rootWindow.catGeneral; rootWindow.fetchWallhaven(rootWindow.wallhavenQuery); } }
                        }
                        
                        // Anime toggle chip
                        Rectangle {
                            width: textAni.width + 16; height: 26; radius: 8
                            color: rootWindow.catAnime ? Colors.opacify(Colors.accentPurple, 0.2) : Colors.opacify(Colors.bg, 0.4)
                            border.color: rootWindow.catAnime ? Colors.accentPurple : Colors.opacify(Colors.outline, 0.2)
                            border.width: 1
                            StyledText { id: textAni; text: "Anime"; font.pixelSize: 10; font.bold: true; anchors.centerIn: parent; color: rootWindow.catAnime ? Colors.textMain : Colors.textSub }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { rootWindow.catAnime = !rootWindow.catAnime; rootWindow.fetchWallhaven(rootWindow.wallhavenQuery); } }
                        }

                        // People toggle chip
                        Rectangle {
                            width: textPeo.width + 16; height: 26; radius: 8
                            color: rootWindow.catPeople ? Colors.opacify(Colors.accentPurple, 0.2) : Colors.opacify(Colors.bg, 0.4)
                            border.color: rootWindow.catPeople ? Colors.accentPurple : Colors.opacify(Colors.outline, 0.2)
                            border.width: 1
                            StyledText { id: textPeo; text: "People"; font.pixelSize: 10; font.bold: true; anchors.centerIn: parent; color: rootWindow.catPeople ? Colors.textMain : Colors.textSub }
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { rootWindow.catPeople = !rootWindow.catPeople; rootWindow.fetchWallhaven(rootWindow.wallhavenQuery); } }
                        }
                    }

                    Rectangle { width: 1; height: 16; color: Colors.opacify(Colors.outline, 0.2) }

                    // Sort order switcher
                    RowLayout {
                        spacing: 6
                        StyledText { text: "Sort:"; font.pixelSize: 11; color: Colors.textSub; font.bold: true }

                        Repeater {
                            model: [
                                { label: "Relevance", code: "relevance" },
                                { label: "Latest", code: "date" },
                                { label: "Views", code: "views" },
                                { label: "Toplist", code: "toplist" },
                                { label: "Random", code: "random" }
                            ]
                            
                            Rectangle {
                                width: textSort.width + 12; height: 26; radius: 8
                                color: (rootWindow.wallhavenSort === modelData.code) ? Colors.opacify(Colors.accentBlue, 0.2) : Colors.opacify(Colors.bg, 0.4)
                                border.color: (rootWindow.wallhavenSort === modelData.code) ? Colors.accentBlue : Colors.opacify(Colors.outline, 0.2)
                                border.width: 1
                                StyledText { id: textSort; text: modelData.label; font.pixelSize: 10; font.bold: true; anchors.centerIn: parent; color: (rootWindow.wallhavenSort === modelData.code) ? Colors.textMain : Colors.textSub }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { rootWindow.wallhavenSort = modelData.code; rootWindow.fetchWallhaven(rootWindow.wallhavenQuery); } }
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.opacify(Colors.outline, 0.15)
            }

            // PREVIEWS GRID VIEW
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                GridView {
                    id: wallGrid
                    anchors.fill: parent
                    clip: true
                    cellWidth: width / 3
                    cellHeight: cellWidth * 0.76
                    model: ListModel { id: wallModel }

                    // Mouse wheel redirection helper to allow smooth scroll
                    MouseArea {
                        anchors.fill: parent
                        acceptedButtons: Qt.NoButton
                        onWheel: (wheel) => {
                            if (wheel.angleDelta.y !== 0) {
                                let newContentY = wallGrid.contentY - wheel.angleDelta.y * 1.5;
                                wallGrid.contentY = Math.max(wallGrid.originY, Math.min(newContentY, wallGrid.contentHeight - wallGrid.height));
                                wheel.accepted = true;
                            }
                        }
                    }

                    delegate: Item {
                        width: wallGrid.cellWidth
                        height: wallGrid.cellHeight

                        // Dynamic hover aura using the wallpaper's dominant color!
                        Rectangle {
                            id: hoverAura
                            anchors.fill: parent
                            anchors.margins: 4
                            radius: 20
                            color: model.dominantColor
                            opacity: (itemMouse.containsMouse && !model.isLoadMore) ? 0.22 : 0.0
                            scale: (itemMouse.containsMouse && !model.isLoadMore) ? 1.02 : 0.98
                            visible: opacity > 0
                            
                            Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
                        }

                        // The Card container
                        Rectangle {
                            id: cardContainer
                            anchors.fill: parent
                            anchors.margins: 10
                            radius: 16
                            color: "#16161a"
                            clip: true
                            border.color: (rootWindow.activePreviewPath === model.filePath && !model.isLoadMore) ? Colors.accentBlue : Colors.opacify(Colors.outline, 0.15)
                            border.width: (rootWindow.activePreviewPath === model.filePath && !model.isLoadMore) ? 2 : 1
                            
                            // Staggered entrance properties
                            property bool animateIn: false
                            opacity: animateIn ? 1.0 : 0.0
                            scale: animateIn ? ((itemMouse.containsMouse && !model.isLoadMore) ? 1.02 : 1.0) : 0.8
                            property real yOffset: animateIn ? 0.0 : 40.0
                            transform: Translate { y: cardContainer.yOffset }

                            Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            // Staggered animation
                            SequentialAnimation {
                                id: entranceAnim
                                running: rootWindow.isOpen // Only animate if selector is open
                                
                                PauseAnimation {
                                    duration: Math.min(index, 12) * 35 // Stagger delay capped at 12 items
                                }
                                
                                ParallelAnimation {
                                    NumberAnimation { target: cardContainer; property: "opacity"; from: 0.0; to: 1.0; duration: 350; easing.type: Easing.OutCubic }
                                    NumberAnimation { target: cardContainer; property: "scale"; from: 0.8; to: 1.0; duration: 400; easing.type: Easing.OutBack }
                                    NumberAnimation { target: cardContainer; property: "yOffset"; from: 40.0; to: 0.0; duration: 400; easing.type: Easing.OutCubic }
                                }
                                
                                onFinished: {
                                    cardContainer.animateIn = true;
                                }
                            }

                            // Image rendering
                            Image {
                                id: cardImage
                                anchors.fill: parent
                                visible: !model.isLoadMore
                                source: model.isRemote ? model.thumbPath : rootWindow.toFileUrl(model.thumbPath)
                                fillMode: Image.PreserveAspectCrop
                                sourceSize: Qt.size(640, 480)
                                asynchronous: true
                                opacity: (itemMouse.containsMouse) ? 1.0 : 0.75
                                Behavior on opacity { NumberAnimation { duration: 200 } }

                                onStatusChanged: {
                                    if (status === Image.Error && !model.isRemote && source.toString().includes("thumb.jpg")) {
                                        source = rootWindow.toFileUrl(model.filePath);
                                    }
                                }
                            }

                            // Black vignette overlay for resolution tags
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                height: 32
                                visible: !model.isLoadMore
                                color: "black"
                                opacity: itemMouse.containsMouse ? 0.65 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 200 } }
                            }

                            // Resolution label
                            StyledText {
                                text: model.resolution
                                anchors.bottom: parent.bottom
                                anchors.right: parent.right
                                anchors.margins: 8
                                font.pixelSize: 10
                                font.bold: true
                                color: "white"
                                visible: !model.isLoadMore && itemMouse.containsMouse
                            }

                            // LOAD MORE SPECIFIC CARD LAYOUT
                            ColumnLayout {
                                anchors.centerIn: parent
                                visible: model.isLoadMore
                                spacing: 8

                                StyledText {
                                    text: "🔄"
                                    font.pixelSize: 22
                                    Layout.alignment: Qt.AlignHCenter
                                }
                                StyledText {
                                    text: "Load More"
                                    font.pixelSize: 12
                                    font.bold: true
                                    color: Colors.accentPurple
                                    Layout.alignment: Qt.AlignHCenter
                                }
                            }

                            // Mouse actions
                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (model.isLoadMore) {
                                        if (rootWindow.activeTab === 1) {
                                            rootWindow.fetchNextWallhavenPage();
                                        } else {
                                            rootWindow.fetchNextKonachanPage();
                                        }
                                    } else {
                                        rootWindow.selectWallpaper(model);
                                    }
                                }
                                onDoubleClicked: {
                                    if (!model.isLoadMore) {
                                        rootWindow.selectWallpaper(model);
                                        rootWindow.applySelected();
                                    }
                                }
                            }
                        }
                    }
                }

                // EMPTY / INITIAL SEARCH PLACEHOLDER LOBBY
                ColumnLayout {
                    anchors.centerIn: parent
                    visible: wallModel.count === 0 && !rootWindow.isSearchingRemote
                    spacing: 12

                    StyledText {
                        text: "✨"
                        font.pixelSize: 32
                        Layout.alignment: Qt.AlignHCenter
                    }
                    StyledText {
                        text: "No wallpapers matches found"
                        font.pixelSize: 14
                        font.bold: true
                        color: Colors.textMain
                        Layout.alignment: Qt.AlignHCenter
                    }
                    StyledText {
                        text: "Check spelling or verify category filters"
                        font.pixelSize: 12
                        color: Colors.textSub
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                // Dynamic loading spinner overlay
                Rectangle {
                    anchors.fill: parent
                    visible: rootWindow.isSearchingRemote
                    color: Colors.opacify(Colors.bg, 0.4)
                    radius: 16

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 16

                        // Rotating loading spinner ring
                        Rectangle {
                            id: loaderRing
                            Layout.preferredWidth: 48
                            Layout.preferredHeight: 48
                            radius: 24
                            color: "transparent"
                            border.color: Colors.accentPurple
                            border.width: 4
                            Layout.alignment: Qt.AlignHCenter

                            RotationAnimation on rotation {
                                from: 0; to: 360
                                running: rootWindow.isSearchingRemote
                                loops: Animation.Infinite
                                duration: 1000
                            }
                        }

                        StyledText {
                            text: "Connecting to remote API..."
                            font.pixelSize: 12
                            font.bold: true
                            color: Colors.accentPurple
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }
            }
        }
    }
  }
}
