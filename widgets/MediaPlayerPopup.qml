import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick.Effects
import "../core"
import "../components"

Item {
    id: root
    width: 320
    height: 366
    
    property bool isOpen: false
    property real bgOpacity: 0.95
    
    property var playersList: Mpris.players.values
    property var player: playersList.length > 0 ? playersList[0] : null
    property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
    property string trackArt: ""
    property string trackTitle: "Ничего не играет"
    property string trackArtist: ""
    property real trackLength: 0
    property real currentPosition: 0
    property real rawTrackLength: 0
    property bool cavaActive: false
    property var spectrumValues: Array(28).fill(0)
    
    onPlayerChanged: updateTrackInfo()
    
    function updateTrackInfo() {
        if (player) {
            root.trackTitle = player.trackTitle || "Ничего не играет"
            root.trackArtist = player.trackArtist || ""
            root.rawTrackLength = player.length > 0 ? player.length : 0
            root.trackLength = root.toSeconds(root.rawTrackLength)
            root.currentPosition = root.toSeconds(player.position || 0)
            if (player.trackArtUrl && player.trackArtUrl !== "") {
                root.trackArt = player.trackArtUrl
            } else {
                root.trackArt = ""
            }
        } else {
            root.trackTitle = "Ничего не играет"
            root.trackArtist = ""
            root.rawTrackLength = 0
            root.trackLength = 0
            root.currentPosition = 0
            root.trackArt = ""
        }
    }

    function toSeconds(value) {
        if (!value || isNaN(value) || value < 0) return 0

        // MPRIS length is commonly microseconds, while some Quickshell/player
        // bindings expose seconds or milliseconds. Normalize defensively.
        if (value > 10000000) return value / 1000000  // microseconds
        if (value > 100000) return value / 1000       // milliseconds
        return value                                  // seconds
    }

    function fromSeconds(seconds) {
        if (!root.rawTrackLength || isNaN(root.rawTrackLength)) return seconds
        if (root.rawTrackLength > 10000000) return seconds * 1000000
        if (root.rawTrackLength > 100000) return seconds * 1000
        return seconds
    }

    function refreshTiming() {
        if (!root.player) return
        root.rawTrackLength = root.player.length > 0 ? root.player.length : root.rawTrackLength
        root.trackLength = root.toSeconds(root.rawTrackLength)
        if (!seekMouse.pressed) root.currentPosition = root.toSeconds(root.player.position || 0)
    }

    function seekToRatio(ratio) {
        if (!root.player || root.trackLength <= 0) return
        if (root.player.canSeek === false) return

        let clamped = Math.max(0, Math.min(1, ratio))
        let targetSeconds = clamped * root.trackLength
        root.currentPosition = targetSeconds
        root.player.position = root.fromSeconds(targetSeconds)
    }
    
    Connections {
        target: root.player
        function onTrackArtUrlChanged() {
            if (root.player && root.player.trackArtUrl && root.player.trackArtUrl !== "") {
                root.trackArt = root.player.trackArtUrl
            }
        }
        function onTrackTitleChanged() { if (root.player) root.trackTitle = root.player.trackTitle || "Ничего не играет" }
        function onTrackArtistChanged() { if (root.player) root.trackArtist = root.player.trackArtist || "" }
        function onLengthChanged() { root.refreshTiming() }
        function onPositionChanged() { root.refreshTiming() }
    }
    
    Timer {
        interval: 500
        running: root.player !== null
        repeat: true
        onTriggered: root.refreshTiming()
    }

    Process {
        id: cavaProcess
        command: ["bash", "/home/stul/.config/quickshell/Scripts/cava-media-popup.sh"]
        running: root.isOpen && root.isPlaying

        onRunningChanged: {
            if (!running) root.cavaActive = false
        }

        stdout: SplitParser {
            onRead: (line) => {
                let clean = line.trim()
                if (clean.length === 0) return

                let parts = clean.split(';')
                let values = []
                for (let i = 0; i < 28; i++) {
                    let value = i < parts.length ? parseInt(parts[i]) : 0
                    values.push(Math.max(0, Math.min(100, isNaN(value) ? 0 : value)))
                }

                root.spectrumValues = values
                root.cavaActive = true
            }
        }
    }
    
    function formatTime(seconds) {
        if (isNaN(seconds) || seconds < 0) return "0:00";
        var m = Math.floor(seconds / 60);
        var s = Math.floor(seconds % 60);
        return m + ":" + (s < 10 ? "0" + s : s);
    }
    
    Rectangle {
        anchors.fill: parent
        radius: 24
        color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, shellRoot ? shellRoot.qsOpacity : 0.95)
        clip: true
        
        opacity: root.isOpen ? 1.0 : 0.0
        scale: root.isOpen ? 1.0 : 0.92
        Behavior on opacity { NumberAnimation { duration: 250; easing.type: Easing.OutQuart } }
        Behavior on scale { NumberAnimation { duration: 250; easing.type: Easing.OutBack } }
        
        Image {
            id: bgArt
            anchors.fill: parent
            source: root.trackArt
            fillMode: Image.PreserveAspectCrop
            visible: false
        }
        
        MultiEffect {
            source: bgArt
            anchors.fill: parent
            blurEnabled: true
            blurMax: 64
            blur: 1.0
            opacity: 0.3
            visible: root.trackArt !== ""
        }
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 16
            spacing: 10
            
            // Album art with proper rounded corners
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                width: 120; height: 120; radius: 12
                color: Colors.card
                
                // Create rounded mask
                Rectangle {
                    id: popupAlbumMask
                    anchors.fill: parent
                    radius: 12
                    color: "white"
                    visible: false
                    layer.enabled: true
                }
                
                Image {
                    id: popupAlbumImg
                    anchors.fill: parent
                    source: root.trackArt
                    fillMode: Image.PreserveAspectCrop
                    visible: false
                    cache: false
                    asynchronous: true
                }
                
                // Apply mask using MultiEffect
                MultiEffect {
                    source: popupAlbumImg
                    anchors.fill: parent
                    maskEnabled: true
                    maskSource: popupAlbumMask
                    visible: root.trackArt !== ""
                }
                
                StyledText {
                    anchors.centerIn: parent
                    text: "󰝚"
                    color: Colors.accentBlue
                    font.pixelSize: 40
                    visible: root.trackArt === ""
                }
            }
            
            // Track info
            ColumnLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 2
                
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.trackTitle
                    color: Colors.textMain
                    font.bold: true
                    font.pixelSize: 14
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }
                
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.trackArtist
                    color: Colors.textSub
                    font.pixelSize: 11
                    elide: Text.ElideRight
                    Layout.maximumWidth: 260
                }
            }

            // Beat visualizer / equalizer
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: 16
                color: Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.34)
                opacity: root.player ? 1.0 : 0.45

                Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutQuart } }

                Row {
                    id: equalizerBars
                    anchors.centerIn: parent
                    height: 30
                    spacing: 4

                    Repeater {
                        model: 28

                        Rectangle {
                            anchors.bottom: parent.bottom
                            width: 5
                            height: root.cavaActive ? cavaHeight : (root.isPlaying ? baseHeight : idleHeight)
                            radius: width / 2
                            opacity: root.cavaActive ? 1.0 : (root.isPlaying ? 0.95 : 0.38)
                            color: {
                                if (index % 5 === 0) return Colors.secondary
                                if (index % 2 === 0) return Colors.accentBlue
                                return Colors.accentPurple
                            }

                            readonly property int idleHeight: 5 + ((index * 3) % 7)
                            readonly property int baseHeight: 8 + ((index * 5) % 10)
                            readonly property int peakHeight: 14 + ((index * 7) % 17)
                            readonly property int pulseDuration: 260 + ((index * 37) % 260)
                            readonly property real cavaValue: root.spectrumValues && index < root.spectrumValues.length ? root.spectrumValues[index] : 0
                            readonly property real cavaHeight: 4 + (cavaValue / 100) * 26

                            Behavior on opacity { NumberAnimation { duration: 220 } }
                            Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }

                            SequentialAnimation on height {
                                loops: Animation.Infinite
                                running: root.isPlaying && !root.cavaActive
                                PauseAnimation { duration: index * 28 }
                                NumberAnimation { to: peakHeight; duration: pulseDuration; easing.type: Easing.InOutQuad }
                                NumberAnimation { to: baseHeight; duration: pulseDuration + 80; easing.type: Easing.OutCubic }
                            }
                        }
                    }
                }

                StyledText {
                    anchors.centerIn: parent
                    text: "Пауза"
                    color: Colors.textSub
                    font.pixelSize: 10
                    opacity: root.player && !root.isPlaying ? 0.55 : 0
                    Behavior on opacity { NumberAnimation { duration: 180 } }
                }
            }
            
            // Seek bar
            Rectangle {
                Layout.fillWidth: true
                height: 4
                radius: 2
                color: Colors.card
                
                Rectangle {
                    width: parent.width * (root.trackLength > 0 ? Math.min(1, root.currentPosition / root.trackLength) : 0)
                    height: parent.height
                    radius: 2
                    color: Colors.accentBlue
                }
                
                MouseArea {
                    id: seekMouse
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    enabled: root.player !== null && root.trackLength > 0 && root.player.canSeek !== false
                    function updateSeek(mouseX) {
                        let localX = Math.max(0, Math.min(parent.width, mouseX - anchors.leftMargin))
                        root.seekToRatio(localX / parent.width)
                    }
                    onClicked: (mouse) => {
                        updateSeek(mouse.x)
                    }
                    onPositionChanged: (mouse) => {
                        if (pressed) updateSeek(mouse.x)
                    }
                }
            }
            
            // Time labels
            Row {
                Layout.alignment: Qt.AlignHCenter
                spacing: 12
                
                StyledText {
                    text: root.formatTime(root.currentPosition)
                    color: Colors.textSub
                    font.pixelSize: 11
                }
                
                StyledText {
                    text: "/"
                    color: Colors.textSub
                    font.pixelSize: 11
                    opacity: 0.5
                }
                
                StyledText {
                    text: root.formatTime(root.trackLength)
                    color: Colors.textSub
                    font.pixelSize: 11
                }
            }
            
            // Controls
            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                spacing: 24
                
                StyledText {
                    text: "󰒮"
                    color: root.player && root.player.canGoPrevious ? Colors.textSub : Qt.rgba(Colors.textSub.r, Colors.textSub.g, Colors.textSub.b, 0.3)
                    font.pixelSize: 20
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.player) root.player.previous(); } }
                }
                
                StyledText {
                    text: root.isPlaying ? "󰏤" : "󰐊"
                    color: Colors.accentBlue
                    font.pixelSize: 26
                    font.bold: true
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.player) { if (root.isPlaying) root.player.pause(); else root.player.play(); } } }
                }
                
                StyledText {
                    text: "󰒭"
                    color: root.player && root.player.canGoNext ? Colors.textSub : Qt.rgba(Colors.textSub.r, Colors.textSub.g, Colors.textSub.b, 0.3)
                    font.pixelSize: 20
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { if (root.player) root.player.next(); } }
                }
            }
        }
    }
}
