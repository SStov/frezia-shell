import QtQuick
import Quickshell.Services.Mpris
import QtQuick.Effects
import "../core"
import "../components"

Item {
    id: root
    
    property int widgetWidth: 180
    signal togglePopup(real xPos)
    
    property var player: MediaService.currentPlayer
    property bool isPlaying: player && player.playbackState === MprisPlaybackState.Playing
    property string trackArt: ""
    property string trackTitle: "..."
    
    width: player ? widgetWidth : 0
    visible: player !== null
    height: parent ? parent.height : 36
    
    Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutQuart } }
    Behavior on opacity { NumberAnimation { duration: 200 } }
    
    Component.onCompleted: {
        updateTrackInfo()
    }
    
    Connections {
        target: root.player
        function onTrackArtUrlChanged() {
            if (root.player && root.player.trackArtUrl) {
                root.trackArt = root.player.trackArtUrl
            } else {
                root.trackArt = ""
            }
        }
        function onTrackTitleChanged() {
            if (root.player) root.trackTitle = root.player.trackTitle || "..."
        }
    }
    
    function updateTrackInfo() {
        if (root.player) {
            root.trackTitle = root.player.trackTitle || "..."
            // Force immediate update of track art
            if (root.player.trackArtUrl && root.player.trackArtUrl !== "") {
                root.trackArt = root.player.trackArtUrl
            } else {
                root.trackArt = ""
            }
        } else {
            root.trackTitle = "..."
            root.trackArt = ""
        }
    }
    
    onPlayerChanged: {
        updateTrackInfo()
        // Force art update after a short delay to ensure Mpris has loaded metadata
        if (root.player) {
            Qt.callLater(function() {
                if (root.player && root.player.trackArtUrl) {
                    root.trackArt = root.player.trackArtUrl
                }
            })
        }
    }
    
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        leftPadding: 6
        rightPadding: 6
        
        // Album art with proper rounded corners using mask
        Rectangle {
            width: 26; height: 26; radius: 13
            color: Colors.card
            anchors.verticalCenter: parent.verticalCenter
            
            // Create circular mask
            Rectangle {
                id: albumMask
                anchors.fill: parent
                radius: 13
                color: "white"
                visible: false
                layer.enabled: true
            }
            
            Image {
                id: albumImg
                anchors.fill: parent
                source: root.trackArt
                fillMode: Image.PreserveAspectCrop
                visible: false
                cache: true
                asynchronous: true
            }
            
            // Apply mask using MultiEffect
            MultiEffect {
                source: albumImg
                anchors.fill: parent
                maskEnabled: true
                maskSource: albumMask
                visible: root.trackArt !== ""
            }
            
            // Default icon when no art
            StyledText {
                anchors.centerIn: parent
                text: "󰝚"
                color: Colors.accentBlue
                font.pixelSize: 12
                visible: root.trackArt === ""
            }
            
            RotationAnimation on rotation {
                loops: Animation.Infinite
                from: 0; to: 360; duration: 8000
                running: root.isPlaying && root.trackArt !== ""
            }
        }
        
        Item {
            id: textClipArea
            anchors.verticalCenter: parent.verticalCenter
            width: root.widgetWidth - 44
            height: parent.height
            clip: true

            Item {
                id: marqueeContainer
                height: parent.height
                width: text1.paintedWidth + 50
                
                readonly property bool needsMarquee: text1.paintedWidth > textClipArea.width
                onWidthChanged: x = 0

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 50
                    
                    StyledText {
                        id: text1
                        text: root.trackTitle
                        color: Colors.textMain
                        font.pixelSize: 13
                    }
                    
                    StyledText {
                        id: text2
                        text: root.trackTitle
                        color: Colors.textMain
                        font.pixelSize: 13
                        visible: marqueeContainer.needsMarquee
                    }
                }

                NumberAnimation {
                    id: marqueeAnim
                    target: marqueeContainer
                    property: "x"
                    loops: Animation.Infinite
                    from: 0
                    to: -(text1.paintedWidth + 50)
                    duration: (text1.paintedWidth + 50) * 25 // Скорость константная: 40px/сек
                    running: marqueeContainer.needsMarquee && root.isPlaying
                    
                    onRunningChanged: {
                        if (!running) marqueeContainer.x = 0;
                    }
                }
            }
        }
    }
    
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            let pos = mapToItem(root.parent, width / 2, 0)
            root.togglePopup(pos.x)
        }
    }
}
