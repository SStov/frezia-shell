import QtQuick
import QtQuick.Layouts
import "."
import "../../core"
import "../../components"

Item {
    id: rootLayout
    property var bar
    anchors.fill: parent

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 15
        anchors.rightMargin: 15
        spacing: 15

        // Left side: Workspaces and Clock grouped together
        RowLayout {
            Layout.alignment: Qt.AlignLeft
            spacing: 15
            
            WorkspacesWidget { bar: rootLayout.bar }
            ClockWidget { bar: rootLayout.bar }
        }

        Item { Layout.fillWidth: true } // Spacer pushing widgets to the sides

        // Right side: System tray and Control buttons
        Row {
            Layout.alignment: Qt.AlignRight
            spacing: rootLayout.bar ? rootLayout.bar.topBarTraySpacing : 10
            
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
}
