import QtQuick
import QtQuick.Layouts
import "."
import "../../core"
import "../../components"

Item {
    id: rootLayout
    property var bar
    anchors.fill: parent

    Component {
        id: compWorkspaces
        WorkspacesWidget { bar: rootLayout.bar }
    }
    
    Component {
        id: compClock
        ClockWidget { bar: rootLayout.bar }
    }
    
    Component {
        id: compRight
        Row {
            spacing: rootLayout.bar ? rootLayout.bar.topBarTraySpacing : 10
            leftPadding: 25; rightPadding: 25
            
            ClipboardButton { bar: rootLayout.bar }
            KeyboardLayoutButton { bar: rootLayout.bar }
            CalculatorButton { bar: rootLayout.bar }
            OcrButton { bar: rootLayout.bar }
            TamagotchiButton { bar: rootLayout.bar }
            SystemTrayWidget { bar: rootLayout.bar }
            PowerButton { bar: rootLayout.bar }
            ControlCenterButton { bar: rootLayout.bar }
            NotificationButton { bar: rootLayout.bar }
        }
    }
    
    property var componentsList: [compWorkspaces, compClock, compRight]
    
    Item {
        id: leftContainer
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height; width: childrenRect.width
        Loader { 
            id: leftLoader
            anchors.verticalCenter: parent.verticalCenter 
            sourceComponent: (rootLayout.bar && rootLayout.bar.topBarOrder && rootLayout.bar.topBarOrder.length > 0) ? rootLayout.componentsList[rootLayout.bar.topBarOrder[0]] : null
        }
    }
    
    Item {
        id: centerContainer
        anchors.centerIn: parent
        height: parent.height; width: childrenRect.width
        Loader { 
            id: centerLoader
            anchors.verticalCenter: parent.verticalCenter 
            sourceComponent: (rootLayout.bar && rootLayout.bar.topBarOrder && rootLayout.bar.topBarOrder.length > 1) ? rootLayout.componentsList[rootLayout.bar.topBarOrder[1]] : null
        }
    }
    
    Item {
        id: rightContainer
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height; width: childrenRect.width
        Loader { 
            id: rightLoader
            anchors.verticalCenter: parent.verticalCenter 
            sourceComponent: (rootLayout.bar && rootLayout.bar.topBarOrder && rootLayout.bar.topBarOrder.length > 2) ? rootLayout.componentsList[rootLayout.bar.topBarOrder[2]] : null
        }
    }
}
