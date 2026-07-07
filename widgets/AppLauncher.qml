import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

import "../core"
import "../components"

PanelWindow {
    id: launcherWindow

    WlrLayershell.namespace: "qs-launcher"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.exclusiveZone: -1

    implicitWidth: 560
    implicitHeight: 520
    color: "transparent"
    visible: false

    // Master Animation State
    property bool isOpen: false

    // Configuration & Persistence
    property string animeImagePath: ""
    property var usageCounts: ({})
    property string configFile: "/home/stul/.config/quickshell/applauncher_config.json"

    // Search & Navigation state
    property string searchQuery: ""
    property int selectedIndex: 0
    property string currentCategory: "all" // "all", "frequent", "dev", "media", "system", "office"

    // App Data Model
    property var filteredApps: []

    Component.onCompleted: {
        loadConfig()
        updateFilteredApps()
    }

    // Window Visibility & Animation Controls
    function toggle() {
        if (visible && isOpen) {
            close()
        } else {
            open()
        }
    }

    function open() {
        closeTimer.stop()
        isOpen = false
        searchQuery = ""
        searchInput.text = ""
        currentCategory = "all"
        selectedIndex = 0
        updateFilteredApps()

        visible = true
        openAnimationTimer.restart()
        focusTimer.restart()
    }

    function close() {
        if (!isOpen && !visible) return
        isOpen = false
        closeTimer.restart()
    }

    onVisibleChanged: {
        if (visible && !isOpen) {
            open()
        } else if (!visible && isOpen) {
            isOpen = false
        }
    }

    Timer {
        id: openAnimationTimer
        interval: 20
        repeat: false
        onTriggered: launcherWindow.isOpen = true
    }

    Timer {
        id: focusTimer
        interval: 50
        repeat: false
        onTriggered: searchInput.forceActiveFocus()
    }

    Timer {
        id: closeTimer
        interval: 250
        repeat: false
        onTriggered: {
            launcherWindow.visible = false
            launcherWindow.isOpen = false
        }
    }

    // Functions
    function updateFilteredApps() {
        let apps = DesktopEntries.applications.values || []
        let q = searchQuery.toLowerCase().trim()
        let cat = currentCategory

        let list = []
        for (let i = 0; i < apps.length; i++) {
            let app = apps[i]
            if (!app || app.noDisplay || !app.name) continue

            // Category filter
            if (cat === "frequent") {
                if ((usageCounts[app.name] || 0) <= 0) continue
            } else if (cat !== "all") {
                let appCats = (app.categories || []).join(" ").toLowerCase()
                let match = false
                if (cat === "dev" && (appCats.includes("development") || appCats.includes("ide") || appCats.includes("texteditor"))) match = true
                else if (cat === "media" && (appCats.includes("audiovideo") || appCats.includes("audio") || appCats.includes("video") || appCats.includes("player") || appCats.includes("music"))) match = true
                else if (cat === "office" && (appCats.includes("office") || appCats.includes("document") || appCats.includes("pdf"))) match = true
                else if (cat === "system" && (appCats.includes("system") || appCats.includes("settings") || appCats.includes("terminal") || appCats.includes("core"))) match = true

                if (!match) continue
            }

            // Search query filter & scoring
            if (q === "") {
                list.push({ app: app, score: usageCounts[app.name] || 0 })
            } else {
                let name = app.name.toLowerCase()
                let genName = app.genericName ? app.genericName.toLowerCase() : ""
                let comment = app.comment ? app.comment.toLowerCase() : ""

                let score = 0
                if (name === q) score += 1000
                else if (name.startsWith(q)) score += 500
                else if (name.includes(q)) score += 200
                else if (genName.startsWith(q)) score += 150
                else if (genName.includes(q)) score += 100
                else if (comment.includes(q)) score += 50

                if (score > 0) {
                    let usage = usageCounts[app.name] || 0
                    score += Math.min(usage * 5, 50)
                    list.push({ app: app, score: score })
                }
            }
        }

        // Sort
        if (q === "") {
            list.sort(function(a, b) {
                if (a.score !== b.score) return b.score - a.score
                return a.app.name.localeCompare(b.app.name)
            })
        } else {
            list.sort(function(a, b) {
                return b.score - a.score
            })
        }

        let res = []
        for (let j = 0; j < list.length; j++) {
            res.push(list[j].app)
        }

        filteredApps = res
        if (selectedIndex >= filteredApps.length) {
            selectedIndex = Math.max(0, filteredApps.length - 1)
        }
    }

    function launchApp(app) {
        if (!app) return
        let counts = usageCounts
        counts[app.name] = (counts[app.name] || 0) + 1
        usageCounts = counts
        saveConfig()

        app.execute()
        close()
    }

    function launchSelected() {
        if (filteredApps.length > 0 && selectedIndex >= 0 && selectedIndex < filteredApps.length) {
            launchApp(filteredApps[selectedIndex])
        }
    }

    // Config persistence processes
    function loadConfig() {
        configLoadProcess.running = false
        configLoadProcess.running = true
    }

    function saveConfig() {
        configSaveProcess.running = false
        configSaveProcess.running = true
    }

    Process {
        id: configLoadProcess
        command: ["bash", "-c", "cat " + launcherWindow.configFile + " 2>/dev/null || echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    let data = JSON.parse(this.text || "{}")
                    if (data.animeImagePath !== undefined) {
                        launcherWindow.animeImagePath = data.animeImagePath
                    }
                    if (data.usageCounts) {
                        launcherWindow.usageCounts = data.usageCounts
                    }
                } catch(e) {
                    console.log("Failed to load applauncher config:", e)
                }
                launcherWindow.updateFilteredApps()
            }
        }
    }

    Process {
        id: configSaveProcess
        command: [
            "bash", "-c",
            "cat << 'EOF' > " + launcherWindow.configFile + "\n" +
            JSON.stringify({
                animeImagePath: launcherWindow.animeImagePath,
                usageCounts: launcherWindow.usageCounts
            }, null, 2) + "\nEOF"
        ]
    }

    Process {
        id: pickImageProcess
        command: [
            "bash", "-c",
            "FILE=$(zenity --file-selection --title='Выберите баннер' --file-filter='Images | *.png *.jpg *.jpeg *.gif *.webp'); if [ -n \"$FILE\" ]; then echo \"$FILE\"; fi"
        ]
        stdout: StdioCollector {
            onStreamFinished: {
                if (this.text && this.text.trim().length > 0) {
                    launcherWindow.animeImagePath = this.text.trim()
                    launcherWindow.saveConfig()
                }
            }
        }
    }

    // ══════════════════════════════════════════════════
    // INTERFACE / LAYOUT & MASKING
    // ══════════════════════════════════════════════════

    // 1. Stencil mask for rounded corners
    Rectangle {
        id: cardMask
        width: 560
        height: 520
        radius: 20
        visible: false
        layer.enabled: true
    }

    // 2. Main visible card container
    Rectangle {
        id: mainCard
        anchors.fill: parent
        radius: 20
        color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, shellRoot ? shellRoot.qsOpacity : 0.88)
        border.color: Colors.outlineVariant
        border.width: 1
        visible: true
        clip: true

        scale: launcherWindow.isOpen ? 1.0 : 0.90
        opacity: launcherWindow.isOpen ? 1.0 : 0.0

        Behavior on scale {
            NumberAnimation {
                duration: launcherWindow.isOpen ? 750 : 280
                easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: launcherWindow.isOpen ? 600 : 250
                easing.type: launcherWindow.isOpen ? Easing.OutCubic : Easing.InCubic
            }
        }

        layer.enabled: true
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: cardMask
        }

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            // ── 1. BANNER HEADER CONTAINER (Unfolding Section 1 - Delay 0ms) ──
            Item {
                id: bannerContainer
                Layout.fillWidth: true
                Layout.preferredHeight: launcherWindow.animeImagePath ? 90 : 0
                visible: launcherWindow.animeImagePath !== ""
                clip: true // 🌟 Clipping boundary for zero deformation reveal

                Behavior on Layout.preferredHeight {
                    NumberAnimation { duration: 350; easing.type: Easing.OutQuint }
                }

                // Inner content with rigid dimensions
                Item {
                    id: bannerContent
                    width: parent.width
                    height: parent.height

                    x: launcherWindow.isOpen ? 0 : -28
                    y: launcherWindow.isOpen ? 0 : -90
                    opacity: launcherWindow.isOpen ? 1.0 : 0.0

                    Behavior on x {
                        NumberAnimation {
                            duration: launcherWindow.isOpen ? 750 : 220
                            easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                        }
                    }
                    Behavior on y {
                        NumberAnimation {
                            duration: launcherWindow.isOpen ? 750 : 220
                            easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                        }
                    }
                    Behavior on opacity {
                        NumberAnimation {
                            duration: launcherWindow.isOpen ? 600 : 180
                            easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                        }
                    }

                    Image {
                        id: bannerImg
                        anchors.fill: parent
                        source: launcherWindow.animeImagePath ? "file://" + launcherWindow.animeImagePath : ""
                        fillMode: Image.PreserveAspectCrop
                        smooth: true
                        antialiasing: true
                    }

                    Rectangle {
                        anchors.fill: parent
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.7; color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, 0.4) }
                            GradientStop { position: 1.0; color: Colors.rootBg }
                        }
                    }

                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 26
                        height: 26
                        radius: 13
                        z: 2
                        color: removeBannerBtn.containsMouse ? Colors.error : Qt.rgba(0, 0, 0, 0.5)

                        StyledText {
                            anchors.centerIn: parent
                            text: "󰅖"
                            color: Colors.textMain
                            font.pixelSize: 12
                        }

                        MouseArea {
                            id: removeBannerBtn
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                launcherWindow.animeImagePath = ""
                                launcherWindow.saveConfig()
                            }
                        }
                    }
                }
            }

            // ── 2. SEARCH BAR CONTAINER (Unfolding Section 2 - Delay 70ms) ──
            Item {
                id: searchContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 64
                clip: true // 🌟 Clipping boundary for zero deformation reveal

                Item {
                    id: searchContent
                    width: parent.width
                    height: parent.height

                    x: launcherWindow.isOpen ? 0 : 28
                    y: launcherWindow.isOpen ? 0 : 45
                    opacity: launcherWindow.isOpen ? 1.0 : 0.0

                    Behavior on x {
                        SequentialAnimation {
                            PauseAnimation { duration: launcherWindow.isOpen ? 80 : 0 }
                            NumberAnimation {
                                duration: launcherWindow.isOpen ? 750 : 220
                                easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                            }
                        }
                    }
                    Behavior on y {
                        SequentialAnimation {
                            PauseAnimation { duration: launcherWindow.isOpen ? 80 : 0 }
                            NumberAnimation {
                                duration: launcherWindow.isOpen ? 750 : 220
                                easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                            }
                        }
                    }
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: launcherWindow.isOpen ? 80 : 0 }
                            NumberAnimation {
                                duration: launcherWindow.isOpen ? 600 : 180
                                easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 20
                        anchors.rightMargin: 20
                        spacing: 12

                        StyledText {
                            text: "󰍉"
                            color: searchInput.activeFocus ? Colors.accentBlue : Colors.textSub
                            font.pixelSize: 20

                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: searchInput.text === "" ? "Поиск приложений..." : ""
                                color: Colors.textSub
                                font.pixelSize: 16
                                opacity: 0.6
                            }

                            StyledTextInput {
                                id: searchInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.textMain
                                font.pixelSize: 16
                                font.weight: Font.Medium
                                clip: true
                                selectionColor: Colors.accentBlue
                                selectedTextColor: Colors.rootBg

                                onTextChanged: {
                                    launcherWindow.searchQuery = text
                                    launcherWindow.selectedIndex = 0
                                    launcherWindow.updateFilteredApps()
                                    appList.positionViewAtBeginning()
                                }

                                Keys.onDownPressed: {
                                    if (launcherWindow.filteredApps.length > 0) {
                                        launcherWindow.selectedIndex = Math.min(
                                            launcherWindow.selectedIndex + 1,
                                            launcherWindow.filteredApps.length - 1
                                        )
                                        appList.positionViewAtIndex(launcherWindow.selectedIndex, ListView.Contain)
                                    }
                                }
                                Keys.onUpPressed: {
                                    if (launcherWindow.filteredApps.length > 0) {
                                        launcherWindow.selectedIndex = Math.max(
                                            launcherWindow.selectedIndex - 1,
                                            0
                                        )
                                        appList.positionViewAtIndex(launcherWindow.selectedIndex, ListView.Contain)
                                    }
                                }
                                Keys.onReturnPressed: launcherWindow.launchSelected()
                                Keys.onEscapePressed: launcherWindow.close()
                            }
                        }

                        RowLayout {
                            spacing: 8

                            Rectangle {
                                visible: searchInput.text !== ""
                                width: 24
                                height: 24
                                radius: 12
                                color: clearBtnArea.containsMouse ? Colors.card : "transparent"

                                StyledText {
                                    anchors.centerIn: parent
                                    text: "󰅖"
                                    color: Colors.textSub
                                    font.pixelSize: 13
                                }

                                MouseArea {
                                    id: clearBtnArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        searchInput.text = ""
                                        searchInput.forceActiveFocus()
                                    }
                                }
                            }

                            Rectangle {
                                height: 22
                                width: countText.implicitWidth + 14
                                radius: 11
                                color: Colors.card

                                StyledText {
                                    id: countText
                                    anchors.centerIn: parent
                                    text: launcherWindow.filteredApps.length.toString()
                                    color: Colors.textSub
                                    font.pixelSize: 11
                                }
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.outlineVariant
                opacity: 0.5
            }

            // ── 3. CATEGORY FILTER TABS CONTAINER (Unfolding Section 3 - Delay 140ms+) ────
            Item {
                id: catContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 40
                clip: true // 🌟 Clipping boundary for zero deformation reveal

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 16
                    anchors.rightMargin: 16
                    spacing: 6

                    Repeater {
                        model: [
                            { id: "all", label: "Все", icon: "󰕰" },
                            { id: "frequent", label: "Частые", icon: "󰋚" },
                            { id: "dev", label: "Кодинг", icon: "󰅩" },
                            { id: "media", label: "Медиа", icon: "󰎈" },
                            { id: "system", label: "Система", icon: "󰒓" },
                            { id: "office", label: "Офис", icon: "󰈙" }
                        ]

                        delegate: Item {
                            Layout.fillHeight: true
                            Layout.preferredWidth: tabRow.implicitWidth + 20
                            clip: true // 🌟 Individual tab clipping slot

                            Rectangle {
                                id: catTab
                                width: parent.width
                                height: parent.height
                                radius: 10
                                color: launcherWindow.currentCategory === modelData.id
                                    ? Colors.card
                                    : (catMouse.containsMouse ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.4) : "transparent")

                                border.color: launcherWindow.currentCategory === modelData.id
                                    ? Colors.accentBlue
                                    : "transparent"
                                border.width: 1

                                // Staggered & Unique movement per tab item
                                x: launcherWindow.isOpen ? 0 : (index % 2 === 0 ? -20 : 20)
                                y: launcherWindow.isOpen ? 0 : 35
                                opacity: launcherWindow.isOpen ? 1.0 : 0.0

                                Behavior on x {
                                    SequentialAnimation {
                                        PauseAnimation { duration: launcherWindow.isOpen ? (150 + index * 45) : 0 }
                                        NumberAnimation {
                                            duration: launcherWindow.isOpen ? 700 : 200
                                            easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                                        }
                                    }
                                }
                                Behavior on y {
                                    SequentialAnimation {
                                        PauseAnimation { duration: launcherWindow.isOpen ? (150 + index * 45) : 0 }
                                        NumberAnimation {
                                            duration: launcherWindow.isOpen ? 700 : 200
                                            easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                                        }
                                    }
                                }
                                Behavior on opacity {
                                    SequentialAnimation {
                                        PauseAnimation { duration: launcherWindow.isOpen ? (150 + index * 45) : 0 }
                                        NumberAnimation {
                                            duration: launcherWindow.isOpen ? 550 : 150
                                            easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                                        }
                                    }
                                }

                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on border.color { ColorAnimation { duration: 150 } }

                                RowLayout {
                                    id: tabRow
                                    anchors.centerIn: parent
                                    spacing: 6

                                    StyledText {
                                        text: modelData.icon
                                        font.pixelSize: 13
                                        color: launcherWindow.currentCategory === modelData.id
                                            ? Colors.accentBlue
                                            : Colors.textSub
                                    }

                                    StyledText {
                                        text: modelData.label
                                        font.pixelSize: 12
                                        font.bold: launcherWindow.currentCategory === modelData.id
                                        color: launcherWindow.currentCategory === modelData.id
                                            ? Colors.textMain
                                            : Colors.textSub
                                    }
                                }

                                MouseArea {
                                    id: catMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        launcherWindow.currentCategory = modelData.id
                                        launcherWindow.selectedIndex = 0
                                        launcherWindow.updateFilteredApps()
                                        searchInput.forceActiveFocus()
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.outlineVariant
                opacity: 0.3
            }

            // ── 4. APP LIST VIEW CONTAINER (Unfolding Section 4 - Delay 220ms+) ──────────
            Item {
                id: appListContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty state
                Item {
                    anchors.centerIn: parent
                    visible: launcherWindow.filteredApps.length === 0
                    width: parent.width
                    height: 140

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        StyledText {
                            text: "󰍉"
                            color: Colors.textSub
                            font.pixelSize: 36
                            opacity: 0.5
                            Layout.alignment: Qt.AlignHCenter
                        }

                        StyledText {
                            text: "Приложения не найдены"
                            color: Colors.textSub
                            font.pixelSize: 14
                            font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }

                        StyledText {
                            text: "Попробуйте изменить категорию или поисковый запрос"
                            color: Colors.textSub
                            font.pixelSize: 12
                            opacity: 0.7
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                ListView {
                    id: appList
                    anchors.fill: parent
                    anchors.margins: 8
                    model: launcherWindow.filteredApps
                    currentIndex: launcherWindow.selectedIndex
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    spacing: 4

                    highlightFollowsCurrentItem: true
                    highlightMoveDuration: 100

                    highlight: Rectangle {
                        radius: 12
                        color: Colors.card
                        border.color: Colors.accentBlue
                        border.width: 1
                        z: 0
                    }

                    delegate: Item {
                        id: delegateRoot
                        width: appList.width
                        height: 52
                        clip: true // 🌟 Technical Requirement 1: Clipping slot eliminates any content deformation!

                        property bool isSelected: index === launcherWindow.selectedIndex

                        // Rigid Content Box (No width/height/scale deformation!)
                        Item {
                            id: delegateContent
                            width: parent.width
                            height: parent.height

                            // 🌟 Technical Requirement 2: Staggered Delay + Alternating X Shift + Unfolding Y Shift
                            // Even indices: X moves from -32px to 0. Odd indices: X moves from +32px to 0.
                            x: launcherWindow.isOpen ? 0 : (index % 2 === 0 ? -32 : 32)
                            y: launcherWindow.isOpen ? 0 : 42
                            opacity: launcherWindow.isOpen ? 1.0 : 0.0

                            Behavior on x {
                                SequentialAnimation {
                                    PauseAnimation { duration: launcherWindow.isOpen ? (220 + Math.min(index, 8) * 45) : 0 }
                                    NumberAnimation {
                                        duration: launcherWindow.isOpen ? 700 : 200
                                        easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                                    }
                                }
                            }

                            Behavior on y {
                                SequentialAnimation {
                                    PauseAnimation { duration: launcherWindow.isOpen ? (220 + Math.min(index, 8) * 45) : 0 }
                                    NumberAnimation {
                                        duration: launcherWindow.isOpen ? 700 : 200
                                        easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                                    }
                                }
                            }

                            Behavior on opacity {
                                SequentialAnimation {
                                    PauseAnimation { duration: launcherWindow.isOpen ? (220 + Math.min(index, 8) * 45) : 0 }
                                    NumberAnimation {
                                        duration: launcherWindow.isOpen ? 550 : 150
                                        easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                                    }
                                }
                            }

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                anchors.rightMargin: 14
                                spacing: 14
                                z: 1

                                // App Icon Box
                                Rectangle {
                                    width: 38
                                    height: 38
                                    radius: 10
                                    color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.6)
                                    border.color: Colors.outlineVariant
                                    border.width: 0.5

                                    Image {
                                        id: iconImg
                                        anchors.centerIn: parent
                                        width: 28
                                        height: 28
                                        source: modelData.icon ? "image://icon/" + modelData.icon : ""
                                        sourceSize: Qt.size(28, 28)
                                        visible: status === Image.Ready
                                        smooth: true
                                        antialiasing: true
                                    }

                                    // Fallback icon
                                    StyledText {
                                        anchors.centerIn: parent
                                        text: "󰀲"
                                        color: isSelected ? Colors.accentBlue : Colors.textSub
                                        font.pixelSize: 20
                                        visible: iconImg.status !== Image.Ready
                                    }
                                }

                                // App Info Text
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 2

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.name || "Unknown App"
                                        color: Colors.textMain
                                        font.pixelSize: 14
                                        font.bold: isSelected
                                        elide: Text.ElideRight
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: modelData.genericName
                                            ? modelData.genericName
                                            : (modelData.comment ? modelData.comment : "Приложение")
                                        color: Colors.textSub
                                        font.pixelSize: 11
                                        opacity: isSelected ? 0.9 : 0.6
                                        elide: Text.ElideRight
                                    }
                                }

                                // Action badge when selected
                                Rectangle {
                                    visible: isSelected
                                    height: 24
                                    width: actionRow.implicitWidth + 16
                                    radius: 12
                                    color: Colors.softAccentBg

                                    RowLayout {
                                        id: actionRow
                                        anchors.centerIn: parent
                                        spacing: 4

                                        StyledText {
                                            text: "Enter"
                                            color: Colors.softAccentText
                                            font.pixelSize: 10
                                            font.bold: true
                                        }

                                        StyledText {
                                            text: "↵"
                                            color: Colors.softAccentText
                                            font.pixelSize: 11
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: itemMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onEntered: launcherWindow.selectedIndex = index
                                onClicked: launcherWindow.launchApp(modelData)
                            }
                        }
                    }
                }
            }

            // Divider
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: Colors.outlineVariant
                opacity: 0.4
            }

            // ── 5. FOOTER / HINTS BAR CONTAINER (Unfolding Section 5 - Delay 320ms) ─────
            Item {
                id: footerContainer
                Layout.fillWidth: true
                Layout.preferredHeight: 38
                clip: true // 🌟 Clipping boundary for zero deformation reveal

                Item {
                    id: footerContent
                    width: parent.width
                    height: parent.height

                    x: launcherWindow.isOpen ? 0 : 28
                    y: launcherWindow.isOpen ? 0 : 35
                    opacity: launcherWindow.isOpen ? 1.0 : 0.0

                    Behavior on x {
                        SequentialAnimation {
                            PauseAnimation { duration: launcherWindow.isOpen ? 360 : 0 }
                            NumberAnimation {
                                duration: launcherWindow.isOpen ? 700 : 200
                                easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                            }
                        }
                    }
                    Behavior on y {
                        SequentialAnimation {
                            PauseAnimation { duration: launcherWindow.isOpen ? 360 : 0 }
                            NumberAnimation {
                                duration: launcherWindow.isOpen ? 700 : 200
                                easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                            }
                        }
                    }
                    Behavior on opacity {
                        SequentialAnimation {
                            PauseAnimation { duration: launcherWindow.isOpen ? 360 : 0 }
                            NumberAnimation {
                                duration: launcherWindow.isOpen ? 550 : 150
                                easing.type: launcherWindow.isOpen ? Easing.OutQuint : Easing.InCubic
                            }
                        }
                    }

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16

                        RowLayout {
                            spacing: 12

                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    width: 20; height: 18; radius: 4
                                    color: Colors.card
                                    StyledText { anchors.centerIn: parent; text: "↑↓"; color: Colors.textSub; font.pixelSize: 10; font.bold: true }
                                }
                                StyledText { text: "Выбор"; color: Colors.textSub; font.pixelSize: 11; opacity: 0.8 }
                            }

                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    width: 34; height: 18; radius: 4
                                    color: Colors.card
                                    StyledText { anchors.centerIn: parent; text: "↵"; color: Colors.textSub; font.pixelSize: 11; font.bold: true }
                                }
                                StyledText { text: "Открыть"; color: Colors.textSub; font.pixelSize: 11; opacity: 0.8 }
                            }

                            RowLayout {
                                spacing: 4
                                Rectangle {
                                    width: 28; height: 18; radius: 4
                                    color: Colors.card
                                    StyledText { anchors.centerIn: parent; text: "Esc"; color: Colors.textSub; font.pixelSize: 10; font.bold: true }
                                }
                                StyledText { text: "Закрыть"; color: Colors.textSub; font.pixelSize: 11; opacity: 0.8 }
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            height: 26
                            width: bannerBtnRow.implicitWidth + 14
                            radius: 13
                            color: bannerBtnMouse.containsMouse ? Colors.card : "transparent"

                            RowLayout {
                                id: bannerBtnRow
                                anchors.centerIn: parent
                                spacing: 6

                                StyledText {
                                    text: "󰋩"
                                    color: Colors.textSub
                                    font.pixelSize: 13
                                }

                                StyledText {
                                    text: launcherWindow.animeImagePath ? "Изменить баннер" : "Добавить баннер"
                                    color: Colors.textSub
                                    font.pixelSize: 11
                                }
                            }

                            MouseArea {
                                id: bannerBtnMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: pickImageProcess.running = true
                            }
                        }
                    }
                }
            }
        }
    }
}