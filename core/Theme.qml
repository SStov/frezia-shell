pragma Singleton
import QtQuick

QtObject {
    id: theme

    // Эти значения будут меняться извне через quickshell ipc
    property color rootBg: '#dfdfe0'
    property color bg: "#1e1e2e"
    property color card: "#313244"
    property color textMain: "#cdd6f4"
    property color textSub: "#a6adc8"
    property color accentBlue: "#89b4fa"
    property color accentPurple: "#cba6f7"
    
    // Чтобы анимация была плавной, добавим поведение прямо сюда
    Behavior on rootBg { ColorAnimation { duration: 400 } }
    Behavior on bg { ColorAnimation { duration: 400 } }
    Behavior on accentBlue { ColorAnimation { duration: 400 } }

    property int borderWidth: 1

    // Глобальный шрифт для всех виджетов Quickshell
    // Изменение этого свойства мгновенно обновляет все тексты
    property string fontFamily: "sans-serif"
}
