import Foundation
import AppKit
import Observation

// MARK: - Managed Window (real macOS window on the canvas)

public struct ManagedWindow: Codable, Identifiable {
    public let id: String
    public var x: Double          // world coordinates on infinite canvas
    public var y: Double
    public var width: Double
    public var height: Double
    public var windowId: UInt32?   // CGWindowID
    public var ownerPid: Int32?    // pid_t
    public var ownerName: String
    public var windowTitle: String
    public var zIndex: Int
    /// True when the window is alive but on a different macOS Space (virtual desktop).
    /// Canvas position is preserved while this flag is set; syncToScreen skips these windows.
    /// Runtime-only state — excluded from Codable.
    public var isOnOtherSpace: Bool

    private enum CodingKeys: String, CodingKey {
        case id, x, y, width, height, windowId, ownerPid, ownerName, windowTitle, zIndex
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        x = try c.decode(Double.self, forKey: .x)
        y = try c.decode(Double.self, forKey: .y)
        width = try c.decode(Double.self, forKey: .width)
        height = try c.decode(Double.self, forKey: .height)
        windowId = try c.decodeIfPresent(UInt32.self, forKey: .windowId)
        ownerPid = try c.decodeIfPresent(Int32.self, forKey: .ownerPid)
        ownerName = try c.decode(String.self, forKey: .ownerName)
        windowTitle = try c.decode(String.self, forKey: .windowTitle)
        zIndex = try c.decode(Int.self, forKey: .zIndex)
        isOnOtherSpace = false
    }

    public init(id: String = UUID().uuidString, x: Double, y: Double,
                width: Double = 960, height: Double = 640,
                windowId: UInt32? = nil, ownerPid: Int32? = nil,
                ownerName: String = "", windowTitle: String = "", zIndex: Int = 0,
                isOnOtherSpace: Bool = false) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.windowId = windowId; self.ownerPid = ownerPid
        self.ownerName = ownerName; self.windowTitle = windowTitle; self.zIndex = zIndex
        self.isOnOtherSpace = isOnOtherSpace
    }

    public var displayName: String {
        if !windowTitle.isEmpty { return windowTitle }
        if !ownerName.isEmpty { return ownerName }
        return "Window"
    }
}

// MARK: - Canvas WM State

@Observable
public final class CanvasWMState {
    // Canvas view (for overlay pan/zoom)
    public var scale: Double = 1.0
    public var panX: Double = 0
    public var panY: Double = 0

    // Monitor viewport position on canvas (what the physical monitor shows)
    public var viewportX: Double = 0
    public var viewportY: Double = 0

    // Managed windows on the canvas
    public var windows: [String: ManagedWindow] = [:]
    public var thumbnails: [String: NSImage] = [:]  // Window screenshots (not persisted)
    public var selectedWindowId: String? = nil
    public var nextZIndex: Int = 1

    // Notification highlight (windows that should glow)
    public var highlightedWindowIds: Set<String> = []

    // Frozen screen geometry captured at activation time (avoids NSScreen.main shifting)
    public var primaryScreenFrame: CGRect = .zero
    public var primaryVisibleFrame: CGRect = .zero
    /// Union of all connected screens — used to compute a hide position that is
    /// guaranteed to be outside every monitor (prevents clamping to sub-monitors).
    public var allScreensUnion: CGRect = .zero

    public func pinPrimaryScreen(_ screen: NSScreen) {
        primaryScreenFrame = screen.frame
        primaryVisibleFrame = screen.visibleFrame
        let screens = NSScreen.screens
        if let first = screens.first {
            allScreensUnion = screens.dropFirst().reduce(first.frame) { $0.union($1.frame) }
        }
    }

    /// Position far enough outside all monitors to hide a window without macOS
    /// clamping it onto a sub-monitor.
    public var offScreenHidePoint: CGPoint {
        if allScreensUnion.width > 0 {
            return CGPoint(x: allScreensUnion.maxX + 5000, y: allScreensUnion.maxY + 5000)
        }
        return CGPoint(x: 99999, y: 99999)
    }

    public init() {}

    // MARK: - Window management

    public func addWindow(x: Double, y: Double, windowId: UInt32, pid: Int32, ownerName: String, title: String, width: Double, height: Double) -> String {
        let id = UUID().uuidString
        windows[id] = ManagedWindow(id: id, x: x, y: y, width: width, height: height,
                                     windowId: windowId, ownerPid: pid,
                                     ownerName: ownerName, windowTitle: title, zIndex: nextZIndex)
        nextZIndex += 1
        return id
    }

