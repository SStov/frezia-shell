import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import "../core"
import "../components"

ElasticDropdown {
    id: trayMenu

    property var menuHandle: null
    
    maxW: 240

    onIsOpenChanged: {
        if (isOpen && menuHandle && menuHandle.updateLayout) {
            // Принудительно обновляем layout меню при открытии
            menuHandle.updateLayout();
        }
    }

    // Динамически обновляем высоту окна, если пункты меню подгрузились с задержкой
    onMaxHChanged: {
        if (isOpen) {
            panelH = maxH;
        }
    }

    // Dynamic height based on content
    maxH: Math.min(600, menuColumn.implicitHeight + maxR)
    
    QsMenuOpener {
        id: opener
        menu: trayMenu.menuHandle
    }
    
    Rectangle {
        id: highlight

        property real targetY: 0
        property bool active: false

        x: 8
        y: menuColumn.y + targetY
        width: parent.width - 16
        height: 36
        radius: 8
        color: Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.15)
        opacity: active ? 1.0 : 0

        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutBack
                easing.overshoot: 0.8
            }
        }
        Behavior on opacity {
            NumberAnimation { duration: 150 }
        }
    }

    Column {
        id: menuColumn
        // Используем fill parent, так как ElasticDropdown уже дает отступ 12px (maxR * 0.5)
        // Это обеспечит идеальную симметрию сверху и снизу.
        anchors.fill: parent
        anchors.margins: 2
        spacing: 2

        StyledText {
            visible: opener.children.count === 0
            text: "Загрузка меню..."
            color: Colors.textSub
            font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }

        Repeater {
            model: opener.children

            delegate: Item {
                id: menuItem

                property bool isSeparator: modelData.isSeparator
                property bool hasChildren: modelData.hasChildren

                width: menuColumn.width
                height: isSeparator ? 12 : 36

                Rectangle {
                    visible: isSeparator
                    anchors.centerIn: parent
                    width: parent.width - 16
                    height: 1
                    color: Colors.outlineVariant
                    opacity: 0.5
                }

                Rectangle {
                    visible: !isSeparator && highlight.active && highlight.targetY === menuItem.y
                    width: 3
                    height: 16
                    radius: 2
                    color: Colors.accentBlue
                    anchors.left: parent.left
                    anchors.leftMargin: 4
                    anchors.verticalCenter: parent.verticalCenter
                }

                RowLayout {
                    visible: !isSeparator
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 12

                    Item {
                        Layout.preferredWidth: 20
                        Layout.preferredHeight: 20

                        Image {
                            anchors.centerIn: parent
                            width: 16
                            height: 16
                            source: modelData.icon || ""
                            fillMode: Image.PreserveAspectFit
                            visible: modelData.icon !== undefined && modelData.icon !== ""
                            layer.enabled: true
                            layer.effect: ColorOverlay {
                                color: (highlight.active && highlight.targetY === menuItem.y) ? Colors.accentBlue : Colors.fg
                            }
                        }
                        
                        Text {
                            anchors.centerIn: parent
                            visible: !(modelData.icon !== undefined && modelData.icon !== "")
                            text: ""
                            color: (highlight.active && highlight.targetY === menuItem.y) ? Colors.accentBlue : Colors.fg
                        }
                    }

                    Text {
                        text: modelData.text || ""
                        color: (highlight.active && highlight.targetY === menuItem.y) ? Colors.fg : Qt.rgba(Colors.fg.r, Colors.fg.g, Colors.fg.b, 0.8)
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        font.pixelSize: 13
                        font.bold: true
                        font.letterSpacing: 0.2
                        verticalAlignment: Text.AlignVCenter
                    }

                    Text {
                        visible: (modelData.checkable && modelData.checked) || menuItem.hasChildren
                        text: menuItem.hasChildren ? "▶" : "✓"
                        color: Colors.accentBlue
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    id: itemMouse
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: isSeparator ? Qt.ArrowCursor : Qt.PointingHandCursor
                    onEntered: {
                        if (!menuItem.isSeparator) {
                            highlight.targetY = menuItem.y;
                            highlight.active = true;
                        }
                    }
                    onClicked: {
                        if (!menuItem.isSeparator) {
                            if (modelData.hasChildren) {
                                trayMenu.menuHandle = modelData;
                            } else {
                                modelData.triggered();
                                trayMenu.isOpen = false;
                            }
                        }
                    }
                }
            }
        }
    }
}
