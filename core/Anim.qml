pragma Singleton
import QtQuick

QtObject {
    // Длительности (в миллисекундах)
    property int durationElastic: 250
    property int durationFast: 200
    property int durationHover: 100

    // Кривые анимации (Easings)
    // Easing.InCubic — начинается медленно, заканчивается быстро
    readonly property int easingElastic: Easing.InCubic
    readonly property int easingFast: Easing.InCubic
}