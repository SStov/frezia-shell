import QtQuick

Rectangle {
    id: root
    
    property color borderColor: Colors.outline
    property real borderWidth: 2
    property real wobbleAmount: 1.5
    
    color: "transparent"
    
    property real randomSeed: Math.random() * 100
    
    Canvas {
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            
            var w = width
            var h = height
            var r = Math.min(root.radius, w/2, h/2)
            var bw = root.borderWidth
            
            ctx.strokeStyle = root.borderColor
            ctx.lineWidth = bw
            ctx.lineCap = "round"
            ctx.lineJoin = "round"
            
            // Функция для получения точки с дрожанием
            function point(x, y) {
                var wx = x + (Math.random() - 0.5) * wobbleAmount
                var wy = y + (Math.random() - 0.5) * wobbleAmount
                return {x: wx, y: wy}
            }
            
            // Рисуем один непрерывный путь
            ctx.beginPath()
            
            // Начинаем с левого верха (после угла)
            var p = point(r, 0)
            ctx.moveTo(p.x, p.y)
            
            // Верхняя линия
            p = point(w - r, 0)
            ctx.lineTo(p.x, p.y)
            
            // Правый верхний угол - квадратичная кривая Безье
            var cp1 = point(w - r/2, 0)
            var cp2 = point(w, r/2)
            var end = point(w, r)
            ctx.bezierCurveTo(cp1.x, cp1.y, cp2.x, cp2.y, end.x, end.y)
            
            // Правая линия
            p = point(w, h - r)
            ctx.lineTo(p.x, p.y)
            
            // Правый нижний угол
            cp1 = point(w, h - r/2)
            cp2 = point(w - r/2, h)
            end = point(w - r, h)
            ctx.bezierCurveTo(cp1.x, cp1.y, cp2.x, cp2.y, end.x, end.y)
            
            // Нижняя линия
            p = point(r, h)
            ctx.lineTo(p.x, p.y)
            
            // Левый нижний угол
            cp1 = point(r/2, h)
            cp2 = point(0, h - r/2)
            end = point(0, h - r)
            ctx.bezierCurveTo(cp1.x, cp1.y, cp2.x, cp2.y, end.x, end.y)
            
            // Левая линия
            p = point(0, r)
            ctx.lineTo(p.x, p.y)
            
            // Левый верхний угол
            cp1 = point(0, r/2)
            cp2 = point(r/2, 0)
            end = point(r, 0)
            ctx.bezierCurveTo(cp1.x, cp1.y, cp2.x, cp2.y, end.x, end.y)
            
            ctx.closePath()
            ctx.stroke()
        }
    }
}
