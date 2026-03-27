import Foundation

public enum ViewportMath {
    public static let minScale: Double = 0.1
    public static let maxScale: Double = 5.0
    public static let zoomStep: Double = 0.05

    public static func screenToWorld(
        screenX: Double, screenY: Double,
        panX: Double, panY: Double, scale: Double
    ) -> (worldX: Double, worldY: Double) {
        ((screenX - panX) / scale, (screenY - panY) / scale)
    }

    public static func worldToScreen(
        worldX: Double, worldY: Double,
        panX: Double, panY: Double, scale: Double
    ) -> (screenX: Double, screenY: Double) {
        (worldX * scale + panX, worldY * scale + panY)
    }

    public static func zoomAtPoint(
        currentScale: Double, delta: Double,
        pointX: Double, pointY: Double,
        panX: Double, panY: Double
    ) -> (newScale: Double, newPanX: Double, newPanY: Double) {
        let newScale = clampScale(currentScale + delta)
        let scaleRatio = newScale / currentScale
        return (newScale, pointX - (pointX - panX) * scaleRatio, pointY - (pointY - panY) * scaleRatio)
    }

    public static func clampScale(_ scale: Double) -> Double {
        min(max(scale, minScale), maxScale)
    }
}
