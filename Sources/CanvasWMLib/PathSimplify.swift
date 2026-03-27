import Foundation

public enum PathSimplify {
    public static func simplify(_ points: [DrawingPoint], tolerance: Double) -> [DrawingPoint] {
        guard points.count > 2 else { return points }
        var result = [DrawingPoint]()
        douglasPeucker(points: points, startIndex: 0, endIndex: points.count - 1, tolerance: tolerance, result: &result)
        result.append(points[points.count - 1])
        return result
    }

    private static func douglasPeucker(points: [DrawingPoint], startIndex: Int, endIndex: Int, tolerance: Double, result: inout [DrawingPoint]) {
        var maxDist: Double = 0
        var maxIndex = startIndex
        let start = points[startIndex]
        let end = points[endIndex]

        for i in (startIndex + 1)..<endIndex {
            let dist = perpendicularDistance(point: points[i], lineStart: start, lineEnd: end)
            if dist > maxDist { maxDist = dist; maxIndex = i }
        }

        if maxDist > tolerance {
            douglasPeucker(points: points, startIndex: startIndex, endIndex: maxIndex, tolerance: tolerance, result: &result)
            douglasPeucker(points: points, startIndex: maxIndex, endIndex: endIndex, tolerance: tolerance, result: &result)
        } else {
            result.append(start)
        }
    }

    private static func perpendicularDistance(point: DrawingPoint, lineStart: DrawingPoint, lineEnd: DrawingPoint) -> Double {
        let dx = lineEnd.x - lineStart.x
        let dy = lineEnd.y - lineStart.y
        let lengthSq = dx * dx + dy * dy
        guard lengthSq > 0 else {
            let px = point.x - lineStart.x; let py = point.y - lineStart.y
            return (px * px + py * py).squareRoot()
        }
        let t = max(0, min(1, ((point.x - lineStart.x) * dx + (point.y - lineStart.y) * dy) / lengthSq))
        let projX = lineStart.x + t * dx
        let projY = lineStart.y + t * dy
        let px = point.x - projX; let py = point.y - projY
        return (px * px + py * py).squareRoot()
    }
}
