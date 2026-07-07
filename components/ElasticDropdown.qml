import QtQuick
import "../core"

Item {
    id: dropdownObj
    
    // API компонента
    property bool isOpen: false
    property real maxW: 450
    property real maxH: 500
    readonly property real maxR: 24
    property real bgOpacity: 0.95
    property bool useRootBg: false

    width: maxW
    height: panelH
    z: 10

    property real panelH: 0.0
    
    // Простая и быстрая анимация (без лагов на холостом старте)
    Behavior on panelH { 
        NumberAnimation { 
            duration: 200 
            easing.type: Easing.OutQuart 
        } 
    }
    
    onIsOpenChanged: panelH = isOpen ? maxH : 0.0

    // Обычный прямоугольник вместо тяжелой геометрии (Shape)
    Rectangle {
        id: bgRect
        anchors.fill: parent
        radius: Math.floor(Math.min(dropdownObj.maxR, height / 2))

        color: useRootBg 
            ? Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, dropdownObj.bgOpacity)
            : Qt.rgba(Colors.card.r, Colors.card.g, Colors.card.b, dropdownObj.bgOpacity)
        
        // Избегаем мерцания рамки при нулевой высоте
        opacity: dropdownObj.panelH > 2 ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: 50 } }

        // Контейнер-маска для безопасной обрезки (чтобы контент не вылезал за скругления)
        Item {
            id: clipContainer
            x: dropdownObj.maxR * 0.5
            y: dropdownObj.maxR * 0.5
            width: dropdownObj.width - dropdownObj.maxR
            // Динамическая высота для обрезки контента строго внутри скруглений
            height: Math.max(0, dropdownObj.panelH - dropdownObj.maxR)
            clip: true
            
            // Фиксированный размер для контента, чтобы верстка (ColumnLayout) не "сплющивалась"
            Item {
                id: innerContent
                width: parent.width
                height: dropdownObj.maxH - dropdownObj.maxR
                
                opacity: dropdownObj.isOpen ? 1.0 : 0.0

                Behavior on opacity {
                    NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
                }
            }
        }
    }
    
    default property alias content: innerContent.data
}