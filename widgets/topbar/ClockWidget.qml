import QtQuick
import QtQuick.Layouts
import "../"
import "../../core"
import "../../components"

Rectangle {
    id: clockContainer
    property var bar
    
    property int currentDayIdx: 0
    property string currentTimeString: ""
    property string hoveredDayName: ""
    
    readonly property var dayNames: ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    property color colorToday: Colors.activeMode === "light" ? "#216e39" : "#39d353"
    property color colorPast: Colors.activeMode === "light" ? "#9be9a8" : "#0e4429"
    property color colorFuture: Colors.activeMode === "light" ? "#ebedf0" : "#21262d"

    function updateCurrentDay() {
        let day = new Date().getDay();
        currentDayIdx = (day === 0) ? 6 : day - 1;
    }

    function updateTime() {
        currentTimeString = Qt.formatDateTime(new Date(), "ddd, d MMM hh:mm");
    }

    Component.onCompleted: {
        updateCurrentDay();
        updateTime();
    }

    Timer {
        id: midnightTimer
        interval: 60000
        running: true
        repeat: true
        onTriggered: {
            updateCurrentDay();
        }
    }

    Timer {
        id: clockTimer
        interval: 1000
        running: true
        repeat: true
        onTriggered: updateTime()
    }

    QtObject {
        id: todayPulse
        property real opacityValue: 1.0
        SequentialAnimation on opacityValue {
            running: true
            loops: Animation.Infinite
            NumberAnimation { from: 0.4; to: 1.0; duration: 3000; easing.type: Easing.InOutSine }
            NumberAnimation { from: 1.0; to: 0.4; duration: 3000; easing.type: Easing.InOutSine }
        }
    }

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
                    bar.toggleMediaPlayer(xPos);
                }
            }
        }
        
        Rectangle {
            id: clockBtn
            width: 240; height: 30; radius: 15
            color: (bar && bar.isCalendarOpen) ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.85) : (clockMouse.containsMouse ? Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, 0.6) : "transparent")
            scale: clockMouse.pressed ? 0.95 : (clockMouse.containsMouse ? 1.03 : 1.0)
            
            RowLayout {
                id: contentRow
                anchors.centerIn: parent
                spacing: 10
                
                RowLayout {
                    spacing: 3
                    
                    Repeater {
                        model: 7
                        Rectangle {
                            width: 10; height: 10; radius: 2
                            color: {
                                if (index > currentDayIdx) {
                                    return colorFuture;
                                } else if (index < currentDayIdx) {
                                    return colorPast;
                                } else {
                                    return colorToday;
                                }
                            }
                            opacity: index === currentDayIdx ? todayPulse.opacityValue : 1.0
                            
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    let status = "";
                                    if (index > currentDayIdx) status = " (Future)";
                                    else if (index < currentDayIdx) status = " (Past)";
                                    else status = " (Today)";
                                    hoveredDayName = dayNames[index] + status;
                                }
                                onExited: {
                                    hoveredDayName = "";
                                }
                                onPressed: (mouse) => { mouse.accepted = false; }
                            }
                        }
                    }
                }
                
                Rectangle {
                    id: separator
                    width: 1
                    height: 14
                    color: (bar && bar.isCalendarOpen) ? Colors.bg : Colors.outlineVariant
                    opacity: 0.5
                }
                
                StyledText {
                    id: clockText
                    color: (bar && bar.isCalendarOpen) ? Colors.bg : Colors.textMain
                    font.pixelSize: 13; font.bold: true
                    text: hoveredDayName !== "" ? hoveredDayName : currentTimeString
                }
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
                    bar.toggleMediaPlayer(xPos);
                }
            }
        }
    }
}
