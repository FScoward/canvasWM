// ViewportMath verification - runs as part of a test executable
// XCTest/Testing not available in Command Line Tools only environment

import Foundation
import CanvasWMLib

func assert(_ condition: Bool, _ message: String, file: String = #file, line: Int = #line) {
    if !condition {
        print("FAIL [\(file):\(line)] \(message)")
        _failures += 1
    } else {
        _passes += 1
    }
}

func assertEqualDouble(_ a: Double, _ b: Double, accuracy: Double = 0.0001, message: String = "", file: String = #file, line: Int = #line) {
    if abs(a - b) > accuracy {
        print("FAIL [\(file):\(line)] \(message) — expected \(b), got \(a)")
        _failures += 1
    } else {
        _passes += 1
    }
}

var _failures = 0
var _passes = 0

func runViewportMathTests() {
    // screenToWorld at default scale
    do {
        let r = ViewportMath.screenToWorld(screenX: 100, screenY: 200, panX: 0, panY: 0, scale: 1.0)
        assert(r.worldX == 100, "screenToWorld default scale X")
        assert(r.worldY == 200, "screenToWorld default scale Y")
    }

    // screenToWorld with pan
    do {
        let r = ViewportMath.screenToWorld(screenX: 150, screenY: 250, panX: 50, panY: 50, scale: 1.0)
        assert(r.worldX == 100, "screenToWorld with pan X")
        assert(r.worldY == 200, "screenToWorld with pan Y")
    }

    // screenToWorld with scale
    do {
        let r = ViewportMath.screenToWorld(screenX: 200, screenY: 400, panX: 0, panY: 0, scale: 2.0)
        assert(r.worldX == 100, "screenToWorld with scale X")
        assert(r.worldY == 200, "screenToWorld with scale Y")
    }

    // worldToScreen
    do {
        let r = ViewportMath.worldToScreen(worldX: 100, worldY: 200, panX: 50, panY: 50, scale: 2.0)
        assert(r.screenX == 250, "worldToScreen X")
        assert(r.screenY == 450, "worldToScreen Y")
    }

    // round trip
    do {
        let scale = 1.5, panX = 30.0, panY = -40.0, origX = 123.0, origY = 456.0
        let w = ViewportMath.screenToWorld(screenX: origX, screenY: origY, panX: panX, panY: panY, scale: scale)
        let s = ViewportMath.worldToScreen(worldX: w.worldX, worldY: w.worldY, panX: panX, panY: panY, scale: scale)
        assertEqualDouble(s.screenX, origX, message: "round trip X")
        assertEqualDouble(s.screenY, origY, message: "round trip Y")
    }

    // zoom clamp min
    do {
        let r = ViewportMath.zoomAtPoint(currentScale: 0.11, delta: -0.05, pointX: 100, pointY: 100, panX: 0, panY: 0)
        assert(r.newScale >= ViewportMath.minScale, "zoom clamp min")
    }

    // zoom clamp max
    do {
        let r = ViewportMath.zoomAtPoint(currentScale: 4.98, delta: 0.05, pointX: 100, pointY: 100, panX: 0, panY: 0)
        assert(r.newScale <= ViewportMath.maxScale, "zoom clamp max")
    }

    // zoom keeps point stable
    do {
        let pX = 200.0, pY = 300.0, panX = 50.0, panY = -20.0, cs = 1.0
        let before = ViewportMath.screenToWorld(screenX: pX, screenY: pY, panX: panX, panY: panY, scale: cs)
        let r = ViewportMath.zoomAtPoint(currentScale: cs, delta: 0.1, pointX: pX, pointY: pY, panX: panX, panY: panY)
        let after = ViewportMath.screenToWorld(screenX: pX, screenY: pY, panX: r.newPanX, panY: r.newPanY, scale: r.newScale)
        assertEqualDouble(before.worldX, after.worldX, message: "zoom stable X")
        assertEqualDouble(before.worldY, after.worldY, message: "zoom stable Y")
    }

    // clampScale
    do {
        assert(ViewportMath.clampScale(-1.0) == ViewportMath.minScale, "clamp min")
        assert(ViewportMath.clampScale(10.0) == ViewportMath.maxScale, "clamp max")
        assert(ViewportMath.clampScale(2.5) == 2.5, "clamp passthrough")
    }

    print("\nViewportMath Tests: \(_passes) passed, \(_failures) failed")
    if _failures > 0 {
        print("TESTS FAILED")
    } else {
        print("ALL TESTS PASSED ✓")
    }
}
