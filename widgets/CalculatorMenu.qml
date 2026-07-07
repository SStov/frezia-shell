import QtQuick
import QtQuick.Layouts
import Quickshell
import "../core"
import "../components"

ElasticDropdown {
    id: root
    maxW: 280
    maxH: 380
    bgOpacity: shellRoot ? shellRoot.qsOpacity : 0.95
    useRootBg: true

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 12

        // Дисплей
        Rectangle {
            id: calcRect 
            Layout.preferredHeight: 70
            Layout.fillWidth: true
            radius: 16
            color: Qt.rgba(Colors.rootBg.r, Colors.rootBg.g, Colors.rootBg.b, bgOpacity)
            clip: true

            StyledText {
                id: display
                anchors.fill: parent
                anchors.margins: 15
                horizontalAlignment: Text.AlignRight
                verticalAlignment: Text.AlignVCenter
                text: calcLogic.expression === "" ? "0" : calcLogic.expression
                color: Colors.textMain
                font.pixelSize: 24
                font.bold: true
                elide: Text.ElideLeft
            }
        }

        // Кнопки
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 4
            rowSpacing: 8
            columnSpacing: 8

            Repeater {
                model: [
                    "C", "(", ")", "÷",
                    "7", "8", "9", "×",
                    "4", "5", "6", "-",
                    "1", "2", "3", "+",
                    "0", ".", "⌫", "="
                ]
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 10
                    
                    readonly property bool isOp: ["÷", "×", "-", "+", "="].includes(modelData)
                    readonly property bool isClear: modelData === "C" || modelData === "⌫"
                    
                    color: btnMouse.containsMouse ? 
                           (isOp ? Colors.accentBlue : (isClear ? Colors.error : Colors.card)) : 
                           (isOp ? Qt.rgba(Colors.accentBlue.r, Colors.accentBlue.g, Colors.accentBlue.b, 0.2) : 
                           (isClear ? Qt.rgba(Colors.error.r, Colors.error.g, Colors.error.b, 0.2) : "transparent"))
                    // Мгновенный hover, без анимации

                    StyledText {
                        anchors.centerIn: parent
                        text: modelData
                        color: btnMouse.containsMouse && (isOp || isClear) ? Colors.bg : Colors.textMain
                        font.pixelSize: 18
                        font.bold: true
                        // Мгновенный hover, без анимации
                    }

                    MouseArea {
                        id: btnMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: calcLogic.press(modelData)
                    }
                }
            }
        }
    }

    // Логика вычислений
    QtObject {
        id: calcLogic
        property string expression: ""
        
        function press(btn) {
            if (expression === "Error" || expression === "NaN" || expression === "Infinity") expression = "";

            if (btn === "C") {
                expression = "";
            } else if (btn === "⌫") {
                expression = expression.slice(0, -1);
            } else if (btn === "=") {
                if (expression.trim() === "") return;
                try {
                    let safeExpr = expression.replace(/×/g, "*").replace(/÷/g, "/");
                    let res = Function("return " + safeExpr)();
                    if (res !== undefined && res !== null) {
                        // Срезаем ошибки плавающей точки (например, 0.1 + 0.2)
                        expression = Math.round(res * 100000000) / 100000000 + "";
                    }
                } catch(e) {
                    expression = "Error";
                }
            } else {
                expression += btn;
            }
        }
    }
}