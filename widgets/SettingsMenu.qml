import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"
import "../components"

PanelWindow {
    id: settingsWindow
    
    WlrLayershell.namespace: "qs-settings"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    
    implicitWidth: 960
    implicitHeight: 740
    anchors.top: true
    anchors.left: true
    margins {
        top: (Screen.height - 740) / 2
        left: (Screen.width - 960) / 2
    }
    color: "transparent"
    visible: false
    
    function toggle() { visible = !visible }

    property int activeTab: 0
    property alias imageWidgets: sysSettings.imageWidgets
    property alias editMode: sysSettings.editMode
    property alias fontFamily: sysSettings.fontFamily

    function updateImageWidget(index, obj) { sysSettings.updateImageWidget(index, obj); }
    function removeImageWidget(index) { sysSettings.removeImageWidget(index); }

    // ALIASES
    property alias useMatugen: sysSettings.useMatugen
    property alias matugenMode: sysSettings.matugenMode
    property alias matugenScheme: sysSettings.matugenScheme
    property alias globalBorders: sysSettings.globalBorders
    property alias wallDir: sysSettings.wallDir
    property alias topBarOpacity: sysSettings.topBarOpacity
    property alias animDuration: sysSettings.animDuration
    property alias topBarHeight: sysSettings.topBarHeight
    property alias topBarWidth: sysSettings.topBarWidth
    property alias topBarMarginTop: sysSettings.topBarMarginTop
    property alias topBarMarginSide: sysSettings.topBarMarginSide
    property alias topBarPosition: sysSettings.topBarPosition
    property alias topBarOrder: sysSettings.topBarOrder
    property alias topBarStyle: sysSettings.topBarStyle
    property alias topBarTraySpacing: sysSettings.topBarTraySpacing
    property alias cornerMode: sysSettings.cornerMode
    property alias cornerRadius: sysSettings.cornerRadius
    property alias mediaPlayerWidth: sysSettings.mediaPlayerWidth
    property alias mediaPlayerPosition: sysSettings.mediaPlayerPosition

    // ==========================================
    // WHISKER-STYLE COMPONENTS
    // ==========================================
    
    component SectionHeader : RowLayout {
        property string iconText: ""
        property string titleText: ""
        spacing: 12
        Layout.topMargin: 10
        StyledText { text: iconText; font.pixelSize: 22; color: Colors.textMain; font.family: "Material Symbols Outlined" }
        StyledText { text: titleText; font.pixelSize: 20; font.family: "Outfit"; font.bold: true; color: Colors.textMain }
    }

    component WhiskerSlider : ColumnLayout {
        property string iconText: ""
        property string titleText: ""
        property real value: 0
        property real from: 0
        property real to: 100
        property string suffix: ""
        property bool isInt: true
        signal valueModified(real val)

        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            StyledText { text: iconText; font.pixelSize: 18; color: Colors.textMain; visible: iconText !== "" }
            StyledText { text: titleText; font.pixelSize: 14; color: Colors.textMain; font.family: "Outfit Medium"; Layout.fillWidth: true }
            StyledText { text: (isInt ? Math.round(value) : value.toFixed(2)) + suffix; font.pixelSize: 14; color: Colors.textMain; font.family: "Outfit Medium" }
        }

        Item {
            Layout.fillWidth: true
            height: 34
            
            Rectangle {
                anchors.fill: parent
                radius: 12
                color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.15)
            }
            
            Rectangle {
                id: trackFill
                width: Math.max(radius * 2, parent.width * ((value - from) / (to - from)))
                height: parent.height
                radius: 12
                color: Colors.accentPurple
            }
            
            Rectangle {
                width: 5
                height: parent.height + 10
                radius: 2.5
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(parent.width - width, trackFill.width - width/2))
                color: Colors.accentPurple
            }

            MouseArea {
                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                function updateVal(mx) {
                    let p = Math.max(0, Math.min(1, mx / width))
                    valueModified(from + p * (to - from))
                }
                onClicked: (m) => updateVal(m.x)
                onPositionChanged: (m) => { if(pressed) updateVal(m.x) }
            }
        }
    }

    component WhiskerToggle : Rectangle {
        property string iconText: ""
        property string titleText: ""
        property string subtitleText: ""
        property bool checked: false
        signal toggled()

        Layout.fillWidth: true
        height: 100
        radius: 16
        color: checked ? Colors.accentPurple : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
        Behavior on color { ColorAnimation { duration: 200 } }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 4
            
            StyledText { 
                text: iconText; font.pixelSize: 22
                color: parent.parent.checked ? Colors.bg : Colors.textMain
            }
            Item { Layout.fillHeight: true }
            StyledText { 
                text: titleText; font.pixelSize: 15; font.family: "Outfit Medium"
                color: parent.parent.checked ? Colors.bg : Colors.textMain
            }
            StyledText { 
                text: subtitleText; font.pixelSize: 12
                color: parent.parent.checked ? Qt.rgba(Colors.bg.r, Colors.bg.g, Colors.bg.b, 0.7) : Colors.textSub
            }
        }
        
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: parent.toggled() }
    }

    component WhiskerSegmented : RowLayout {
        property var options: []
        property var currentValue
        property int rowHeight: 44
        signal selected(var val)
        
        spacing: 8
        
        Repeater {
            model: options
            Rectangle {
                Layout.fillWidth: true
                height: rowHeight
                radius: 12
                color: currentValue === modelData.value ? Colors.accentPurple : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
                Behavior on color { ColorAnimation { duration: 150 } }
                
                RowLayout {
                    anchors.centerIn: parent
                    spacing: 6
                    StyledText { text: modelData.icon !== undefined ? modelData.icon : ""; font.pixelSize: 16; color: currentValue === modelData.value ? Colors.bg : Colors.textMain; visible: modelData.icon !== undefined }
                    StyledText { text: modelData.label; font.pixelSize: 14; font.family: "Outfit Medium"; color: currentValue === modelData.value ? Colors.bg : Colors.textMain }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: selected(modelData.value) }
            }
        }
    }

    component WhiskerInput : ColumnLayout {
        property string titleText: ""
        property alias text: inputField.text
        signal editingFinished()
        
        spacing: 8
        StyledText { text: titleText; font.pixelSize: 14; color: Colors.textMain; font.family: "Outfit Medium" }
        Rectangle {
            Layout.fillWidth: true; height: 44; radius: 12
            color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
            StyledTextInput {
                id: inputField
                anchors.fill: parent; anchors.margins: 14; verticalAlignment: TextInput.AlignVCenter
                color: Colors.textMain; font.pixelSize: 14; font.family: "Outfit"
                onEditingFinished: parent.parent.editingFinished()
            }
        }
    }

    // ==========================================
    // CONTROLLERS & DATA
    // ==========================================
    Process {
        id: mangoOptionProc
        property var queue: []
        function run(key, value) { queue.push([key, value]); if (!running) next(); }
        function next() { if (queue.length === 0) return; let item = queue.shift(); command = ["mmsg", "dispatch", "setoption," + item[0] + "," + item[1]]; running = true; }
        stdout: StdioCollector { onStreamFinished: mangoOptionProc.next() }
    }

    QtObject {
        id: mangoController
        function setWindowOpacity(val) { var v = Math.max(0.3, Math.min(1.0, val)).toFixed(2); mangoOptionProc.run("focused_opacity", v); mangoOptionProc.run("unfocused_opacity", v); }
        function setBlurSize(val) { mangoOptionProc.run("blur_params_radius", Math.round(Math.max(0, Math.min(20, val)))); }
        function setBlurPasses(val) { mangoOptionProc.run("blur_params_num_passes", Math.round(Math.max(1, Math.min(8, val)))); }
        function applyWidgetBlur(enabled) { sysSettings.widgetBlur = enabled ? 1.0 : 0.0; save(); }
    }

    QtObject {
        id: sysSettings
        property bool useMatugen: true
        property string matugenMode: "dark"
        property string matugenScheme: "vibrant"
        property bool globalBorders: true
        property string wallDir: "/home/stul/Pictures/wallpapers"
        property real topBarOpacity: 0.7
        property int animDuration: 200
        property int topBarHeight: 35
        property int topBarWidth: 0
        property int topBarMarginTop: 10
        property int topBarMarginSide: 20
        property int topBarPosition: 0
        property var topBarOrder: [0, 1, 2]
        property string topBarStyle: "Dynamic"
        property int topBarTraySpacing: 10
        property int cornerMode: 0
        property int cornerRadius: 16
        property int mediaPlayerWidth: 180
        property int mediaPlayerPosition: 0
        
        property real windowOpacity: 1.0
        property int blurSize: 10
        property int blurPasses: 4
        property real widgetOpacity: 0.95
        property real widgetBlur: 0.0
        
        property bool editMode: false
        property bool needsMatugenUpdate: false
        property string fontFamily: "sans-serif"
        property var imageWidgets: [{ x: 40, y: 660, w: 260, h: 360, path: "", radius: 20 }]

        function updateImageWidget(index, obj) { var a = imageWidgets.slice(); a[index] = obj; imageWidgets = a; save(); }
        function removeImageWidget(index) { var a = imageWidgets.slice(); a.splice(index, 1); imageWidgets = a; save(); }
        property bool isLoaded: false
        function save() { if (!isLoaded) return; saveTimer.restart(); }
        function swapOrder(idx1, idx2) { var a = topBarOrder.slice(); var t = a[idx1]; a[idx1] = a[idx2]; a[idx2] = t; topBarOrder = a; save(); }

        onUseMatugenChanged: { needsMatugenUpdate = true; save() }
        onMatugenModeChanged: { needsMatugenUpdate = true; save() }
        onMatugenSchemeChanged: { needsMatugenUpdate = true; save() }
        onGlobalBordersChanged: save()
        onWallDirChanged: save()
        onTopBarOpacityChanged: save()
        onAnimDurationChanged: save()
        onTopBarHeightChanged: save()
        onTopBarWidthChanged: save()
        onTopBarMarginTopChanged: save()
        onTopBarMarginSideChanged: save()
        onTopBarPositionChanged: save()
        onTopBarOrderChanged: save()
        onTopBarStyleChanged: save()
        onTopBarTraySpacingChanged: save()
        onCornerModeChanged: save()
        onCornerRadiusChanged: save()
        onMediaPlayerWidthChanged: save()
        onMediaPlayerPositionChanged: save()
        
        onWindowOpacityChanged: { save(); mangoController.setWindowOpacity(windowOpacity) }
        onBlurSizeChanged: { save(); mangoController.setBlurSize(blurSize) }
        onBlurPassesChanged: { save(); mangoController.setBlurPasses(blurPasses) }
        onWidgetOpacityChanged: { save(); if (shellRoot) shellRoot.qsOpacity = widgetOpacity }
        onWidgetBlurChanged: { save() }
        onFontFamilyChanged: { Theme.fontFamily = fontFamily; save() }
    }

    Binding {
        target: Colors
        property: "activeMode"
        value: sysSettings.matugenMode
    }

    Binding {
        target: Colors
        property: "activeScheme"
        value: sysSettings.matugenScheme
    }

    Timer {
        id: saveTimer
        interval: 300; repeat: false
        onTriggered: {
            var qml = "import QtQuick\n\nQtObject {\n"
                     + "    property bool useMatugen: " + sysSettings.useMatugen + "\n"
                     + "    property string matugenMode: \"" + sysSettings.matugenMode + "\"\n"
                     + "    property string matugenScheme: \"" + sysSettings.matugenScheme + "\"\n"
                     + "    property bool globalBorders: " + sysSettings.globalBorders + "\n"
                     + "    property string wallDir: \"" + sysSettings.wallDir + "\"\n"
                     + "    property real topBarOpacity: " + sysSettings.topBarOpacity + "\n"
                     + "    property int animDuration: " + sysSettings.animDuration + "\n"
                     + "    property int topBarHeight: " + sysSettings.topBarHeight + "\n"
                     + "    property int topBarWidth: " + sysSettings.topBarWidth + "\n"
                     + "    property int topBarMarginTop: " + sysSettings.topBarMarginTop + "\n"
                     + "    property int topBarMarginSide: " + sysSettings.topBarMarginSide + "\n"
                     + "    property int topBarPosition: " + sysSettings.topBarPosition + "\n"
                     + "    property var topBarOrder: " + JSON.stringify(sysSettings.topBarOrder) + "\n"
                     + "    property string topBarStyle: \"" + sysSettings.topBarStyle + "\"\n"
                     + "    property int topBarTraySpacing: " + sysSettings.topBarTraySpacing + "\n"
                     + "    property int cornerMode: " + sysSettings.cornerMode + "\n"
                     + "    property int cornerRadius: " + sysSettings.cornerRadius + "\n"
                     + "    property int mediaPlayerWidth: " + sysSettings.mediaPlayerWidth + "\n"
                     + "    property int mediaPlayerPosition: " + sysSettings.mediaPlayerPosition + "\n"
                     + "    property real windowOpacity: " + sysSettings.windowOpacity + "\n"
                     + "    property int blurSize: " + sysSettings.blurSize + "\n"
                     + "    property int blurPasses: " + sysSettings.blurPasses + "\n"
                     + "    property real widgetOpacity: " + sysSettings.widgetOpacity + "\n"
                     + "    property real widgetBlur: " + sysSettings.widgetBlur + "\n"
                     + "    property string fontFamily: \"" + sysSettings.fontFamily + "\"\n"
                     + "    property var imageWidgets: " + JSON.stringify(sysSettings.imageWidgets, null, 2) + "\n"
                     + "}";
            var cmd = "cat > /home/stul/.config/quickshell/settings.qml << 'EOF'\n" + qml + "\nEOF\n";
            if (sysSettings.needsMatugenUpdate && sysSettings.useMatugen) { sysSettings.needsMatugenUpdate = false; cmd += "nohup /home/stul/.local/bin/swww-matugen.sh >/dev/null 2>&1 &\n"; }
            saveProcess.running = false; saveProcess.command = ["bash", "-c", cmd]; saveProcess.running = true;
        }
    }
    Process { id: saveProcess }

    Process {
        id: themeWriter
        function writeTheme(rBg, bg, card, tM, tS, aB, aP, sABg, sAT, err, sec, out, outV) {
            command = ["bash", "-c", "mkdir -p /home/stul/.cache/noctalia && echo '" + JSON.stringify({
                "surface_dim": rBg, "surface": bg, "surface_variant": card,
                "on_surface": tM, "on_surface_variant": tS,
                "primary": aB, "tertiary": aP,
                "secondary_container": sABg, "on_secondary_container": sAT,
                "error": err, "secondary": sec, "outline": out, "outline_variant": outV
            }) + "' > /home/stul/.cache/noctalia/colors.json"];
            running = true;
        }
    }

    onAnimDurationChanged: updateAnims()
    onGlobalBordersChanged: updateAnims()

    Loader {
        id: settingsLoader
        source: "file:///home/stul/.config/quickshell/settings.qml?t=" + new Date().getTime()
        onLoaded: {
            if (item) {
                if (item.useMatugen !== undefined) sysSettings.useMatugen = item.useMatugen;
                if (item.matugenMode !== undefined) sysSettings.matugenMode = item.matugenMode;
                if (item.matugenScheme !== undefined) sysSettings.matugenScheme = item.matugenScheme;
                if (item.globalBorders !== undefined) sysSettings.globalBorders = item.globalBorders;
                if (item.wallDir !== undefined) sysSettings.wallDir = item.wallDir;
                if (item.topBarOpacity !== undefined) sysSettings.topBarOpacity = item.topBarOpacity;
                if (item.animDuration !== undefined) sysSettings.animDuration = item.animDuration;
                if (item.topBarHeight !== undefined) sysSettings.topBarHeight = item.topBarHeight;
                if (item.topBarWidth !== undefined) sysSettings.topBarWidth = item.topBarWidth;
                if (item.topBarMarginTop !== undefined) sysSettings.topBarMarginTop = item.topBarMarginTop;
                if (item.topBarMarginSide !== undefined) sysSettings.topBarMarginSide = item.topBarMarginSide;
                if (item.topBarPosition !== undefined) sysSettings.topBarPosition = item.topBarPosition;
                if (item.topBarOrder !== undefined) sysSettings.topBarOrder = item.topBarOrder;
                if (item.topBarStyle !== undefined) sysSettings.topBarStyle = item.topBarStyle;
                if (item.topBarTraySpacing !== undefined) sysSettings.topBarTraySpacing = item.topBarTraySpacing;
                if (item.cornerMode !== undefined) sysSettings.cornerMode = item.cornerMode;
                if (item.cornerRadius !== undefined) sysSettings.cornerRadius = item.cornerRadius;
                if (item.mediaPlayerWidth !== undefined) sysSettings.mediaPlayerWidth = item.mediaPlayerWidth;
                if (item.mediaPlayerPosition !== undefined) sysSettings.mediaPlayerPosition = item.mediaPlayerPosition;
                if (item.windowOpacity !== undefined) sysSettings.windowOpacity = item.windowOpacity;
                if (item.blurSize !== undefined) sysSettings.blurSize = item.blurSize;
                if (item.blurPasses !== undefined) sysSettings.blurPasses = item.blurPasses;
                if (item.widgetOpacity !== undefined) sysSettings.widgetOpacity = item.widgetOpacity;
                if (item.widgetBlur !== undefined) sysSettings.widgetBlur = item.widgetBlur;
                if (item.fontFamily !== undefined) { sysSettings.fontFamily = item.fontFamily; Theme.fontFamily = item.fontFamily; }
                if (item.imageWidgets !== undefined) sysSettings.imageWidgets = item.imageWidgets;
            }
            sysSettings.isLoaded = true; updateAnims();
            Qt.callLater(function() {
                if (shellRoot) { shellRoot.qsOpacity = sysSettings.widgetOpacity; }
                mangoController.setWindowOpacity(sysSettings.windowOpacity);
                mangoController.setBlurSize(sysSettings.blurSize);
                mangoController.setBlurPasses(sysSettings.blurPasses);
            });
        }
        onStatusChanged: { if (status === Loader.Error) { sysSettings.isLoaded = true; updateAnims(); } }
    }
    
    function updateAnims() {
        Anim.durationFast = animDuration; Anim.durationElastic = animDuration + 50;
        Theme.borderWidth = sysSettings.globalBorders ? 1 : 0;
    }

    // ==========================================
    // UI LAYOUT (WHISKER STYLE)
    // ==========================================
    Rectangle {
        id: rootBg
        anchors.fill: parent
        radius: 20
        color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, shellRoot ? shellRoot.qsOpacity : 0.95)
        
        // Header Text
        StyledText {
            anchors.top: parent.top; anchors.topMargin: 16
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Settings · " + ["Design", "Animations", "Desktop"][activeTab]
            font.pixelSize: 16; font.family: "Outfit Medium"; color: Colors.textMain
        }
        
        // Close Button
        Rectangle {
            width: 32; height: 32; radius: 16
            anchors.top: parent.top; anchors.topMargin: 12
            anchors.right: parent.right; anchors.rightMargin: 16
            color: closeMouse.containsMouse ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2) : "transparent"
            StyledText { anchors.centerIn: parent; text: "✕"; font.pixelSize: 14; color: Colors.textMain }
            MouseArea { id: closeMouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: settingsWindow.visible = false }
        }

        // Left Sidebar (Icons only)
        ColumnLayout {
            anchors.left: parent.left; anchors.leftMargin: 12
            anchors.top: parent.top; anchors.topMargin: 64
            spacing: 12
            
            Repeater {
                model: [
                    { icon: "󰏘", tooltip: "Design" },
                    { icon: "󰢹", tooltip: "Animations" },
                    { icon: "󰕮", tooltip: "Desktop" }
                ]
                Rectangle {
                    width: 48; height: 48; radius: 24
                    color: settingsWindow.activeTab === index ? Colors.accentPurple : (tabMouse.containsMouse ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1) : "transparent")
                    Behavior on color { ColorAnimation { duration: 150 } }
                    
                    StyledText {
                        anchors.centerIn: parent
                        text: modelData.icon
                        color: settingsWindow.activeTab === index ? Colors.bg : Colors.textMain
                        font.pixelSize: 22
                    }
                    MouseArea {
                        id: tabMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: settingsWindow.activeTab = index
                    }
                }
            }
        }

        // Main Content Area
        Rectangle {
            anchors.left: parent.left; anchors.leftMargin: 72
            anchors.right: parent.right; anchors.rightMargin: 12
            anchors.top: parent.top; anchors.topMargin: 52
            anchors.bottom: parent.bottom; anchors.bottomMargin: 12
            radius: 16
            color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.5)
            
            Flickable {
                anchors.fill: parent
                contentHeight: rightContent.implicitHeight + 60
                clip: true; boundsBehavior: Flickable.StopAtBounds
                
                ColumnLayout {
                    id: rightContent
                    anchors.left: parent.left; anchors.right: parent.right; anchors.top: parent.top
                    anchors.margins: 32
                    spacing: 32
                    
                    // =====================================
                    // ТАБ 0: ДИЗАЙН И ТЕМЫ
                    // =====================================
                    ColumnLayout {
                        Layout.fillWidth: true; visible: settingsWindow.activeTab === 0; spacing: 24
                        
                        SectionHeader { iconText: "󰏘"; titleText: "Colors & Theming" }
                        
                        RowLayout {
                            Layout.fillWidth: true; spacing: 16
                            WhiskerToggle {
                                iconText: "󰸉"
                                titleText: "Use Matugen"
                                subtitleText: "Generate scheme from wallpaper"
                                checked: sysSettings.useMatugen
                                onToggled: sysSettings.useMatugen = !sysSettings.useMatugen
                            }
                            WhiskerToggle {
                                iconText: "󰆧"
                                titleText: "Global Borders"
                                subtitleText: "Outlines on windows & widgets"
                                checked: sysSettings.globalBorders
                                onToggled: sysSettings.globalBorders = !sysSettings.globalBorders
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 12
                            visible: sysSettings.useMatugen; opacity: sysSettings.useMatugen ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            
                            StyledText { text: "Matugen Mode"; color: Colors.textSub; font.pixelSize: 14; font.family: "Outfit Medium" }
                            WhiskerSegmented {
                                Layout.fillWidth: true
                                options: [{label: "Dark", value: "dark", icon: "󰖨"}, {label: "Light", value: "light", icon: "󰖨"}]
                                currentValue: sysSettings.matugenMode
                                onSelected: (val) => sysSettings.matugenMode = val
                            }
                            
                            StyledText { text: "Matugen Palette"; color: Colors.textSub; font.pixelSize: 14; font.family: "Outfit Medium"; Layout.topMargin: 8 }
                            WhiskerSegmented {
                                Layout.fillWidth: true
                                options: [{label: "Pastel", value: "pastel"}, {label: "Vibrant", value: "vibrant"}, {label: "Intensified", value: "intensified"}]
                                currentValue: sysSettings.matugenScheme
                                onSelected: (val) => sysSettings.matugenScheme = val
                            }
                        }
                        
                        SectionHeader { iconText: "󰏫"; titleText: "Appearance" }
                        
                        RowLayout {
                            Layout.fillWidth: true; spacing: 16
                            WhiskerInput {
                                Layout.fillWidth: true
                                titleText: "Wallpaper Folder"
                                text: sysSettings.wallDir
                                onEditingFinished: sysSettings.wallDir = text
                            }
                            WhiskerInput {
                                Layout.fillWidth: true
                                titleText: "Widget Font Family"
                                text: sysSettings.fontFamily
                                onEditingFinished: sysSettings.fontFamily = text
                            }
                        }
                        
                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 12
                            visible: !sysSettings.useMatugen; opacity: !sysSettings.useMatugen ? 1.0 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                            StyledText { text: "Built-in Themes"; color: Colors.textSub; font.pixelSize: 14; font.family: "Outfit Medium" }
                            Flow {
                                Layout.fillWidth: true; spacing: 12
                                Repeater {
                                    model: [
                                        { name: "Catppuccin", colors: ["#11111b","#181825","#1e1e2e","#cdd6f4","#a6adc8","#89b4fa","#cba6f7","#313244","#f5c2e7","#f38ba8","#89b4fa","#6c7086","#313244"] },
                                        { name: "Dracula", colors: ["#282a36","#44475a","#6272a4","#f8f8f2","#bfbfbf","#8be9fd","#bd93f9","#ff79c6","#f8f8f2","#ff5555","#8be9fd","#6272a4","#44475a"] },
                                        { name: "Tokyo Night", colors: ["#1a1b26","#1f2335","#24283b","#c0caf5","#a9b1d6","#7aa2f7","#bb9af7","#292e42","#9ece6a","#f7768e","#7aa2f7","#565f89","#292e42"] }
                                    ]
                                    Rectangle {
                                        width: 140; height: 50; radius: 12; color: modelData.colors[1]
                                        border.width: 1; border.color: modelData.colors[2]
                                        StyledText { anchors.centerIn: parent; text: modelData.name; color: modelData.colors[3]; font.pixelSize: 14; font.family: "Outfit Medium" }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                themeWriter.writeTheme(modelData.colors[0], modelData.colors[1], modelData.colors[2], modelData.colors[3], modelData.colors[4], modelData.colors[5], modelData.colors[6], modelData.colors[7], modelData.colors[8], modelData.colors[9], modelData.colors[10], modelData.colors[11], modelData.colors[12])
                                                Colors.applyFixedPalette(modelData.colors[0], modelData.colors[1], modelData.colors[2], modelData.colors[3], modelData.colors[4], modelData.colors[5], modelData.colors[6], modelData.colors[7], modelData.colors[8], modelData.colors[9], modelData.colors[10], modelData.colors[11], modelData.colors[12])
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    // =====================================
                    // ТАБ 1: АНИМАЦИИ
                    // =====================================
                    ColumnLayout {
                        Layout.fillWidth: true; visible: settingsWindow.activeTab === 1; spacing: 24
                        
                        SectionHeader { iconText: "󰢹"; titleText: "Animation Engine" }
                        
                        WhiskerSlider {
                            iconText: "󰥔"
                            titleText: "UI Animation Speed"
                            from: 50; to: 800; isInt: true; suffix: " ms"
                            value: sysSettings.animDuration
                            onValueModified: (val) => sysSettings.animDuration = val
                        }
                        
                        SectionHeader { iconText: "󰖨"; titleText: "Window Effects (MangoWM)" }
                        
                        WhiskerSlider {
                            iconText: "󰂵"
                            titleText: "Window Opacity"
                            from: 0.3; to: 1.0; isInt: false; suffix: ""
                            value: sysSettings.windowOpacity
                            onValueModified: (val) => sysSettings.windowOpacity = val
                        }
                        WhiskerSlider {
                            iconText: "󰆨"
                            titleText: "Blur Radius"
                            from: 0; to: 20; isInt: true; suffix: " px"
                            value: sysSettings.blurSize
                            onValueModified: (val) => sysSettings.blurSize = val
                        }
                        WhiskerSlider {
                            iconText: "󰆨"
                            titleText: "Blur Passes"
                            from: 1; to: 8; isInt: true; suffix: ""
                            value: sysSettings.blurPasses
                            onValueModified: (val) => sysSettings.blurPasses = val
                        }
                    }
                    
                    // =====================================
                    // ТАБ 2: ДЕСКТОП И ПАНЕЛИ
                    // =====================================
                    ColumnLayout {
                        Layout.fillWidth: true; visible: settingsWindow.activeTab === 2; spacing: 24
                        
                        SectionHeader { iconText: "󰕮"; titleText: "Desktop Widgets" }
                        
                        RowLayout {
                            Layout.fillWidth: true; spacing: 16
                            WhiskerToggle {
                                iconText: "󰏫"
                                titleText: "Edit Mode"
                                subtitleText: "Move and resize desktop widgets"
                                checked: sysSettings.editMode
                                onToggled: sysSettings.editMode = !sysSettings.editMode
                            }
                            Rectangle {
                                Layout.fillWidth: true; height: 100; radius: 16
                                color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
                                visible: sysSettings.editMode
                                ColumnLayout {
                                    anchors.centerIn: parent; spacing: 4
                                    StyledText { text: "󰏔"; font.pixelSize: 22; color: Colors.textMain; Layout.alignment: Qt.AlignHCenter }
                                    StyledText { text: "Add Image Widget"; font.pixelSize: 15; font.family: "Outfit Medium"; color: Colors.textMain }
                                }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { var a = settingsWindow.imageWidgets.slice(); a.push({x: 500, y: 300, w: 260, h: 360, path: "", radius: 20}); settingsWindow.imageWidgets = a; sysSettings.save() } }
                            }
                        }
                        
                        SectionHeader { iconText: "󰍹"; titleText: "Screen Corners" }
                        
                        StyledText { text: "Rounding Mode"; color: Colors.textSub; font.pixelSize: 14; font.family: "Outfit Medium" }
                        WhiskerSegmented {
                            Layout.fillWidth: true
                            options: [{label: "Disabled", value: 0}, {label: "TopBar Only", value: 1}, {label: "All 4 Corners", value: 2}]
                            currentValue: sysSettings.cornerMode
                            onSelected: (val) => sysSettings.cornerMode = val
                        }
                        WhiskerSlider {
                            visible: sysSettings.cornerMode > 0
                            iconText: "󰆦"
                            titleText: "Corner Radius"
                            from: 4; to: 40; isInt: true; suffix: " px"
                            value: sysSettings.cornerRadius
                            onValueModified: (val) => sysSettings.cornerRadius = val
                        }
                        
                        SectionHeader { iconText: "󰘦"; titleText: "TopBar Configuration" }
                        
                        StyledText { text: "TopBar Style"; color: Colors.textSub; font.pixelSize: 14; font.family: "Outfit Medium" }
                        WhiskerSegmented {
                            Layout.fillWidth: true
                            options: [{label: "Default", value: "Default"}, {label: "Alternative", value: "Alternative"}, {label: "Dynamic", value: "Dynamic"}]
                            currentValue: sysSettings.topBarStyle
                            onSelected: (val) => sysSettings.topBarStyle = val
                        }
                        
                        WhiskerSlider {
                            iconText: "󰂵"
                            titleText: "Opacity"
                            from: 0.0; to: 1.0; isInt: false; suffix: ""
                            value: sysSettings.topBarOpacity
                            onValueModified: (val) => sysSettings.topBarOpacity = val
                        }
                        WhiskerSlider {
                            iconText: "󰖟"
                            titleText: "Height"
                            from: 20; to: 80; isInt: true; suffix: " px"
                            value: sysSettings.topBarHeight
                            onValueModified: (val) => sysSettings.topBarHeight = val
                        }
                        WhiskerSlider {
                            iconText: "󰖟"
                            titleText: "Margin Top"
                            from: 0; to: 50; isInt: true; suffix: " px"
                            value: sysSettings.topBarMarginTop
                            onValueModified: (val) => sysSettings.topBarMarginTop = val
                        }
                        WhiskerSlider {
                            iconText: "󰖟"
                            titleText: "Side Margins"
                            from: 0; to: 500; isInt: true; suffix: " px"
                            value: sysSettings.topBarWidth
                            onValueModified: (val) => sysSettings.topBarWidth = val
                        }
                        
                        SectionHeader { iconText: "󰯓"; titleText: "TopBar Layout" }
                        
                        RowLayout {
                            Layout.fillWidth: true; spacing: 12
                            Repeater {
                                model: [0, 1, 2]
                                Rectangle {
                                    Layout.fillWidth: true; height: 120; radius: 12
                                    color: Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1)
                                    readonly property int slotIndex: modelData
                                    readonly property int widgetId: sysSettings.topBarOrder[slotIndex]
                                    
                                    ColumnLayout {
                                        anchors.centerIn: parent; spacing: 8
                                        StyledText { text: slotIndex === 0 ? "Left Slot" : (slotIndex === 1 ? "Center Slot" : "Right Slot"); color: Colors.textSub; font.pixelSize: 12; Layout.alignment: Qt.AlignHCenter }
                                        StyledText {
                                            text: widgetId === 0 ? "󰨇 Workspaces" : (widgetId === 1 ? "󰥔 Clock & Media" : "󰘦 Tray & Menu")
                                            color: Colors.textMain; font.pixelSize: 14; font.family: "Outfit Medium"; Layout.alignment: Qt.AlignHCenter
                                        }
                                        RowLayout {
                                            Layout.alignment: Qt.AlignHCenter; spacing: 14
                                            Rectangle {
                                                width: 32; height: 32; radius: 16; opacity: slotIndex > 0 ? 1 : 0.2
                                                color: lMa.pressed ? Colors.accentPurple : (lMa.containsMouse ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2) : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1))
                                                StyledText { anchors.centerIn: parent; text: "←"; font.pixelSize: 16; color: lMa.pressed ? Colors.bg : Colors.textMain }
                                                MouseArea { id: lMa; anchors.fill: parent; enabled: slotIndex > 0; cursorShape: Qt.PointingHandCursor; onClicked: sysSettings.swapOrder(slotIndex, slotIndex-1) }
                                            }
                                            Rectangle {
                                                width: 32; height: 32; radius: 16; opacity: slotIndex < 2 ? 1 : 0.2
                                                color: rMa.pressed ? Colors.accentPurple : (rMa.containsMouse ? Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.2) : Qt.rgba(Colors.outline.r, Colors.outline.g, Colors.outline.b, 0.1))
                                                StyledText { anchors.centerIn: parent; text: "→"; font.pixelSize: 16; color: rMa.pressed ? Colors.bg : Colors.textMain }
                                                MouseArea { id: rMa; anchors.fill: parent; enabled: slotIndex < 2; cursorShape: Qt.PointingHandCursor; onClicked: sysSettings.swapOrder(slotIndex, slotIndex+1) }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
