import QtQuick
import "../"
import "../../core"
import "../../components"

Rectangle {
    id: clockContainer
    property var bar
    
    height: 34
    width: clockRow.width + 8
    radius: 17
    color: (bar && bar.isCalendarOpen) ? Qt.rgba(Colors.muted.r, Colors.muted.g, Colors.muted.b, 0.4) : "transparent"
    Behavior on color { ColorAnimation { duration: 150 } }

    Row {
        id: clockRow
        anchors.centerIn: parent
        spacing: 8
        
        MediaPlayerBar {
            id: mediaPlayerBarLeft
            widgetWidth: bar ? bar.mediaPlayerWidth : 180
            visible: bar ? (bar.mediaPlayerPosition === 0) : true
            width: visible ? widgetWidth : 0
            onTogglePopup: (xPos) => {
                if (bar) {
                    bar.isMediaPlayerOpen = !bar.isMediaPlayerOpen;
                    bar.toggleMediaPlayer(xPos);
                }
            }
        }
        
        Rectangle {
            id: clockBtn
            width: 150; height: 30; radius: 15
            color: (bar && bar.isCalendarOpen) ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.85) : (clockMouse.containsMouse ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.6) : "transparent")
            scale: clockMouse.pressed ? 0.95 : (clockMouse.containsMouse ? 1.03 : 1.0)
            
            StyledText {
                id: clockText
                anchors.centerIn: parent
                color: (bar && bar.isCalendarOpen) ? Colors.bg : Colors.textMain
                font.pixelSize: 14; font.bold: true
                Timer { interval: 1000; running: true; repeat: true; onTriggered: clockText.text = Qt.formatDateTime(new Date(), "ddd, d MMM hh:mm") }
                Component.onCompleted: clockText.text = Qt.formatDateTime(new Date(), "ddd, d MMM hh:mm")
            }

            MouseArea {
                id: clockMouse
                anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                onClicked: {
                    if (bar) {
                        let pos = mapToItem(bar, width / 2, 0)
                        bar.toggleCalendar(pos.x)
                    }
                }
            }
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
        }
        
        MediaPlayerBar {
            id: mediaPlayerBarRight
            widgetWidth: bar ? bar.mediaPlayerWidth : 180
            visible: bar ? (bar.mediaPlayerPosition === 1) : false
            width: visible ? widgetWidth : 0
            onTogglePopup: (xPos) => {
                if (bar) {
                    bar.isMediaPlayerOpen = !bar.isMediaPlayerOpen;
                    bar.toggleMediaPlayer(xPos);
                }
            }
        }
    }
}
