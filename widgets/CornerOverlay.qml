import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland

Item {
    id: root
    
    property int cornerMode: 0
    property int cornerRadius: 16 // Эстетичный радиус скругления, как в end4 / caestrelia
    
    // 1. Левый верхний угол (Top-Left)
    PanelWindow {
        implicitWidth: root.cornerRadius
        implicitHeight: root.cornerRadius
        anchors { top: true; left: true }
        color: "transparent"
        visible: root.cornerMode > 0
        exclusionMode: ExclusionMode.Ignore
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-corners"
        
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: 0
                fillColor: "#000000" // Чистый черный, идеальный для краев экрана
                startX: 0; startY: 0
                PathLine { x: root.cornerRadius; y: 0 }
                PathArc {
                    x: 0; y: root.cornerRadius
                    radiusX: root.cornerRadius; radiusY: root.cornerRadius
                    direction: PathArc.Counterclockwise
                    useLargeArc: false
                }
                PathLine { x: 0; y: 0 }
            }
        }
    }
    
    // 2. Правый верхний угол (Top-Right)
    PanelWindow {
        implicitWidth: root.cornerRadius
        implicitHeight: root.cornerRadius
        anchors { top: true; right: true }
        color: "transparent"
        visible: root.cornerMode > 0
        exclusionMode: ExclusionMode.Ignore
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-corners"
        
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: 0
                fillColor: "#000000"
                startX: root.cornerRadius; startY: 0
                PathLine { x: 0; y: 0 }
                PathArc {
                    x: root.cornerRadius; y: root.cornerRadius
                    radiusX: root.cornerRadius; radiusY: root.cornerRadius
                    direction: PathArc.Clockwise
                    useLargeArc: false
                }
                PathLine { x: root.cornerRadius; y: 0 }
            }
        }
    }
    
    // 3. Левый нижний угол (Bottom-Left)
    PanelWindow {
        implicitWidth: root.cornerRadius
        implicitHeight: root.cornerRadius
        anchors { bottom: true; left: true }
        color: "transparent"
        visible: root.cornerMode === 2
        exclusionMode: ExclusionMode.Ignore
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-corners"
        
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: 0
                fillColor: "#000000"
                startX: 0; startY: root.cornerRadius
                PathLine { x: root.cornerRadius; y: root.cornerRadius }
                PathArc {
                    x: 0; y: 0
                    radiusX: root.cornerRadius; radiusY: root.cornerRadius
                    direction: PathArc.Clockwise
                    useLargeArc: false
                }
                PathLine { x: 0; y: root.cornerRadius }
            }
        }
    }
    
    // 4. Правый нижний угол (Bottom-Right)
    PanelWindow {
        implicitWidth: root.cornerRadius
        implicitHeight: root.cornerRadius
        anchors { bottom: true; right: true }
        color: "transparent"
        visible: root.cornerMode === 2
        exclusionMode: ExclusionMode.Ignore
        
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "qs-corners"
        
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeWidth: 0
                fillColor: "#000000"
                startX: root.cornerRadius; startY: root.cornerRadius
                PathLine { x: 0; y: root.cornerRadius }
                PathArc {
                    x: root.cornerRadius; y: 0
                    radiusX: root.cornerRadius; radiusY: root.cornerRadius
                    direction: PathArc.Counterclockwise
                    useLargeArc: false
                }
                PathLine { x: root.cornerRadius; y: root.cornerRadius }
            }
        }
    }
}
