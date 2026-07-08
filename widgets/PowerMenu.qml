import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../core"
import "../components"

Item {
    id: powerMenu
    
    property bool isOpen: false
    
    readonly property real maxW: 200
    readonly property real maxH: 224  // 5 items × 40px + 16px padding + spacing
    property real panelH: 0.0
    
    width: maxW
    height: panelH 
    
    Behavior on panelH {
        NumberAnimation { duration: 250; easing.type: Easing.OutQuart }
    }
    
    onIsOpenChanged: panelH = isOpen ? maxH : 0.0
      
    // Hidden processes for power commands  
    Process { id: lockProcess; command: ["loginctl", "lock-session"] }
    Process { id: sleepProcess; command: ["systemctl", "suspend"] }
    Process { id: hibernateProcess; command: ["systemctl", "hibernate"] }
    Process { id: rebootProcess; command: ["systemctl", "reboot"] }
    Process { id: shutdownProcess; command: ["systemctl", "poweroff"] }
    
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: 18
        color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, shellRoot ? shellRoot.qsOpacity : 0.95)
        
        opacity: powerMenu.panelH > 10 ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 100 } }
        
        clip: true
        
        Item {
            id: innerContent
            x: 8
            y: powerMenu.isOpen ? 8 : -20
            width: powerMenu.maxW - 16
            height: powerMenu.maxH - 16
            
            opacity: powerMenu.isOpen ? 1.0 : 0.0
            
            Behavior on y {
                NumberAnimation { duration: 200; easing.type: Easing.OutQuart }
            }
            Behavior on opacity {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            
            Column {
                id: menuColumn
                width: parent.width
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2
                
                // Menu item — встроенный компонент (без анимации x, чтобы не дёргалось)
                Rectangle {
                    id: lockItem
                    width: parent.width; height: 40; radius: 12
                    color: lockMouse.containsMouse ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2) : "transparent"
                    // Мгновенный hover, без анимации
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 12
                        StyledText { text: "󰍁"; color: lockMouse.containsMouse ? Colors.accentBlue : Colors.textMain; font.pixelSize: 18; }
                        StyledText { text: "Lock"; color: lockMouse.containsMouse ? Colors.accentBlue : Colors.textMain; font.pixelSize: 14; font.bold: true; }
                    }
                    
                    MouseArea {
                        id: lockMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { lockProcess.running = true; powerMenu.isOpen = false }
                    }
                }
                
                Rectangle {
                    id: sleepItem
                    width: parent.width; height: 40; radius: 12
                    color: sleepMouse.containsMouse ? Qt.rgba(Colors.accentPurple.r, Colors.accentPurple.g, Colors.accentPurple.b, 0.2) : "transparent"
                    // Мгновенный hover, без анимации
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 12
                        StyledText { text: "󰏦"; color: sleepMouse.containsMouse ? Colors.accentPurple : Colors.textMain; font.pixelSize: 18; }
                        StyledText { text: "Sleep"; color: sleepMouse.containsMouse ? Colors.accentPurple : Colors.textMain; font.pixelSize: 14; font.bold: true; }
                    }
                    
                    MouseArea {
                        id: sleepMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { sleepProcess.running = true; powerMenu.isOpen = false }
                    }
                }
                
                Rectangle {
                    id: hibernateItem
                    width: parent.width; height: 40; radius: 12
                    color: hibernateMouse.containsMouse ? Qt.rgba(Colors.secondary.r, Colors.secondary.g, Colors.secondary.b, 0.2) : "transparent"
                    // Мгновенный hover, без анимации
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 12
                        StyledText { text: "󰒲"; color: hibernateMouse.containsMouse ? Colors.secondary : Colors.textMain; font.pixelSize: 18; }
                        StyledText { text: "Hibernate"; color: hibernateMouse.containsMouse ? Colors.secondary : Colors.textMain; font.pixelSize: 14; font.bold: true; }
                    }
                    
                    MouseArea {
                        id: hibernateMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { hibernateProcess.running = true; powerMenu.isOpen = false }
                    }
                }
                
                Rectangle {
                    id: rebootItem
                    width: parent.width; height: 40; radius: 12
                    color: rebootMouse.containsMouse ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2) : "transparent"
                    // Мгновенный hover, без анимации
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 12
                        StyledText { text: "󰑐"; color: rebootMouse.containsMouse ? Colors.accentBlue : Colors.textMain; font.pixelSize: 18; }
                        StyledText { text: "Reboot"; color: rebootMouse.containsMouse ? Colors.accentBlue : Colors.textMain; font.pixelSize: 14; font.bold: true; }
                    }
                    
                    MouseArea {
                        id: rebootMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { rebootProcess.running = true; powerMenu.isOpen = false }
                    }
                }
                
                Rectangle {
                    id: shutdownItem
                    width: parent.width; height: 40; radius: 12
                    color: shutdownMouse.containsMouse ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2) : "transparent"
                    // Мгновенный hover, без анимации
                    
                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.verticalCenterOffset: 2
                        anchors.left: parent.left; anchors.leftMargin: 12
                        anchors.right: parent.right; anchors.rightMargin: 12
                        spacing: 12
                        StyledText { text: "󰐥"; color: shutdownMouse.containsMouse ? Colors.error : Colors.textMain; font.pixelSize: 18; }
                        StyledText { text: "Shutdown"; color: shutdownMouse.containsMouse ? Colors.error : Colors.textMain; font.pixelSize: 14; font.bold: true; }
                    }
                    
                    MouseArea {
                        id: shutdownMouse
                        anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: { shutdownProcess.running = true; powerMenu.isOpen = false }
                    }
                }
            }
        }
    }
}
