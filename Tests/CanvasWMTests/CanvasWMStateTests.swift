import Foundation
import AppKit
import CanvasWMLib

func runCanvasWMStateTests() {
    // MARK: - Window CRUD

    // addWindow creates a managed window
    do {
        let state = CanvasWMState()
        let id = state.addWindow(x: 100, y: 200, windowId: 42, pid: 123, ownerName: "Finder", title: "Downloads", width: 800, height: 600)
        assert(state.windows.count == 1, "addWindow creates one")
        let win = state.windows[id]!
        assertEqualDouble(win.x, 100, message: "addWindow x")
        assertEqualDouble(win.y, 200, message: "addWindow y")
        assertEqualDouble(win.width, 800, message: "addWindow width")
        assertEqualDouble(win.height, 600, message: "addWindow height")
        assert(win.ownerName == "Finder", "addWindow ownerName")
        assert(win.windowTitle == "Downloads", "addWindow title")
    }

    // moveWindow
    do {
        let state = CanvasWMState()
        let id = state.addWindow(x: 0, y: 0, windowId: 1, pid: 1, ownerName: "A", title: "", width: 100, height: 100)
        state.moveWindow(id: id, x: 500, y: 600)
        assertEqualDouble(state.windows[id]!.x, 500, message: "moveWindow x")
        assertEqualDouble(state.windows[id]!.y, 600, message: "moveWindow y")
    }

    // resizeWindow clamps minimum
    do {
        let state = CanvasWMState()
        let id = state.addWindow(x: 0, y: 0, windowId: 1, pid: 1, ownerName: "A", title: "", width: 100, height: 100)
        state.resizeWindow(id: id, width: 50, height: 50)
        assertEqualDouble(state.windows[id]!.width, 200, message: "resizeWindow clamp min width")
        assertEqualDouble(state.windows[id]!.height, 150, message: "resizeWindow clamp min height")
    }

    // removeWindow
    do {
        let state = CanvasWMState()
        let id = state.addWindow(x: 0, y: 0, windowId: 1, pid: 1, ownerName: "A", title: "", width: 100, height: 100)
        state.selectedWindowId = id
        state.removeWindow(id: id)
        assert(state.windows.isEmpty, "removeWindow removes")
        assert(state.selectedWindowId == nil, "removeWindow clears selection")
    }

    // bringToFront
    do {
        let state = CanvasWMState()
        let id1 = state.addWindow(x: 0, y: 0, windowId: 1, pid: 1, ownerName: "A", title: "", width: 100, height: 100)
        let id2 = state.addWindow(x: 0, y: 0, windowId: 2, pid: 2, ownerName: "B", title: "", width: 100, height: 100)
        state.bringToFront(id: id1)
        assert(state.windows[id1]!.zIndex > state.windows[id2]!.zIndex, "bringToFront increases z")
        assert(state.selectedWindowId == id1, "bringToFront selects")
    }

    // MARK: - screenRect

    do {
        let state = CanvasWMState()
        state.viewportX = 100; state.viewportY = 50
        let win = ManagedWindow(x: 200, y: 150, width: 800, height: 600, ownerName: "Test", windowTitle: "Win")
        let r = state.screenRect(for: win, screenSize: (w: 1920, h: 1080))
        assertEqualDouble(r.x, 100, message: "screenRect x = win.x - viewportX")
        assertEqualDouble(r.y, 100, message: "screenRect y = win.y - viewportY")
        assertEqualDouble(r.w, 800, message: "screenRect w")
        assertEqualDouble(r.h, 600, message: "screenRect h")
    }

    // MARK: - isVisible

    do {
        let state = CanvasWMState()
        state.viewportX = 0; state.viewportY = 0
        let screenSize = (w: 1920.0, h: 1080.0)

        // Window fully inside viewport
        let inside = ManagedWindow(x: 100, y: 100, width: 400, height: 300, ownerName: "A", windowTitle: "")
        assert(state.isVisible(inside, screenSize: screenSize), "window inside is visible")

        // Window far away
        let farAway = ManagedWindow(x: 5000, y: 5000, width: 400, height: 300, ownerName: "B", windowTitle: "")
        assert(!state.isVisible(farAway, screenSize: screenSize), "window far away is not visible")

        // Window partially overlapping (edge case with 100px margin)
        let partial = ManagedWindow(x: -450, y: 0, width: 400, height: 300, ownerName: "C", windowTitle: "")
        assert(state.isVisible(partial, screenSize: screenSize), "window within 100px margin is visible")

        let justOutside = ManagedWindow(x: -600, y: 0, width: 400, height: 300, ownerName: "D", windowTitle: "")
        assert(!state.isVisible(justOutside, screenSize: screenSize), "window beyond margin is not visible")
    }

    // MARK: - centerViewport

    do {
        let state = CanvasWMState()
        let win = ManagedWindow(x: 500, y: 300, width: 400, height: 200, ownerName: "A", windowTitle: "")
        let screenSize = (w: 1920.0, h: 1080.0)
        state.centerViewport(on: win, screenSize: screenSize)
        // expected: viewportX = 500 + 200 - 960 = -260, viewportY = 300 + 100 - 540 = -140
        // centerViewport now animates — verify the animation target values
        if case .animating(_, _, let toX, let toY, _, _) = state.viewport {
            assertEqualDouble(Double(toX), -260, message: "centerViewport x")
            assertEqualDouble(Double(toY), -140, message: "centerViewport y")
        } else {
            assert(false, "centerViewport should produce .animating state")
        }
    }

    // MARK: - Highlight

    do {
        let state = CanvasWMState()
        _ = state.addWindow(x: 0, y: 0, windowId: 1, pid: 1, ownerName: "Safari", title: "Google", width: 100, height: 100)
        _ = state.addWindow(x: 0, y: 0, windowId: 2, pid: 2, ownerName: "iTerm2", title: "bash", width: 100, height: 100)
        _ = state.addWindow(x: 0, y: 0, windowId: 3, pid: 3, ownerName: "Safari", title: "GitHub", width: 100, height: 100)

        state.highlightWindows(ownerName: "Safari")
        assert(state.highlightedWindowIds.count == 2, "highlight matches 2 Safari windows")

        state.clearHighlights()
        assert(state.highlightedWindowIds.isEmpty, "clearHighlights")
    }

    // Case-insensitive highlight
    do {
        let state = CanvasWMState()
        _ = state.addWindow(x: 0, y: 0, windowId: 1, pid: 1, ownerName: "iTerm2", title: "", width: 100, height: 100)
        state.highlightWindows(ownerName: "iterm2")
        assert(state.highlightedWindowIds.count == 1, "case-insensitive highlight")
    }

    // MARK: - ManagedWindow.displayName

    do {
        let w1 = ManagedWindow(x: 0, y: 0, ownerName: "Finder", windowTitle: "Downloads")
        assert(w1.displayName == "Downloads", "displayName prefers windowTitle")

        let w2 = ManagedWindow(x: 0, y: 0, ownerName: "Finder", windowTitle: "")
        assert(w2.displayName == "Finder", "displayName falls back to ownerName")

        let w3 = ManagedWindow(x: 0, y: 0, ownerName: "", windowTitle: "")
        assert(w3.displayName == "Window", "displayName falls back to Window")
    }

    // MARK: - sortedWindows

    do {
        let state = CanvasWMState()
        let id1 = state.addWindow(x: 0, y: 0, windowId: 1, pid: 1, ownerName: "A", title: "", width: 100, height: 100)
        _ = state.addWindow(x: 0, y: 0, windowId: 2, pid: 2, ownerName: "B", title: "", width: 100, height: 100)
        _ = state.addWindow(x: 0, y: 0, windowId: 3, pid: 3, ownerName: "C", title: "", width: 100, height: 100)
        state.bringToFront(id: id1) // id1 now has highest z

        let sorted = state.sortedWindows
        assert(sorted.count == 3, "sortedWindows count")
        assert(sorted.last!.id == id1, "sortedWindows last is brought-to-front window")
    }

    // MARK: - BookmarkedArea

    do {
        let state = CanvasWMState()
        state.viewportX = 500; state.viewportY = -300; state.scale = 2.0
        state.addBookmarkedArea(name: "Spot")
        assert(state.bookmarkedAreas.count == 1, "addBookmarkedArea")
        let id = state.bookmarkedAreas.keys.first!
        assertEqualDouble(state.bookmarkedAreas[id]!.panX, 500, message: "bookmark captures viewportX")
        assertEqualDouble(state.bookmarkedAreas[id]!.panY, -300, message: "bookmark captures viewportY")

        state.renameBookmarkedArea(id: id, name: "Renamed")
        assert(state.bookmarkedAreas[id]!.name == "Renamed", "renameBookmarkedArea")

        state.deleteBookmarkedArea(id: id)
        assert(state.bookmarkedAreas.isEmpty, "deleteBookmarkedArea")
    }

    print("CanvasWMState Tests: \(_passes) passed, \(_failures) failed")
}
