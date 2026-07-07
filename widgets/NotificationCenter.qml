import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Io
import "../core"
import "../components"

PanelWindow {
    id: notifCenterWindow

    WlrLayershell.namespace: "qs-notifcenter"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
    exclusionMode: ExclusionMode.Ignore

    anchors {
        top: true
        bottom: true
        right: true
    }

    margins {
        top: shellRoot ? shellRoot.getPopupY() : 40
        bottom: 20
    }

    property bool isOpen: false

    implicitWidth: 380
    color: "transparent"

    // Маска схлопывается когда закрыто — иначе PanelWindow перехватывает клики своей зоной
    mask: Region {
        item: maskRect
    }

    Rectangle {
        id: maskRect
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: notifCenterWindow.isOpen ? 380 : 0
        color: "transparent"

        Behavior on width {
            enabled: !notifCenterWindow.isOpen
            NumberAnimation { duration: 550 }  // ждём завершения каскадной анимации закрытия (~150 + 320 = 470ms)
        }
    }

    // ── MPRIS player ─────────────────────────────────
    property var mprisPlayer: {
        let vals = Mpris.players.values
        return (vals && vals.length > 0) ? vals[0] : null
    }
    property bool isPlaying: mprisPlayer && mprisPlayer.playbackState === MprisPlaybackState.Playing
    property string trackTitle: mprisPlayer ? (mprisPlayer.trackTitle || "Ничего не играет") : "Ничего не играет"
    property string trackArtist: mprisPlayer ? (mprisPlayer.trackArtist || "") : ""

    Connections {
        target: Mpris.players
        function onValuesChanged() {
            let vals = Mpris.players.values
            notifCenterWindow.mprisPlayer = (vals && vals.length > 0) ? vals[0] : null
        }
    }

    Connections {
        target: notifCenterWindow.mprisPlayer
        function onTrackTitleChanged() {
            if (notifCenterWindow.mprisPlayer)
                notifCenterWindow.trackTitle = notifCenterWindow.mprisPlayer.trackTitle || "Ничего не играет"
        }
        function onTrackArtistChanged() {
            if (notifCenterWindow.mprisPlayer)
                notifCenterWindow.trackArtist = notifCenterWindow.mprisPlayer.trackArtist || ""
        }
        function onPlaybackStateChanged() {
            notifCenterWindow.isPlaying = Qt.binding(function() {
                return notifCenterWindow.mprisPlayer
                    && notifCenterWindow.mprisPlayer.playbackState === MprisPlaybackState.Playing
            })
        }
    }

    // ── Uptime ───────────────────────────────────────
    property string uptimeStr: "up ..."

    Process {
        id: uptimeProcess
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                let parts = this.text.split(" ")
                if (parts.length > 0) {
                    let secs = parseFloat(parts[0])
                    let d = Math.floor(secs / 86400)
                    let h = Math.floor((secs % 86400) / 3600)
                    let m = Math.floor((secs % 3600) / 60)
                    let s = "up "
                    if (d > 0) s += d + "d "
                    if (h > 0) s += h + "h "
                    s += m + "m"
                    notifCenterWindow.uptimeStr = s
                }
            }
        }
    }

    Timer {
        interval: 60000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: uptimeProcess.running = true
    }

    // ── Toggle component ─────────────────────────────
    component QuickToggle: Rectangle {
        property string icon: ""
        property string name: ""
        property bool isOn: false
        property color activeColor: Colors.accentBlue

        Layout.fillWidth: true
        height: 44; radius: 12
        color: isOn ? activeColor : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.35)

        Behavior on color { ColorAnimation { duration: 150 } }

        RowLayout {
            anchors.fill: parent; anchors.margins: 10; spacing: 10
            StyledText { text: icon; color: parent.parent.isOn ? Colors.bg : Colors.textMain; font.pixelSize: 16 }
            StyledText { text: name; color: parent.parent.isOn ? Colors.bg : Colors.textMain; font.bold: true; font.pixelSize: 13 }
        }

        MouseArea {
            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
            onClicked: parent.isOn = !parent.isOn
        }
    }

    // ── Helper: карточка-блок ────────────────────────
    component BlockCard: Rectangle {
        id: card
        width: parent ? parent.width : 348
        radius: 16
        color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, shellRoot ? shellRoot.qsOpacity : 0.95)
        border { color: Qt.rgba(Colors.outlineVariant.r, Colors.outlineVariant.g, Colors.outlineVariant.b, 0.25); width: 1 }

        // ── stagger slide-in:
        //     card.slideDelay = index * 60; card.triggerOpen()
        //     карточка «начинает» за экраном при x=390, по команде анимируется в x=0
        property int slideDelay: 0

        // Каскадная анимация открытия
        SequentialAnimation {
            id: slideInAnim
            running: false
            PauseAnimation { duration: card.slideDelay }
            NumberAnimation {
                target: card; property: "x"; from: 390; to: 0
                duration: 380; easing.type: Easing.OutCubic
            }
        }

        // Каскадная анимация закрытия (reverse stagger)
        SequentialAnimation {
            id: slideOutAnim
            running: false
            PauseAnimation { duration: Math.max(0, 150 - card.slideDelay) }
            NumberAnimation {
                target: card; property: "x"; to: 390
                duration: 320; easing.type: Easing.InCubic
            }
        }

        function triggerOpen()  { slideOutAnim.stop(); slideInAnim.start()  }
        function triggerClose() { slideInAnim.stop();  slideOutAnim.start() }
    }

    // ══════════════════════════════════════════════════
    // РАЗМЕТКА
    // ══════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        // ── БЛОК 1: ПРОФИЛЬ ──────────────────────────
        BlockCard {
            id: blockProfile
            slideDelay: 0
            Layout.fillWidth: true
            Layout.preferredHeight: 70

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 12

                Rectangle {
                    width: 46; height: 46; radius: 23; color: Colors.accentBlue
                    StyledText {
                        anchors.centerIn: parent; text: "󰣇"; color: Colors.bg; font.pixelSize: 22
                    }
                }

                ColumnLayout { spacing: 2
                    StyledText {
                        text: "STUL"; color: Colors.textMain
                        font.pixelSize: 16; font.bold: true
                    }
                    StyledText {
                        text: notifCenterWindow.uptimeStr
                        color: Colors.textSub; font.pixelSize: 12
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: clearMouse.containsMouse
                        ? Colors.error
                        : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.35)
                    StyledText {
                        anchors.centerIn: parent; text: "󰃢"
                        color: clearMouse.containsMouse ? Colors.bg : Colors.textMain
                        font.pixelSize: 16
                    }
                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (shellRoot && shellRoot.globalNotifModel)
                                shellRoot.globalNotifModel.clear()
                        }
                    }
                }
            }
        }

        // ── БЛОК 2: БЫСТРЫЕ ПЕРЕКЛЮЧАТЕЛИ ────────────
        BlockCard {
            id: blockToggles
            slideDelay: 60
            Layout.fillWidth: true
            Layout.preferredHeight: togglesGrid.implicitHeight + 24

            GridLayout {
                id: togglesGrid
                anchors { fill: parent; margins: 12 }
                columns: 2
                rowSpacing: 10; columnSpacing: 10

                QuickToggle {
                    icon: isOn ? "󰈀" : "󰈂"; name: "Network"
                    isOn: true; activeColor: Colors.accentBlue
                    MouseArea {
                        anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.isOn = !parent.isOn
                    }
                }

                QuickToggle {
                    icon: isOn ? "󰂯" : "󰂲"; name: "Bluetooth"
                    isOn: false; activeColor: Colors.accentPurple
                    MouseArea {
                        anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.isOn = !parent.isOn
                    }
                }

                QuickToggle {
                    icon: "󰒲"; name: "DND"
                    isOn: false; activeColor: Colors.accentPurple
                    MouseArea {
                        anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.isOn = !parent.isOn
                    }
                }

                QuickToggle {
                    icon: "󰖔"; name: "Night Light"
                    isOn: true; activeColor: Colors.accentPurple
                    MouseArea {
                        anchors.fill: parent; z: 1; cursorShape: Qt.PointingHandCursor
                        onClicked: parent.isOn = !parent.isOn
                    }
                }
            }
        }

        // ── БЛОК 3: МИНИ-ПЛЕЕР ───────────────────────
        BlockCard {
            id: blockPlayer
            slideDelay: 120
            Layout.fillWidth: true
            Layout.preferredHeight: 72

            visible: notifCenterWindow.mprisPlayer !== null

            RowLayout {
                anchors.fill: parent; anchors.margins: 12; spacing: 12

                // Album art
                Rectangle {
                    width: 48; height: 48; radius: 12; color: Colors.card
                    Image {
                        id: ncAlbumImg
                        anchors.fill: parent
                        source: notifCenterWindow.mprisPlayer ? (notifCenterWindow.mprisPlayer.trackArtUrl || "") : ""
                        fillMode: Image.PreserveAspectCrop
                        visible: false; cache: false; asynchronous: true
                    }
                    Rectangle {
                        id: ncAlbumMask
                        anchors.fill: parent; radius: 12; color: "white"
                        visible: false; layer.enabled: true
                    }
                    MultiEffect {
                        source: ncAlbumImg; anchors.fill: parent
                        maskEnabled: true; maskSource: ncAlbumMask
                        visible: ncAlbumImg.source !== ""
                    }
                    StyledText {
                        anchors.centerIn: parent; text: "󰝚"
                        color: Colors.accentBlue; font.pixelSize: 18
                        visible: ncAlbumImg.source === "" || ncAlbumImg.status !== Image.Ready
                    }
                    RotationAnimation on rotation {
                        loops: Animation.Infinite; from: 0; to: 360; duration: 8000
                        running: notifCenterWindow.isPlaying && ncAlbumImg.source !== ""
                    }
                }

                // Track info + marquee
                Item {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    clip: true

                    ColumnLayout {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 2

                        StyledText {
                            id: ncTrackTitle
                            text: notifCenterWindow.trackTitle
                            color: Colors.textMain; font.pixelSize: 13; font.bold: true
                        }

                        StyledText {
                            text: notifCenterWindow.trackArtist
                            color: Colors.textSub; font.pixelSize: 11
                            visible: text !== ""
                        }
                    }
                }

                // Play/Pause
                Rectangle {
                    width: 38; height: 38; radius: 19
                    color: ppMouse.containsMouse
                        ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2)
                        : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.35)
                    StyledText {
                        anchors.centerIn: parent
                        text: notifCenterWindow.isPlaying ? "󰏤" : "󰐊"
                        color: Colors.accentBlue; font.pixelSize: 18; font.bold: true
                    }
                    MouseArea {
                        id: ppMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (!notifCenterWindow.mprisPlayer) return
                            if (notifCenterWindow.isPlaying)
                                notifCenterWindow.mprisPlayer.pause()
                            else
                                notifCenterWindow.mprisPlayer.play()
                        }
                    }
                }
            }
        }

        // ── БЛОК 4: УВЕДОМЛЕНИЯ ──────────────────────
        BlockCard {
            id: blockNotifs
            slideDelay: 180
            Layout.fillWidth: true
            Layout.fillHeight: true

            ListView {
                id: listView
                anchors { fill: parent; margins: 10 }
                model: shellRoot ? shellRoot.globalNotifModel : null
                spacing: 10; clip: true
                boundsBehavior: Flickable.StopAtBounds

                // Empty state
                Item {
                    anchors.fill: parent
                    visible: listView.count === 0
                    ColumnLayout {
                        anchors.centerIn: parent; spacing: 12
                        StyledText {
                            text: "󰎟"; color: Colors.textSub
                            font.pixelSize: 64; Layout.alignment: Qt.AlignHCenter
                            opacity: 0.25
                        }
                        StyledText {
                            text: "Тишина и покой"
                            color: Colors.textMain; font.pixelSize: 16; font.bold: true
                            Layout.alignment: Qt.AlignHCenter
                        }
                        StyledText {
                            text: "Здесь будут появляться\nновые уведомления"
                            color: Colors.textSub; font.pixelSize: 13
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                        }
                    }
                }

                add: Transition {
                    NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 300 }
                    NumberAnimation { property: "x"; from: -40; to: 0; duration: 300; easing.type: Easing.OutBack }
                }

                remove: Transition {
                    NumberAnimation { property: "opacity"; to: 0; duration: 200 }
                    NumberAnimation { property: "scale"; to: 0.8; duration: 200 }
                }

                delegate: Rectangle {
                    width: listView.width
                    height: contentCol.implicitHeight + 20
                    color: itemMouse.containsMouse
                        ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.85)
                        : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.4)
                    radius: 14

                    property var n: model.notif

                    ColumnLayout {
                        id: contentCol
                        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 10 }
                        spacing: 6

                        RowLayout {
                            Layout.fillWidth: true; spacing: 8

                            Rectangle {
                                width: 22; height: 22; radius: 5; color: "transparent"
                                Image {
                                    anchors.fill: parent
                                    source: n && n.icon
                                        ? (n.icon.startsWith("/") ? "file://" + n.icon : "image://icon/" + n.icon)
                                        : ""
                                    sourceSize: Qt.size(22, 22)
                                    visible: status === Image.Ready; smooth: true
                                }
                                StyledText {
                                    anchors.centerIn: parent; text: "󰂚"
                                    color: Colors.accentBlue; font.pixelSize: 14
                                    visible: parent.children[0].status !== Image.Ready
                                }
                            }

                            StyledText {
                                text: model.nAppName; color: Colors.textMain
                                font.pixelSize: 12; font.bold: true
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }

                            StyledText {
                                text: model.nTime || ""; color: Colors.textSub; font.pixelSize: 10
                            }

                            Rectangle {
                                width: 20; height: 20; radius: 10
                                color: delMouse2.containsMouse ? Colors.error : "transparent"
                                StyledText {
                                    anchors.centerIn: parent; text: ""
                                    color: delMouse2.containsMouse ? Colors.bg : Colors.textSub
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    id: delMouse2
                                    anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (shellRoot && shellRoot.globalNotifModel)
                                            shellRoot.globalNotifModel.remove(index)
                                    }
                                }
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true; spacing: 4
                            Layout.leftMargin: 30

                            StyledText {
                                text: model.nSummary; color: Colors.textMain
                                font.pixelSize: 13; font.bold: true
                                wrapMode: Text.Wrap; Layout.fillWidth: true
                                maximumLineCount: 2; elide: Text.ElideRight
                            }

                            StyledText {
                                text: model.nBody; color: Colors.textSub
                                font.pixelSize: 12; wrapMode: Text.Wrap
                                Layout.fillWidth: true; visible: text !== ""
                                maximumLineCount: 4; elide: Text.ElideRight
                            }
                        }

                        Flow {
                            Layout.fillWidth: true; spacing: 6
                            Layout.topMargin: 2; Layout.leftMargin: 30
                            visible: n && n.actions && n.actions.length > 0

                            Repeater {
                                model: n && n.actions ? n.actions : []
                                delegate: Rectangle {
                                    width: actionText2.implicitWidth + 20; height: 26; radius: 13
                                    color: actMouse.containsMouse
                                        ? Colors.accentBlue
                                        : Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, 0.7)
                                    StyledText {
                                        id: actionText2
                                        anchors.centerIn: parent
                                        text: modelData.name || modelData.text || "Действие"
                                        color: actMouse.containsMouse ? Colors.bg : Colors.textMain
                                        font.pixelSize: 11; font.bold: true
                                    }
                                    MouseArea {
                                        id: actMouse
                                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            if (n) {
                                                n.invokeAction(modelData.id)
                                                if (shellRoot && shellRoot.globalNotifModel)
                                                    shellRoot.globalNotifModel.remove(index)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    MouseArea {
                        id: itemMouse
                        anchors.fill: parent; hoverEnabled: true; z: -1
                        onClicked: {
                            if (n && n.invokeDefaultAction) n.invokeDefaultAction()
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════
    // ЗАПУСК КАСКАДНОЙ АНИМАЦИИ
    // ══════════════════════════════════════════════════
    onIsOpenChanged: {
        if (isOpen) {
            blockProfile.triggerOpen()
            blockToggles.triggerOpen()
            blockPlayer.triggerOpen()
            blockNotifs.triggerOpen()
        } else {
            blockProfile.triggerClose()
            blockToggles.triggerClose()
            blockPlayer.triggerClose()
            blockNotifs.triggerClose()
        }
    }

    Component.onCompleted: {
        // Изначально все блоки за экраном, анимации остановлены
        blockProfile.x = 390; blockProfile.triggerClose()
        blockToggles.x = 390; blockToggles.triggerClose()
        blockPlayer.x = 390; blockPlayer.triggerClose()
        blockNotifs.x = 390; blockNotifs.triggerClose()
        // Явно сбрасываем isOpen — хот-релоад не должен оставлять виджет открытым
        isOpen = false
    }
}