    public func moveWindow(id: String, x: Double, y: Double) {
        windows[id]?.x = x
        windows[id]?.y = y
    }

    public func resizeWindow(id: String, width: Double, height: Double) {
        windows[id]?.width = max(width, 200)
        windows[id]?.height = max(height, 150)
    }

    public func removeWindow(id: String) {
        windows.removeValue(forKey: id)
        if selectedWindowId == id { selectedWindowId = nil }
    }

    public func bringToFront(id: String) {
        windows[id]?.zIndex = nextZIndex
        nextZIndex += 1
        selectedWindowId = id
    }

    // Screen position for a window based on monitor viewport (1:1 mapping)
    public func screenRect(for win: ManagedWindow, screenSize: (w: Double, h: Double)) -> (x: Double, y: Double, w: Double, h: Double) {
        let sx = win.x - viewportX
        let sy = win.y - viewportY
        return (sx, sy, win.width, win.height)
    }

    // Is window visible within the monitor viewport?
    public func isVisible(_ win: ManagedWindow, screenSize: (w: Double, h: Double)) -> Bool {
        let r = screenRect(for: win, screenSize: screenSize)
        return r.x + r.w > -100 && r.x < screenSize.w + 100 &&
               r.y + r.h > -100 && r.y < screenSize.h + 100
    }

    // Move viewport to center on a window
    public func centerViewport(on win: ManagedWindow, screenSize: (w: Double, h: Double)) {
        viewportX = win.x + win.width / 2 - screenSize.w / 2
        viewportY = win.y + win.height / 2 - screenSize.h / 2
    }

    /// Highlight windows matching the given app name (e.g. "iTerm2")
    public func highlightWindows(ownerName: String) {
        for (id, win) in windows where win.ownerName.localizedCaseInsensitiveContains(ownerName) {
            highlightedWindowIds.insert(id)
        }
    }

    /// Highlight a single window by CGWindowID
    public func highlightWindow(cgWindowId: UInt32) {
        for (id, win) in windows where win.windowId == cgWindowId {
            highlightedWindowIds.insert(id)
        }
    }

    /// Clear all highlights
    public func clearHighlights() {
        highlightedWindowIds.removeAll()
    }

    // MARK: - Bookmarked Areas

    public var bookmarkedAreas: [String: BookmarkedArea] = [:]

    public func addBookmarkedArea(name: String) {
        let id = UUID().uuidString
        bookmarkedAreas[id] = BookmarkedArea(id: id, name: name, panX: viewportX, panY: viewportY, scale: scale)
    }

    public func deleteBookmarkedArea(id: String) {
        bookmarkedAreas.removeValue(forKey: id)
    }

    public func renameBookmarkedArea(id: String, name: String) {
        bookmarkedAreas[id]?.name = name
    }

    public func jumpToArea(id: String, engine: CanvasWMEngine) {
        guard let area = bookmarkedAreas[id] else { return }
        viewportX = area.panX
        viewportY = area.panY
        engine.syncToScreen()
    }

    public var sortedWindows: [ManagedWindow] {
        windows.values.sorted { $0.zIndex < $1.zIndex }
    }

    /// Auto-fit: compute scale and pan so all windows + viewport fit in the given minimap size
    public func autoFit(minimapSize: CGSize, padding: Double = 40) {
        var minX = viewportX
        var minY = viewportY
        var maxX = viewportX + primaryScreenFrame.width
        var maxY = viewportY + primaryScreenFrame.height

        for win in windows.values {
            minX = min(minX, win.x)
            minY = min(minY, win.y)
            maxX = max(maxX, win.x + win.width)
            maxY = max(maxY, win.y + win.height)
        }

        let contentW = maxX - minX
        let contentH = maxY - minY
        guard contentW > 0, contentH > 0 else { return }

        let availW = Double(minimapSize.width) - padding * 2
        let availH = Double(minimapSize.height) - padding * 2
        scale = min(availW / contentW, availH / contentH, 0.3)

        panX = padding - minX * scale + (availW - contentW * scale) / 2
        panY = padding - minY * scale + (availH - contentH * scale) / 2
    }

    /// Shift pan so the monitor viewport is centered in the minimap (call after autoFit)
    public func centerOnMonitor(minimapSize: CGSize) {
        let monitorCenterX = viewportX + primaryScreenFrame.width / 2
        let monitorCenterY = viewportY + primaryScreenFrame.height / 2
        let targetPanX = Double(minimapSize.width) / 2 - monitorCenterX * scale
        let targetPanY = Double(minimapSize.height) / 2 - monitorCenterY * scale
        panX = targetPanX
        panY = targetPanY
    }
}
