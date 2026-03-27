import Foundation
@testable import CanvasWMLib

func runPathSimplifyTests() {
    // Empty / single / two points returned as-is
    do {
        let empty: [DrawingPoint] = []
        let result = PathSimplify.simplify(empty, tolerance: 1.0)
        assert(result.isEmpty, "simplify empty array")
    }

    do {
        let single = [DrawingPoint(x: 5, y: 10)]
        let result = PathSimplify.simplify(single, tolerance: 1.0)
        assert(result.count == 1, "simplify single point")
        assertEqualDouble(result[0].x, 5, message: "single point x")
    }

    do {
        let two = [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 10, y: 10)]
        let result = PathSimplify.simplify(two, tolerance: 1.0)
        assert(result.count == 2, "simplify two points")
    }

    // Collinear points: middle points removed
    do {
        let points = (0...10).map { DrawingPoint(x: Double($0) * 10, y: Double($0) * 10) }
        let result = PathSimplify.simplify(points, tolerance: 0.1)
        assert(result.count == 2, "collinear points simplified to 2 — got \(result.count)")
        assertEqualDouble(result.first!.x, 0, message: "collinear first x")
        assertEqualDouble(result.last!.x, 100, message: "collinear last x")
    }

    // Points with significant deviation are kept
    do {
        let points = [
            DrawingPoint(x: 0, y: 0),
            DrawingPoint(x: 50, y: 100), // big deviation from line (0,0)→(100,0)
            DrawingPoint(x: 100, y: 0),
        ]
        let result = PathSimplify.simplify(points, tolerance: 1.0)
        assert(result.count == 3, "deviated point kept — got \(result.count)")
    }

    // High tolerance simplifies more aggressively
    do {
        let points = [
            DrawingPoint(x: 0, y: 0),
            DrawingPoint(x: 50, y: 5), // small deviation
            DrawingPoint(x: 100, y: 0),
        ]
        let lowTol = PathSimplify.simplify(points, tolerance: 1.0)
        let highTol = PathSimplify.simplify(points, tolerance: 10.0)
        assert(lowTol.count >= highTol.count, "higher tolerance => fewer or equal points")
    }

    // Result always includes first and last points
    do {
        let points = [
            DrawingPoint(x: 0, y: 0),
            DrawingPoint(x: 25, y: 3),
            DrawingPoint(x: 50, y: 50),
            DrawingPoint(x: 75, y: 3),
            DrawingPoint(x: 100, y: 0),
        ]
        let result = PathSimplify.simplify(points, tolerance: 2.0)
        assertEqualDouble(result.first!.x, 0, message: "first point preserved x")
        assertEqualDouble(result.first!.y, 0, message: "first point preserved y")
        assertEqualDouble(result.last!.x, 100, message: "last point preserved x")
        assertEqualDouble(result.last!.y, 0, message: "last point preserved y")
    }

    print("PathSimplify Tests: \(_passes) passed, \(_failures) failed")
}
