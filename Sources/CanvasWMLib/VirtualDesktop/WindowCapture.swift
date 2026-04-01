import AppKit
import ApplicationServices

public final class WindowCapture {
    public static let shared = WindowCapture()
    private init() {}

    // MARK: - Per-frame cache (call beginFrame/endFrame around sync loops)

    private var frameWindowList: [[String: Any]]?
    private var frameAXWindows: [pid_t: [AXUIElement]] = [:]

    /// Call at the start of a sync frame to cache expensive system queries
    public func beginFrame() {
        frameWindowList = CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]]
        frameAXWindows.removeAll()
    }

    /// Call at the end of a sync frame to release cache
    public func endFrame() {
        frameWindowList = nil
        frameAXWindows.removeAll()
    }

    private func getCachedWindowList() -> [[String: Any]] {
        if let cached = frameWindowList { return cached }
        return CGWindowListCopyWindowInfo([.optionAll], kCGNullWindowID) as? [[String: Any]] ?? []
    }

    private func getCachedAXWindows(pid: pid_t) -> [AXUIElement]? {
        if let cached = frameAXWindows[pid] { return cached }
        let app = AXUIElementCreateApplication(pid)
        var windowsRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
              let windows = windowsRef as? [AXUIElement] else { return nil }
        frameAXWindows[pid] = windows
        return windows
    }

    public struct WindowInfo {
        public let id: CGWindowID
        public let ownerName: String
        public let title: String
        public let bounds: CGRect
        public let ownerPid: pid_t
        public let layer: Int
        public let isOnScreen: Bool
        public let alpha: Double
    }

    /// Request Accessibility permissions
    public func requestAccessibilityPermission() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    /// Get the set of CGWindowIDs on the currently active Space
    private func windowIDsOnActiveSpace() -> Set<CGWindowID>? {
        let conn = CGSMainConnectionID()
        guard conn != 0 else { return nil }
        let activeSpace = CGSGetActiveSpace(conn)
        guard activeSpace != 0 else { return nil }

        // Get all normal-layer window IDs first
        guard let allWindows = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        var normalWindowIDs: [CGWindowID] = []
        for dict in allWindows {
            guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
                  let layer = dict[kCGWindowLayer as String] as? Int,
                  layer == 0 else { continue }
            normalWindowIDs.append(id)
        }
        guard !normalWindowIDs.isEmpty else { return Set() }

        // Query which Space each window belongs to
        var result = Set<CGWindowID>()
        for wid in normalWindowIDs {
            let windowArray = [wid] as CFArray
            let spaces = CGSCopySpacesForWindows(conn, 0x7, windowArray) as? [UInt64] ?? []
            if spaces.contains(activeSpace) {
                result.insert(wid)
            }
        }
        return result
    }

    /// Get all visible windows on the current Space
    public func getWindows() -> [WindowInfo] {
        let allOnScreen = getWindowList(options: [.optionOnScreenOnly, .excludeDesktopElements], onScreenOnly: true)

        // Filter to only windows on the active Space
        guard let activeSpaceWindowIDs = windowIDsOnActiveSpace() else {
            return allOnScreen
        }
        return allOnScreen.filter { activeSpaceWindowIDs.contains($0.id) }
    }

    /// Get IDs of all windows that still exist (across all Spaces)
    public func getAllLiveWindowIDs() -> Set<CGWindowID> {
        guard let windowList = CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var ids = Set<CGWindowID>()
        for dict in windowList {
            guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
                  let layer = dict[kCGWindowLayer as String] as? Int,
                  layer == 0
            else { continue }
            ids.insert(id)
        }
        return ids
    }

    private func getWindowList(options: CGWindowListOption, onScreenOnly: Bool) -> [WindowInfo] {
        guard let windowList = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return windowList.compactMap { dict -> WindowInfo? in
            guard let id = dict[kCGWindowNumber as String] as? CGWindowID,
                  let ownerName = dict[kCGWindowOwnerName as String] as? String,
                  let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? Double,
                  let y = boundsDict["Y"] as? Double,
                  let w = boundsDict["Width"] as? Double,
                  let h = boundsDict["Height"] as? Double,
                  let pid = dict[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = dict[kCGWindowLayer as String] as? Int
            else { return nil }

            let title = dict[kCGWindowName as String] as? String ?? ""
            let isOnScreen = dict[kCGWindowIsOnscreen as String] as? Bool ?? false
            let alpha = dict[kCGWindowAlpha as String] as? Double ?? 1.0
            return WindowInfo(id: id, ownerName: ownerName, title: title,
                            bounds: CGRect(x: x, y: y, width: w, height: h),
                            ownerPid: pid, layer: layer,
                            isOnScreen: isOnScreen, alpha: alpha)
        }.filter {
            $0.layer == 0 &&           // Normal windows only
            $0.bounds.width > 100 &&   // Skip tiny windows (menu extras, etc)
            $0.bounds.height > 100 &&
            (!onScreenOnly || $0.isOnScreen)
        }
    }

    /// Move and resize a window using Accessibility API (matches by CGWindowID via bounds comparison)
    public func setWindowPosition(pid: pid_t, windowTitle: String, position: CGPoint, size: CGSize, windowId: CGWindowID? = nil) -> Bool {
        guard let windows = getCachedAXWindows(pid: pid) else { return false }

        // Try to match by CGWindowID first (robust against title changes)
        if let windowId = windowId {
            let axWindow = findAXWindow(axWindows: windows, pid: pid, targetWindowId: windowId)
            if let axWindow = axWindow {
                return applyPosition(axWindow, position: position, size: size)
            }
        }

        // Fallback: match by title (backwards compatibility)
        for window in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""
            if title == windowTitle || windowTitle.isEmpty {
                return applyPosition(window, position: position, size: size)
            }
        }
        return false
    }

    /// Find AXUIElement window matching a CGWindowID by comparing bounds with CGWindowList
    private func findAXWindow(axWindows: [AXUIElement], pid: pid_t, targetWindowId: CGWindowID) -> AXUIElement? {
        // Get the target window's current bounds from CGWindowList (uses frame cache if available)
        let windowList = getCachedWindowList()
        var targetBounds: CGRect?
        for dict in windowList {
            guard let wid = dict[kCGWindowNumber as String] as? CGWindowID, wid == targetWindowId,
                  let boundsDict = dict[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDict["X"] as? Double, let y = boundsDict["Y"] as? Double,
                  let w = boundsDict["Width"] as? Double, let h = boundsDict["Height"] as? Double
            else { continue }
            targetBounds = CGRect(x: x, y: y, width: w, height: h)
            break
        }
        guard let target = targetBounds else { return nil }

        // Match AXUIElement by comparing position+size with CGWindowList bounds
        for axWin in axWindows {
            var posRef: CFTypeRef?
            var sizeRef: CFTypeRef?
            AXUIElementCopyAttributeValue(axWin, kAXPositionAttribute as CFString, &posRef)
            AXUIElementCopyAttributeValue(axWin, kAXSizeAttribute as CFString, &sizeRef)
            var pos = CGPoint.zero
            var sz = CGSize.zero
            if let posRef { AXValueGetValue(posRef as! AXValue, .cgPoint, &pos) }
            if let sizeRef { AXValueGetValue(sizeRef as! AXValue, .cgSize, &sz) }

            // Allow small tolerance for rounding differences
            if abs(pos.x - target.origin.x) < 5 && abs(pos.y - target.origin.y) < 5 &&
               abs(sz.width - target.size.width) < 5 && abs(sz.height - target.size.height) < 5 {
                return axWin
            }
        }
        return nil
    }

    /// Apply position and size to an AXUIElement window
    private func applyPosition(_ window: AXUIElement, position: CGPoint, size: CGSize) -> Bool {
        var pos = position
        let posValue = AXValueCreate(.cgPoint, &pos)!
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, posValue)

        var sz = size
        let szValue = AXValueCreate(.cgSize, &sz)!
        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, szValue)
        return true
    }

    /// Capture screenshot of a specific window
    public func captureWindow(windowId: CGWindowID) -> NSImage? {
        guard let cgImage = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowId,
            [.boundsIgnoreFraming, .nominalResolution]
        ) else { return nil }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }

    /// Get window position and size (matches by CGWindowID via bounds comparison)
    public func getWindowPosition(pid: pid_t, windowTitle: String, windowId: CGWindowID? = nil) -> (position: CGPoint, size: CGSize)? {
        guard let windows = getCachedAXWindows(pid: pid) else { return nil }

        // Try to match by CGWindowID first
        if let windowId = windowId {
            let axWindow = findAXWindow(axWindows: windows, pid: pid, targetWindowId: windowId)
            if let axWindow = axWindow {
                return readPosition(axWindow)
            }
        }

        // Fallback: match by title
        for window in windows {
            var titleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleRef)
            let title = titleRef as? String ?? ""
            if title == windowTitle || windowTitle.isEmpty {
                return readPosition(window)
            }
        }
        return nil
    }

    /// Read position and size from an AXUIElement window
    private func readPosition(_ window: AXUIElement) -> (position: CGPoint, size: CGSize)? {
        var posRef: CFTypeRef?
        var sizeRef: CFTypeRef?
        AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &posRef)
        AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeRef)

        var pos = CGPoint.zero
        var sz = CGSize.zero
        if let posRef { AXValueGetValue(posRef as! AXValue, .cgPoint, &pos) }
        if let sizeRef { AXValueGetValue(sizeRef as! AXValue, .cgSize, &sz) }
        return (pos, sz)
    }
}
