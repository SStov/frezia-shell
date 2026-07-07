import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../core"
import "../components"

Item {
    id: root

    property bool isOpen: false
    property real maxW: 370
    property real maxH: 570
    property bool animatingOut: false
    property real bgOpacity: shellRoot ? shellRoot.qsOpacity : 0.95
    property int activeTab: 0

    width: maxW
    height: maxH

    // ── Блок-карточка с каскадной анимацией (паттерн NotificationCenter) ──
    component BlockCard: Rectangle {
        id: card
        width: parent ? parent.width : 346
        radius: 16
        color: Colors.rootBg
        border.color: Colors.outlineVariant
        border.width: 1

        property int slideDelay: 0
        property real slideY: -root.maxH

        transform: Translate { y: card.slideY }

        // Каскадная анимация открытия: выезд сверху вниз
        SequentialAnimation {
            id: slideInAnim
            running: false
            PauseAnimation { duration: card.slideDelay }
            NumberAnimation {
                target: card
                property: "slideY"
                from: -root.maxH
                to: 0
                duration: 380
                easing.type: Easing.OutCubic
            }
        }

        // Каскадная анимация закрытия: уезд вверх
        SequentialAnimation {
            id: slideOutAnim
            running: false
            PauseAnimation { duration: Math.max(0, 150 - card.slideDelay) }
            NumberAnimation {
                target: card
                property: "slideY"
                to: -root.maxH
                duration: 320
                easing.type: Easing.InCubic
            }
        }

        function triggerOpen()  { slideOutAnim.stop(); slideInAnim.start()  }
        function triggerClose() { slideInAnim.stop();  slideOutAnim.start() }
    }

    // ══════════════════════════════════════════════════
    // БЭКЕНД ЗАДАЧ (Rust)
    // ══════════════════════════════════════════════════
    Process {
        id: initTodoData
        command: ["bash", "-c", "if [ ! -f /tmp/TodoData.qml ]; then cp /home/stul/.config/quickshell/widgets/TodoData.qml /tmp/TodoData.qml; fi"]
        onExited: dataLoader.reload()
    }

    Loader {
        id: dataLoader
        Component.onCompleted: initTodoData.running = true
        function reload() { source = "file:///tmp/TodoData.qml?t=" + new Date().getTime() }
    }

    Process {
        id: rustBackend
        function run(act, a) {
            let cmd = ["/home/stul/.config/quickshell/todo_backend", act]
            if (a !== undefined && a !== "") cmd.push(a.toString())
            command = cmd
            running = true
        }
        onExited: { running = false; dataLoader.reload() }
    }

    Timer {
        id: focusTimer
        interval: 120
        onTriggered: taskInput.forceActiveFocus()
    }

    onActiveTabChanged: {
        if (activeTab === 1) { dataLoader.reload(); focusTimer.start() }
        else { taskInput.focus = false }
    }

    readonly property int totalTasks: dataLoader.item ? dataLoader.item.count : 0
    readonly property int pendingTasks: {
        if (!dataLoader.item) return 0
        let count = 0
        for (let i = 0; i < dataLoader.item.count; i++) {
            let item = dataLoader.item.get(i)
            if (item && !item.isDone) count++
        }
        return count
    }
    readonly property int doneTasks: {
        if (!dataLoader.item) return 0
        let count = 0
        for (let i = 0; i < dataLoader.item.count; i++) {
            let item = dataLoader.item.get(i)
            if (item && item.isDone) count++
        }
        return count
    }

    // ══════════════════════════════════════════════════
    // ЛОГИКА КАЛЕНДАРЯ И ВРЕМЕНИ
    // ══════════════════════════════════════════════════
    property date liveTime: new Date()
    Timer {
        interval: 1000
        running: root.isOpen
        repeat: true
        onTriggered: root.liveTime = new Date()
    }

    readonly property date todayDate: new Date()
    property int todayDay: todayDate.getDate()
    property int todayMonth: todayDate.getMonth()
    property int todayYear: todayDate.getFullYear()

    property int currentMonth: todayMonth
    property int currentYear: todayYear
    property int selectedDay: todayDay

    function daysInMonth(month, year) { return new Date(year, month + 1, 0).getDate() }
    function startDayOfWeek(month, year) {
        let d = new Date(year, month, 1).getDay()
        return d === 0 ? 6 : d - 1
    }
    function prevMonthDays(month, year) {
        let m = month === 0 ? 11 : month - 1
        let y = month === 0 ? year - 1 : year
        return daysInMonth(m, y)
    }

    readonly property var monthNames: [
        "Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
        "Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
    ]
    readonly property var dayOfWeekNames: [
        "Воскресенье", "Понедельник", "Вторник", "Среда",
        "Четверг", "Пятница", "Суббота"
    ]

    function prevMonth() {
        if (currentMonth === 0) { currentMonth = 11; currentYear-- }
        else { currentMonth-- }
    }
    function nextMonth() {
        if (currentMonth === 11) { currentMonth = 0; currentYear++ }
        else { currentMonth++ }
    }

    readonly property bool isCurrentMonth:
        currentMonth === todayMonth && currentYear === todayYear

    // ══════════════════════════════════════════════════
    // РАЗМЕТКА: КОЛОНКА ИЗ НЕЗАВИСИМЫХ БЛОКОВ
    // ══════════════════════════════════════════════════
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        // ── БЛОК 1: ВКЛАДКИ ─────────────────────────────
        BlockCard {
            id: blockTabs
            slideDelay: 0
            Layout.fillWidth: true
            Layout.preferredHeight: 48

            RowLayout {
                anchors.fill: parent
                anchors.margins: 4
                spacing: 4

                Rectangle {
                    id: tabIndicator
                    height: parent.height
                    radius: 12
                    width: (parent.width - parent.spacing) / 2
                    color: Colors.card
                    border.color: Colors.accentBlue
                    border.width: 1

                    Behavior on x {
                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                    }
                    x: root.activeTab === 0 ? 0 : (width + parent.spacing)
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: "transparent"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        StyledText {
                            text: ""
                            color: root.activeTab === 0 ? Colors.accentBlue : Colors.textSub
                            font.pixelSize: 14
                        }
                        StyledText {
                            text: "Календарь"
                            color: root.activeTab === 0 ? Colors.textMain : Colors.textSub
                            font.pixelSize: 13
                            font.bold: root.activeTab === 0
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = 0
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 12
                    color: "transparent"

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        StyledText {
                            text: ""
                            color: root.activeTab === 1 ? Colors.accentBlue : Colors.textSub
                            font.pixelSize: 14
                        }
                        StyledText {
                            text: "Задачи"
                            color: root.activeTab === 1 ? Colors.textMain : Colors.textSub
                            font.pixelSize: 13
                            font.bold: root.activeTab === 1
                        }
                        Rectangle {
                            visible: root.pendingTasks > 0
                            implicitWidth: badgeText.implicitWidth + 10
                            implicitHeight: 18
                            radius: 9
                            color: root.activeTab === 1 ? Colors.accentBlue : Colors.card
                            StyledText {
                                id: badgeText
                                anchors.centerIn: parent
                                text: root.pendingTasks
                                color: root.activeTab === 1 ? Colors.bg : Colors.textMain
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.activeTab = 1
                    }
                }
            }
        }

        // ── БЛОК 2: ПОГОДА И ЧАСЫ ───────────────────────
        BlockCard {
            id: blockWeather
            slideDelay: 50
            Layout.fillWidth: true
            Layout.preferredHeight: 76
            visible: root.activeTab === 0

            RowLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 12

                Rectangle {
                    implicitWidth: 46
                    implicitHeight: 46
                    radius: 12
                    color: Colors.card
                    border.color: Colors.outlineVariant
                    border.width: 1
                    StyledText {
                        anchors.centerIn: parent
                        text: "☀️"
                        font.pixelSize: 24
                    }
                }

                ColumnLayout {
                    spacing: 1
                    RowLayout {
                        spacing: 6
                        StyledText {
                            text: "22°C"
                            color: Colors.accentBlue
                            font.pixelSize: 20
                            font.bold: true
                        }
                        Rectangle {
                            implicitWidth: 40
                            implicitHeight: 18
                            radius: 9
                            color: Colors.card
                            StyledText {
                                anchors.centerIn: parent
                                text: "Ясно"
                                color: Colors.textSub
                                font.pixelSize: 10
                                font.bold: true
                            }
                        }
                    }
                    StyledText {
                        text: "Прекрасная погода"
                        color: Colors.textSub
                        font.pixelSize: 11
                    }
                }

                Item { Layout.fillWidth: true }

                ColumnLayout {
                    spacing: 1
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    StyledText {
                        text: Qt.formatDateTime(root.liveTime, "hh:mm")
                        color: Colors.textMain
                        font.pixelSize: 22
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                    StyledText {
                        text: root.dayOfWeekNames[root.todayDate.getDay()] + ", " + root.todayDay
                        color: Colors.accentPurple
                        font.pixelSize: 11
                        font.bold: true
                        horizontalAlignment: Text.AlignRight
                        Layout.alignment: Qt.AlignRight
                    }
                }
            }
        }

        // ── БЛОК 3: СЕТКА КАЛЕНДАРЯ ─────────────────────
        BlockCard {
            id: blockCalendar
            slideDelay: 100
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeTab === 0
            clip: true

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                // Навигация по месяцу
                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 17
                        color: btnPrevM.containsMouse ? Colors.card : "transparent"
                        StyledText {
                            anchors.centerIn: parent
                            text: ""
                            color: Colors.textMain
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: btnPrevM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.prevMonth()
                        }
                    }

                    StyledText {
                        text: root.monthNames[root.currentMonth] + " " + root.currentYear
                        color: Colors.textMain
                        font.pixelSize: 15
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        visible: !root.isCurrentMonth
                        implicitWidth: 28
                        implicitHeight: 28
                        radius: 14
                        color: Colors.accentBlue
                        StyledText {
                            anchors.centerIn: parent
                            text: "🎯"
                            font.pixelSize: 12
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.currentMonth = root.todayMonth
                                root.currentYear = root.todayYear
                            }
                        }
                    }

                    Rectangle {
                        implicitWidth: 34
                        implicitHeight: 34
                        radius: 17
                        color: btnNextM.containsMouse ? Colors.card : "transparent"
                        StyledText {
                            anchors.centerIn: parent
                            text: ""
                            color: Colors.textMain
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: btnNextM
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.nextMonth()
                        }
                    }
                }

                // Дни недели
                GridLayout {
                    Layout.fillWidth: true
                    columns: 7
                    columnSpacing: 4
                    Repeater {
                        model: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]
                        StyledText {
                            text: modelData
                            color: (index === 5 || index === 6) ? Colors.accentPurple : Colors.textSub
                            font.pixelSize: 12
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            Layout.fillWidth: true
                        }
                    }
                }

                // Сетка дней
                GridLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    columns: 7
                    rowSpacing: 4
                    columnSpacing: 4

                    Repeater {
                        model: 42
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            implicitHeight: 36
                            radius: 50

                            readonly property int firstDayIndex:
                                root.startDayOfWeek(root.currentMonth, root.currentYear)
                            readonly property int totalDaysCurrent:
                                root.daysInMonth(root.currentMonth, root.currentYear)
                            readonly property int totalDaysPrev:
                                root.prevMonthDays(root.currentMonth, root.currentYear)

                            readonly property int cellType: {
                                if (index < firstDayIndex) return -1
                                if (index >= firstDayIndex + totalDaysCurrent) return 1
                                return 0
                            }

                            readonly property int dayNumber: {
                                if (cellType === -1)
                                    return totalDaysPrev - (firstDayIndex - 1 - index)
                                if (cellType === 1)
                                    return index - (firstDayIndex + totalDaysCurrent) + 1
                                return index - firstDayIndex + 1
                            }

                            readonly property bool isToday:
                                cellType === 0
                                && dayNumber === root.todayDay
                                && root.isCurrentMonth
                            readonly property bool isSelected:
                                cellType === 0
                                && dayNumber === root.selectedDay
                                && !isToday

                            color: {
                                if (isToday) return Colors.accentBlue
                                if (isSelected) return Colors.card
                                if (cellMouse.containsMouse && cellType === 0)
                                    return Colors.card
                                return "transparent"
                            }

                            border.color: isSelected ? Colors.accentBlue : "transparent"
                            border.width: isSelected ? 1 : 0

                            StyledText {
                                anchors.centerIn: parent
                                text: parent.dayNumber
                                color: {
                                    if (parent.isToday) return Colors.bg
                                    if (parent.cellType !== 0) return Colors.outline
                                    return Colors.textMain
                                }
                                font.pixelSize: 13
                                font.bold: parent.isToday || parent.isSelected
                            }

                            MouseArea {
                                id: cellMouse
                                anchors.fill: parent
                                hoverEnabled: parent.cellType === 0
                                cursorShape: parent.cellType === 0
                                    ? Qt.PointingHandCursor : Qt.ArrowCursor
                                onClicked: {
                                    if (parent.cellType === 0)
                                        root.selectedDay = parent.dayNumber
                                    else if (parent.cellType === -1)
                                        root.prevMonth()
                                    else if (parent.cellType === 1)
                                        root.nextMonth()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ── БЛОК 4: ЗАДАЧИ (Вкладка 1) ──────────────────
        BlockCard {
            id: blockTasks
            slideDelay: 50
            Layout.fillWidth: true
            Layout.fillHeight: true
            visible: root.activeTab === 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 10

                // Прогресс
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    StyledText {
                        text: "Прогресс дня"
                        color: Colors.textMain
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Item { Layout.fillWidth: true }
                    StyledText {
                        text: root.doneTasks + " / " + root.totalTasks
                        color: Colors.textSub
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    height: 5
                    radius: 2.5
                    color: Colors.card
                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        width: parent.width * (root.totalTasks > 0
                            ? (root.doneTasks / root.totalTasks) : 0)
                        color: Colors.accentBlue
                        Behavior on width {
                            NumberAnimation {
                                duration: 200
                                easing.type: Easing.OutCubic
                            }
                        }
                    }
                }

                // Поле ввода
                Rectangle {
                    Layout.fillWidth: true
                    height: 42
                    radius: 12
                    color: Colors.card
                    border.color: taskInput.activeFocus
                        ? Colors.accentBlue : Colors.outlineVariant
                    border.width: 1

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 10
                        anchors.rightMargin: 6
                        spacing: 8

                        Item {
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                text: taskInput.text === ""
                                    ? "Добавить новую задачу..." : ""
                                color: Colors.textSub
                                font.pixelSize: 13
                            }

                            StyledTextInput {
                                id: taskInput
                                anchors.fill: parent
                                verticalAlignment: TextInput.AlignVCenter
                                color: Colors.textMain
                                font.pixelSize: 13
                                selectionColor: Colors.accentBlue
                                selectedTextColor: Colors.bg
                                onAccepted: {
                                    if (text.trim() !== "") {
                                        rustBackend.run("add", text.trim())
                                        text = ""
                                    }
                                }
                            }
                        }

                        Rectangle {
                            implicitWidth: 30
                            implicitHeight: 30
                            radius: 8
                            color: btnAdd.containsMouse
                                ? Colors.accentBlue : Colors.rootBg
                            StyledText {
                                anchors.centerIn: parent
                                text: ""
                                color: btnAdd.containsMouse
                                    ? Colors.bg : Colors.accentBlue
                                font.pixelSize: 13
                            }
                            MouseArea {
                                id: btnAdd
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (taskInput.text.trim() !== "") {
                                        rustBackend.run("add",
                                            taskInput.text.trim())
                                        taskInput.text = ""
                                    }
                                }
                            }
                        }
                    }
                }

                // Список задач
                ListView {
                    id: taskList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 6
                    boundsBehavior: Flickable.StopAtBounds
                    model: dataLoader.item

                    Item {
                        anchors.centerIn: parent
                        visible: root.totalTasks === 0
                        ColumnLayout {
                            anchors.centerIn: parent
                            spacing: 4
                            StyledText {
                                text: "🎉"
                                font.pixelSize: 28
                                Layout.alignment: Qt.AlignHCenter
                            }
                            StyledText {
                                text: "Все задачи выполнены!"
                                color: Colors.textSub
                                font.pixelSize: 12
                                Layout.alignment: Qt.AlignHCenter
                            }
                        }
                    }

                    delegate: Rectangle {
                        width: taskList.width
                        height: 42
                        radius: 10
                        color: taskMouse.containsMouse
                            ? Colors.card : Colors.rootBg
                        border.color: Colors.outlineVariant
                        border.width: 1

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 8
                            spacing: 8

                            Rectangle {
                                implicitWidth: 20
                                implicitHeight: 20
                                radius: 10
                                color: model.isDone
                                    ? Colors.accentBlue : Colors.rootBg
                                border.color: model.isDone
                                    ? Colors.accentBlue : Colors.textSub
                                border.width: 1.5
                                StyledText {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: Colors.bg
                                    font.pixelSize: 10
                                    visible: model.isDone
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rustBackend.run("toggle", index)
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: model.taskText
                                color: model.isDone
                                    ? Colors.textSub : Colors.textMain
                                font.pixelSize: 13
                                font.strikeout: model.isDone
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: 24
                                implicitHeight: 24
                                radius: 6
                                color: delMouse.containsMouse
                                    ? Colors.error : "transparent"
                                StyledText {
                                    anchors.centerIn: parent
                                    text: ""
                                    color: delMouse.containsMouse
                                        ? Colors.bg : Colors.textSub
                                    font.pixelSize: 12
                                }
                                MouseArea {
                                    id: delMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: rustBackend.run("delete", index)
                                }
                            }
                        }

                        MouseArea {
                            id: taskMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            z: -1
                        }
                    }
                }
            }
        }
    }

    // ══════════════════════════════════════════════════
    // ЗАПУСК КАСКАДНОЙ АНИМАЦИИ
    // ══════════════════════════════════════════════════
    Timer {
        id: closeAnimTimer
        interval: 320
        onTriggered: root.animatingOut = false
    }

    onIsOpenChanged: {
        if (isOpen) {
            animatingOut = false
            closeAnimTimer.stop()
            blockTabs.triggerOpen()
            blockWeather.triggerOpen()
            blockCalendar.triggerOpen()
            blockTasks.triggerOpen()
        } else {
            animatingOut = true
            closeAnimTimer.start()
            blockTabs.triggerClose()
            blockWeather.triggerClose()
            blockCalendar.triggerClose()
            blockTasks.triggerClose()
        }
    }

    Component.onCompleted: {
        blockTabs.slideY = -root.maxH
        blockWeather.slideY = -root.maxH
        blockCalendar.slideY = -root.maxH
        blockTasks.slideY = -root.maxH
        root.isOpen = false
    }
}