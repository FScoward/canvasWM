import AppKit
import CoreGraphics

/// Positions real macOS windows according to canvas viewport
public final class CanvasWMEngine {
    public let state: CanvasWMState
    public let windowCapture: WindowCapture
    public var stickyNoteController: StickyNoteWindowController?
    private var syncTimer: Timer?
    private var recaptureTimer: Timer?
    private var notifyTimer: Timer?
    private var highlightDismissWork: DispatchWorkItem?
    private var isArranging = false
    // Track last-applied screen positions to detect user-initiated moves
    private var lastAppliedPositions: [String: CGPoint] = [:]
    /// True while the user is dragging a window or widget on the minimap
    public var isDragging: Bool = false
    /// When true, suppress user-move detection for floating widgets (minimap is showing)
    public var isMinimapShowing: Bool = false
    /// Frames to skip reverse sync after startSync or viewport movement to avoid
    /// false user-move detection (Accessibility API moves are async)
    private var reverseSyncCooldown: Int = 0
    /// Last viewport position used to detect viewport movement in syncToScreen
    private var lastSyncViewportX: Double = 0
    private var lastSyncViewportY: Double = 0

    /// Directory and file for external notification triggers
    private static let notifyDir: URL = {
        FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".canvaswm")
    }()
    private static let notifyFile: URL = {
        notifyDir.appendingPathComponent("notify")
    }()

    public init(state: CanvasWMState, windowCapture: WindowCapture = .shared) {
        self.state = state
        self.windowCapture = windowCapture
    }

    // MARK: - Capture windows and place on canvas

    public func captureAndPlaceWindows() {
        let windows = windowCapture.getWindows()
        let placedWindowIds = Set(state.windows.values.compactMap(\.windowId))
        let mainScreenFrame = state.primaryScreenFrame

        for win in windows {
            guard !placedWindowIds.contains(win.id) else { continue }
            let skipNames: Set<String> = [
                "CanvasWM", "Window Server", "Dock", "SystemUIServer",
                "Control Center", "Notification Center", "Spotlight",
                "WindowManager", "AXVisualSupportAgent", "TextInputMenuAgent",
                "universalAccessAuthWarn", "Wallpaper", "loginwindow",
                "Borders", "borders", "Bartender", "Ice", "Hidden Bar",
                "AltTab", "Rectangle", "Magnet", "Hammerspoon", "Karabiner-Elements",
                "Stats", "iStat Menus", "MenubarX", "Dozer",
                "DDPM"
            ]
            guard !skipNames.contains(win.ownerName) else { continue }
            guard win.bounds.width > 100 && win.bounds.height > 100 else { continue }
            guard !win.title.isEmpty || win.ownerName != "" else { continue }
            guard mainScreenFrame.intersects(win.bounds) else { continue }

            // Place at canvas position = screen position + viewport offset
            let canvasX = Double(win.bounds.origin.x) + state.viewportX
            let canvasY = Double(win.bounds.origin.y) + state.viewportY
            _ = state.addWindow(
                x: canvasX, y: canvasY,
                windowId: win.id, pid: win.ownerPid,
                ownerName: win.ownerName, title: win.title,
                width: Double(win.bounds.width), height: Double(win.bounds.height)
            )
        }

        // Update titles for existing windows so fallback matching stays in sync
        let liveWindowMap = Dictionary(uniqueKeysWithValues: windows.map { ($0.id, $0) })
        for (id, managed) in state.windows {
            if let wid = managed.windowId, let live = liveWindowMap[wid], live.title != managed.windowTitle {
                state.windows[id]?.windowTitle = live.title
            }
        }

        // Remove closed windows — prune managed windows whose real window no longer exists
        let liveWindowIds = Set(windows.map(\.id))
        let managedEntries = state.windows.filter { $0.value.windowId != nil }
        for (id, managed) in managedEntries {
            if let wid = managed.windowId, !liveWindowIds.contains(wid) {
                state.removeWindow(id: id)
                lastAppliedPositions.removeValue(forKey: id)
            }
        }

        // Pre-seed lastAppliedPositions so the first syncToScreen doesn't
        // re-apply positions unnecessarily (which causes windows to shift).
        let screen = state.primaryVisibleFrame
        let screenSize = (w: Double(screen.width), h: Double(screen.height))
        for win in state.sortedWindows {
            guard win.ownerPid != nil else { continue }
            if lastAppliedPositions[win.id] == nil {
                let r = state.screenRect(for: win, screenSize: screenSize)
                lastAppliedPositions[win.id] = CGPoint(x: r.x, y: r.y)
            }
        }
    }

    // MARK: - Bidirectional sync

    public func syncToScreen() {
        guard !isArranging else { return }
        isArranging = true
        defer { isArranging = false }

        // Detect viewport movement and extend cooldown so reverse sync
        // doesn't fire while Accessibility API is still finishing async moves
        let vpDx = abs(state.viewportX - lastSyncViewportX)
        let vpDy = abs(state.viewportY - lastSyncViewportY)
        if vpDx > 0.5 || vpDy > 0.5 {
            reverseSyncCooldown = max(reverseSyncCooldown, 5)
            lastSyncViewportX = state.viewportX
            lastSyncViewportY = state.viewportY
        }
        if reverseSyncCooldown > 0 { reverseSyncCooldown -= 1 }

        let screen = state.primaryVisibleFrame
        guard screen.width > 0 else { return }
        let screenSize = (w: Double(screen.width), h: Double(screen.height))

        for win in state.sortedWindows {
            guard let pid = win.ownerPid else { continue }

            // Apply canvas position to screen — only show if within viewport
            let r = state.screenRect(for: win, screenSize: screenSize)
            let inViewport = r.x + win.width > 0 && r.x < screenSize.w &&
                             r.y + win.height > 0 && r.y < screenSize.h
            if inViewport {
                let targetPos = CGPoint(x: r.x, y: r.y)
                let targetSize = CGSize(width: win.width, height: win.height)

                // If target position hasn't changed, allow user to freely move the window
                if let last = lastAppliedPositions[win.id],
                   abs(targetPos.x - last.x) < 1 && abs(targetPos.y - last.y) < 1,
                   last.x < 90000 {
                    // Skip reverse sync during cooldown to avoid false detection
                    // right after startSync or viewport movement (Accessibility API moves are async).
                    if reverseSyncCooldown > 0 { continue }
                    // Skip reverse sync if last applied position was outside visible screen area.
                    // macOS won't actually place a window at large negative coordinates (e.g. y=-1477)
                    // and will clamp it to the menu bar (~y=25). Reading back the clamped position
                    // would be falsely interpreted as a user-initiated move.
                    if Double(last.x) < -50 || Double(last.y) < -50 ||
                       Double(last.x) > screenSize.w + 50 || Double(last.y) > screenSize.h + 50 {
                        continue
                    }
                    // Target unchanged — detect user-initiated moves and sync to canvas
                    if let actual = windowCapture.getWindowPosition(pid: pid, windowTitle: win.windowTitle, windowId: win.windowId.map { CGWindowID($0) }) {
                        let actualX = Double(actual.position.x)
                        let actualY = Double(actual.position.y)
                        let dx = abs(actualX - Double(last.x))
                        let dy = abs(actualY - Double(last.y))
                        if dx > 5 || dy > 5 {
                            let newCanvasX = actualX + state.viewportX
                            let newCanvasY = actualY + state.viewportY
                            state.moveWindow(id: win.id, x: newCanvasX, y: newCanvasY)
                            lastAppliedPositions[win.id] = CGPoint(x: actualX, y: actualY)
                        }
                    }
                    continue
                }

                // Target changed (viewport moved or canvas drag) — apply position
                _ = windowCapture.setWindowPosition(
                    pid: pid, windowTitle: win.windowTitle,
                    position: targetPos,
                    size: targetSize,
                    windowId: win.windowId.map { CGWindowID($0) }
                )
                lastAppliedPositions[win.id] = targetPos
            } else {
                // Hide off-screen (far away so it won't land on any monitor)
                _ = windowCapture.setWindowPosition(
                    pid: pid, windowTitle: win.windowTitle,
                    position: CGPoint(x: 99999, y: 99999),
                    size: CGSize(width: win.width, height: win.height),
                    windowId: win.windowId.map { CGWindowID($0) }
                )
                lastAppliedPositions[win.id] = CGPoint(x: 99999, y: 99999)
            }
        }

        // Sync floating widget positions (suppress user-move detection during minimap
        // because makeKeyAndOrderFront causes panels to shift, triggering false positives)
        stickyNoteController?.syncPositions(
            viewportX: state.viewportX, viewportY: state.viewportY,
            screenFrame: state.primaryScreenFrame,
            forceSkipUserMoveDetection: isMinimapShowing
        )
    }

    // MARK: - Start/stop continuous sync

    public func startSync(interval: TimeInterval = 1.0 / 60.0) {
        // Skip reverse-sync for the first ~10 frames (~167ms at 60fps) so
        // Accessibility API position writes finish before we read back.
        reverseSyncCooldown = 10
        syncTimer?.invalidate()
        syncTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.syncToScreen()
        }

        // Periodic recapture for new windows (every 3 seconds)
        recaptureTimer?.invalidate()
        recaptureTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            let beforeCount = self.state.windows.count
            self.captureAndPlaceWindows()
            if self.state.windows.count > beforeCount {
                self.captureAllThumbnails()
            }
        }

        // Watch for external notification triggers
        startNotifyWatch()
    }

    public func stopSync() {
        syncTimer?.invalidate()
        syncTimer = nil
        recaptureTimer?.invalidate()
        recaptureTimer = nil
        lastAppliedPositions.removeAll()
        stopNotifyWatch()
    }

    // MARK: - Focus & activate

    public func activateWindow(id: String) {
        state.bringToFront(id: id)
        if let win = state.windows[id], let pid = win.ownerPid {
            NSRunningApplication(processIdentifier: pid)?.activate()
        }
    }

    /// Capture thumbnails for all managed windows
    public func captureAllThumbnails() {
        for (id, win) in state.windows {
            guard let windowId = win.windowId else { continue }
            if let image = windowCapture.captureWindow(windowId: CGWindowID(windowId)) {
                state.thumbnails[id] = image
            }
        }
    }

    // MARK: - Notification highlight via trigger file

    /// Start watching ~/.canvaswm/notify for external highlight triggers.
    /// File format: one line with the app name to highlight (e.g. "iTerm2").
    /// The file is deleted after reading.
    public func startNotifyWatch(interval: TimeInterval = 0.5) {
        // Ensure directory exists
        try? FileManager.default.createDirectory(at: Self.notifyDir, withIntermediateDirectories: true)

        notifyTimer?.invalidate()
        notifyTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.checkNotifyFile()
        }
    }

    public func stopNotifyWatch() {
        notifyTimer?.invalidate()
        notifyTimer = nil
        highlightDismissWork?.cancel()
        highlightDismissWork = nil
    }

    private func checkNotifyFile() {
        let fm = FileManager.default
        let path = Self.notifyFile.path
        guard fm.fileExists(atPath: path),
              let data = fm.contents(atPath: path),
              let content = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !content.isEmpty else { return }

        // Delete trigger file immediately
        try? fm.removeItem(atPath: path)

        // Highlight matching windows
        state.highlightWindows(ownerName: content)

        // Auto-dismiss after 5 seconds
        highlightDismissWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.state.clearHighlights()
        }
        highlightDismissWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }

    // MARK: - Gather windows back to monitor

    /// Move all managed windows back into the primary monitor's visible area.
    /// Uses cascade layout to avoid stacking all windows at the same position.
    public func gatherWindowsToMonitor() {
        let screen = state.primaryVisibleFrame
        guard screen.width > 0 else { return }

        let cascadeOffset: Double = 30
        var offsetX: Double = Double(screen.origin.x) + 20
        var offsetY: Double = Double(screen.origin.y) + 20

        for win in state.sortedWindows {
            guard let pid = win.ownerPid else { continue }

            // Clamp position so window fits within visible frame
            let x = min(offsetX, Double(screen.maxX) - win.width)
            let y = min(offsetY, Double(screen.maxY) - win.height)

            _ = windowCapture.setWindowPosition(
                pid: pid, windowTitle: win.windowTitle,
                position: CGPoint(x: x, y: y),
                size: CGSize(width: win.width, height: win.height),
                windowId: win.windowId.map { CGWindowID($0) }
            )

            offsetX += cascadeOffset
            offsetY += cascadeOffset
            // Wrap cascade if it goes off-screen
            if offsetX + win.width > Double(screen.maxX) {
                offsetX = Double(screen.origin.x) + 20
            }
            if offsetY + win.height > Double(screen.maxY) {
                offsetY = Double(screen.origin.y) + 20
            }
        }
    }

    deinit { stopSync(); stopNotifyWatch() }
}
