import QtQuick
import QtQuick.Layouts
import QtQuick.Dialogs 
import QtQuick.Effects // 🌟 Обязательно для идеального сглаживания MultiEffect
import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import "../core"
import "../components"

PanelWindow {
    id: imageWidgetLayer

    WlrLayershell.namespace: "qs-desktop-image"
    WlrLayershell.layer: WlrLayer.Bottom
    
    // 🌟 ВАЖНО: Игнорируем эксклюзивную зону, чтобы тайловые окна не сплющило!
    exclusionMode: ExclusionMode.Ignore 
    
    // Растягиваем на весь экран, чтобы виджеты могли свободно перемещаться
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    property var settings

    // ==========================================
    // НАТИВНЫЙ ВЫБОР ФАЙЛА
    // ==========================================
    FileDialog {
        id: imagePicker
        title: "Выберите вайбовую картинку"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.gif *.webp)"]
        property int targetIndex: -1
        onAccepted: {
            let fileUrl = selectedFile.toString();
            if (targetIndex >= 0 && targetIndex < settings.imageWidgets.length) {
                var obj = settings.imageWidgets[targetIndex];
                obj.path = fileUrl;
                settings.updateImageWidget(targetIndex, obj);
            }
        }
    }

    // ==========================================
    // СЕТКА ВИДЖЕТОВ
    // ==========================================
    Repeater {
        model: settings ? settings.imageWidgets : []

        delegate: Item {
            id: widgetRoot
            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            property bool isEditing: settings ? settings.editMode : false

            // 🌟 САМА ФОТОРАМКА
            Rectangle {
                anchors.fill: parent
                radius: modelData.radius || 20 
                
                color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, 0.4)

                // МАГИЯ СГЛАЖИВАНИЯ: Невидимый трафарет
                Rectangle {
                    id: imageMask
                    anchors.fill: parent
                    anchors.margins: 1 
                    radius: (modelData.radius || 20) - 1 
                    visible: false
                    antialiasing: true
                    layer.enabled: true 
                }

                // Исходная картинка 
                Image {
                    id: hiddenImage
                    anchors.fill: parent
                    anchors.margins: 1
                    source: modelData.path || ""
                    fillMode: Image.PreserveAspectCrop 
                    visible: false 
                    smooth: true
                    antialiasing: true
                    layer.enabled: true 
                }

                // Результат
                MultiEffect {
                    anchors.fill: hiddenImage
                    source: hiddenImage
                    maskEnabled: true
                    maskSource: imageMask
                    visible: hiddenImage.status === Image.Ready 
                }

                // Заглушка
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 10
                    visible: hiddenImage.status !== Image.Ready

                    StyledText { Layout.alignment: Qt.AlignHCenter; text: "󰋩"; color: Colors.textSub; font.pixelSize: 48 }
                    StyledText { Layout.alignment: Qt.AlignHCenter; text: "Кликни,\nчтобы выбрать"; color: Colors.textSub; font.pixelSize: 14; horizontalAlignment: Text.AlignHCenter }
                }

                // Кнопка, Ховер и Драг-логика
                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: isEditing ? Qt.OpenHandCursor : Qt.PointingHandCursor
                    
                    drag.target: isEditing ? widgetRoot : null
                    drag.axis: Drag.XAndYAxis
                    
                    onReleased: {
                        if (isEditing) {
                            var obj = settings.imageWidgets[index];
                            obj.x = widgetRoot.x;
                            obj.y = widgetRoot.y;
                            settings.updateImageWidget(index, obj);
                        }
                    }

                    onClicked: {
                        if (!isEditing) {
                            imagePicker.targetIndex = index;
                            imagePicker.open();
                        }
                    }
                    
                    Rectangle {
                        anchors.fill: parent; radius: modelData.radius || 20
                        color: "black"
                        opacity: parent.containsMouse && !isEditing ? 0.3 : 0
                        Behavior on opacity { NumberAnimation { duration: 150 } }
                        StyledText { anchors.centerIn: parent; text: "󰄄"; color: Colors.bg; font.pixelSize: 32; visible: parent.opacity > 0 }
                    }
                }
            }

            // 🌟 ОВЕРЛЕЙ РЕДАКТИРОВАНИЯ (Ресайз, Удаление)
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                radius: modelData.radius || 20
                visible: isEditing

                // Удаление
                Rectangle {
                    width: 28; height: 28; radius: 14
                    anchors.left: parent.left; anchors.top: parent.top; anchors.margins: -10
                    color: Colors.error
                    StyledText { anchors.centerIn: parent; text: ""; color: Colors.bg; font.pixelSize: 14; font.bold: true }
                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: settings.removeImageWidget(index) }
                }

                // Ресайз
                Rectangle {
                    width: 28; height: 28; radius: 14
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: -10
                    color: Colors.accentBlue
                    StyledText { anchors.centerIn: parent; text: "󰡈"; color: Colors.rootBg; font.pixelSize: 14 }
                    
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.SizeFDiagCursor
                        
                        property real startX
                        property real startY
                        property real startW
                        property real startH
                        
                        onPressed: (mouse) => { 
                            let mapped = mapToItem(widgetRoot.parent, mouse.x, mouse.y);
                            startX = mapped.x; startY = mapped.y; 
                            startW = widgetRoot.width; startH = widgetRoot.height; 
                        }
                        onPositionChanged: (mouse) => {
                            if (pressed) {
                                let mapped = mapToItem(widgetRoot.parent, mouse.x, mouse.y);
                                widgetRoot.width = Math.max(100, startW + (mapped.x - startX));
                                widgetRoot.height = Math.max(100, startH + (mapped.y - startY));
                            }
                        }
                        onReleased: {
                            var obj = settings.imageWidgets[index];
                            obj.w = widgetRoot.width;
                            obj.h = widgetRoot.height;
                            settings.updateImageWidget(index, obj);
                        }
                    }
                }
            }
        }
    }
}