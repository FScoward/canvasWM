import AppKit
import SwiftUI

public final class CanvasWMWindowController {
    public let wmState: CanvasWMState
    public let engine: CanvasWMEngine
    private var minimapWindow: NSWindow?
    private var minimapDelegate: MinimapWindowDelegate?
    private var keyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var scrollMonitor: Any?
    private var flagsMonitor: Any?
    private var globalFlagsMonitor: Any?
    private var mouseTrackMonitor: Any?
    private var inactivityTimer: Timer?
    private var activityMonitors: [Any] = []
    /// Seconds of inactivity before auto-hiding the minimap
    private static let inactivityTimeout: TimeInterval = 2.0
    public private(set) var isActive: Bool = false
    /// Whether the minimap is currently shown via meta-key shortcut
    private var isMetaKeyShowing: Bool = false
    /// Whether the engine/state are prepared (windows captured, sync ready)
    private var isPrepared: Bool = false
    /// Fade-out work item
    private var fadeOutWork: DispatchWorkItem?
    /// Tracks whether Option+Control were both pressed (for toggle detection)
    private var metaKeysWerePressed: Bool = false

    private static let minimapSize: CGSize = {
        guard let screen = NSScreen.main else { return CGSize(width: 1600, height: 1000) }
        let f = screen.visibleFrame
        return CGSize(width: f.width * 0.85, height: f.height * 0.85)
    }()

    /// Required modifier flags to show the minimap: Option + Control
    private static let requiredFlags: NSEvent.ModifierFlags = [.option, .control]

    public var stickyNoteController: StickyNoteWindowController? {
        didSet { engine.stickyNoteController = stickyNoteController }
    }

    public init() {
        wmState = CanvasWMState()
        engine = CanvasWMEngine(state: wmState)
    }

    // MARK: - Prepare (capture windows, create hidden minimap)

    public func prepare() {
        guard !isPrepared else { return }
        isPrepared = true
        if let screen = NSScreen.main { wmState.pinPrimaryScreen(screen) }
        _ = WindowCapture.shared.requestAccessibilityPermission()
        engine.captureAndPlaceWindows()
        engine.captureAllThumbnails()
        wmState.autoFit(minimapSize: Self.minimapSize)
        createMinimapWindow()
        minimapWindow?.alphaValue = 0
        minimapWindow?.orderOut(nil)
        registerFlagsMonitors()
    }

    // MARK: - Persistent mode (Ctrl+T toggle)

    public func activate() {
        guard !isActive else { return }
        isActive = true
        if !isPrepared {
            if let screen = NSScreen.main { wmState.pinPrimaryScreen(screen) }
            _ = WindowCapture.shared.requestAccessibilityPermission()
            engine.captureAndPlaceWindows()
            engine.captureAllThumbnails()
            wmState.autoFit(minimapSize: Self.minimapSize)
            createMinimapWindow()
        }
        minimapWindow?.alphaValue = 1.0
        minimapWindow?.makeKeyAndOrderFront(nil)
        registerKeyMonitors()
        engine.startSync()
        engine.syncToScreen()
    }

    public func deactivate() {
        guard isActive else { return }
        isActive = false
        engine.stopSync()
        unregisterKeyMonitors()
        minimapWindow?.orderOut(nil)
        minimapWindow = nil
        isPrepared = false
    }

    public func toggle() { if isActive { deactivate() } else { activate() } }

    /// Clean up all monitors (call on app termination)
    public func cleanup() {
        unregisterFlagsMonitors()
        fadeOutWork?.cancel()
        fadeOutWork = nil
    }

    // MARK: - Meta-key toggle show/hide

    /// Show minimap with fade-in. User can interact freely after keys are released.
    /// Hides when mouse leaves the minimap or Option+Control is pressed again.
    private func showWithMetaKey() {
        guard !isMetaKeyShowing, !isActive else { return }
        isMetaKeyShowing = true
        fadeOutWork?.cancel()
        fadeOutWork = nil

        if !isPrepared {
            prepare()
        }
        // Refresh window state
        engine.captureAndPlaceWindows()
        engine.captureAllThumbnails()
        if let size = minimapWindow?.frame.size {
            wmState.autoFit(minimapSize: size)
        }
        // Show with fade-in
        minimapWindow?.alphaValue = 0
        minimapWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        registerKeyMonitors()
        startMouseTracking()
        startInactivityTimer()
        engine.startSync()
        engine.syncToScreen()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.25
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.minimapWindow?.animator().alphaValue = 1.0
        }
    }

    /// Hide minimap with fade-out
    private func hideWithMetaKey() {
        guard isMetaKeyShowing else { return }
        if engine.isDragging {
            let work = DispatchWorkItem { [weak self] in self?.hideWithMetaKey() }
            fadeOutWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
            return
        }
        isMetaKeyShowing = false
        fadeOutWork?.cancel()
        stopMouseTracking()
        stopInactivityTimer()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            self.engine.stopSync()
            self.unregisterKeyMonitors()
            self.minimapWindow?.orderOut(nil)
        }
        fadeOutWork = work
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.5
            ctx.timingFunction = CAMediaTimingFunction(name: .easeOut)
            self.minimapWindow?.animator().alphaValue = 0
        }, completionHandler: {
            work.perform()
        })
    }

    // MARK: - Mouse tracking (hide when mouse leaves minimap)

    private func startMouseTracking() {
        mouseTrackMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
            guard let self, self.isMetaKeyShowing, let window = self.minimapWindow else { return }
            // If click is outside the minimap window, hide it
            let mouseScreen = NSEvent.mouseLocation
            if !window.frame.contains(mouseScreen) {
                DispatchQueue.main.async { self.hideWithMetaKey() }
            }
        }
    }

    private func stopMouseTracking() {
        if let m = mouseTrackMonitor { NSEvent.removeMonitor(m); mouseTrackMonitor = nil }
    }

    // MARK: - Inactivity auto-hide

    private func startInactivityTimer() {
        stopInactivityTimer()
        resetInactivityTimer()
        // Monitor mouse movement, clicks, scrolls, and key events on the minimap
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDown, .leftMouseDragged,
                                              .scrollWheel, .keyDown]
        let monitor = NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
            guard let self, self.isMetaKeyShowing else { return event }
            self.resetInactivityTimer()
            return event
        }
        activityMonitors.append(monitor as Any)
    }

    private func stopInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = nil
        for m in activityMonitors { NSEvent.removeMonitor(m) }
        activityMonitors.removeAll()
    }

    private func resetInactivityTimer() {
        inactivityTimer?.invalidate()
        inactivityTimer = Timer.scheduledTimer(withTimeInterval: Self.inactivityTimeout, repeats: false) { [weak self] _ in
            guard let self, self.isMetaKeyShowing else { return }
            self.hideWithMetaKey()
        }
    }

    // MARK: - Modifier flags monitoring (always active after prepare)

    private func registerFlagsMonitors() {
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let held = flags.contains(Self.requiredFlags)
            DispatchQueue.main.async {
                if held && !self.metaKeysWerePressed {
                    self.metaKeysWerePressed = true
                } else if !held && self.metaKeysWerePressed {
                    self.metaKeysWerePressed = false
                    // Toggle: show if hidden, hide if shown
                    if self.isMetaKeyShowing {
                        self.hideWithMetaKey()
                    } else {
                        self.showWithMetaKey()
                    }
                }
            }
        }

        flagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
            return event
        }
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler)
    }

    private func unregisterFlagsMonitors() {
        if let m = flagsMonitor { NSEvent.removeMonitor(m); flagsMonitor = nil }
        if let m = globalFlagsMonitor { NSEvent.removeMonitor(m); globalFlagsMonitor = nil }
    }

    private func createMinimapWindow() {
        let size = Self.minimapSize
        // Position in bottom-right corner of main screen
        let screenFrame = wmState.primaryVisibleFrame
        let origin = CGPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.midY - size.height / 2
        )
        let window = MinimapWindow(
            contentRect: CGRect(origin: origin, size: size),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CanvasWM"
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)))
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.minSize = CGSize(width: 320, height: 220)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        minimapDelegate = MinimapWindowDelegate(controller: self)
        window.delegate = minimapDelegate

        // Frosted glass background
        let visualEffect = NSVisualEffectView()
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.autoresizingMask = [.width, .height]

        var view = CanvasWMOverlayView(state: wmState, engine: engine)
        view.stickyNoteController = stickyNoteController
        let hostingView = NSHostingView(rootView: view)
        hostingView.autoresizingMask = [.width, .height]

        visualEffect.frame = CGRect(origin: .zero, size: size)
        hostingView.frame = CGRect(origin: .zero, size: size)
        visualEffect.addSubview(hostingView)
        window.contentView = visualEffect
        window.makeKeyAndOrderFront(nil)
        minimapWindow = window
    }

    private func registerKeyMonitors() {
        // Scroll → zoom (NSEvent monitor works reliably in panel windows)
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, (self.isActive || self.isMetaKeyShowing),
                  let window = self.minimapWindow,
                  event.window == window else { return event }
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 3
            let zoomDelta = delta > 0 ? 0.03 : -0.03
            let mouseInWindow = event.locationInWindow
            let windowH = window.frame.height
            let mouseX = mouseInWindow.x
            let mouseY = windowH - mouseInWindow.y

            let result = ViewportMath.zoomAtPoint(
                currentScale: self.wmState.scale, delta: zoomDelta,
                pointX: mouseX, pointY: mouseY,
                panX: self.wmState.panX, panY: self.wmState.panY)
            self.wmState.scale = result.newScale
            self.wmState.panX = result.newPanX
            self.wmState.panY = result.newPanY
            self.engine.syncToScreen()
            return nil
        }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, (self.isActive || self.isMetaKeyShowing) else { return event }
            if event.keyCode == 53 { self.deactivate(); return nil } // Esc
            if event.modifierFlags.contains(.control) && event.keyCode == 15 { // Ctrl+R
                self.engine.captureAndPlaceWindows()
                self.engine.captureAllThumbnails()
                if let size = self.minimapWindow?.frame.size {
                    self.wmState.autoFit(minimapSize: size)
                }
                self.engine.syncToScreen()
                return nil
            }
            return event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, (self.isActive || self.isMetaKeyShowing) else { return }
            if event.keyCode == 53 {
                DispatchQueue.main.async { self.deactivate() }
            }
        }
    }

    private func unregisterKeyMonitors() {
        [scrollMonitor, keyMonitor, globalKeyMonitor].compactMap { $0 }.forEach {
            NSEvent.removeMonitor($0)
        }
        scrollMonitor = nil; keyMonitor = nil; globalKeyMonitor = nil
    }

    deinit { deactivate(); unregisterFlagsMonitors(); stopMouseTracking(); stopInactivityTimer() }
}

// Custom window that strips modifier flags from mouse events so SwiftUI
// gestures work while Option+Control are held down.
private class MinimapWindow: NSWindow {
    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged,
             .rightMouseDown, .rightMouseUp, .rightMouseDragged,
             .otherMouseDown, .otherMouseUp, .otherMouseDragged:
            // Create a copy with modifier flags stripped
            if let stripped = NSEvent.mouseEvent(
                with: event.type,
                location: event.locationInWindow,
                modifierFlags: [],
                timestamp: event.timestamp,
                windowNumber: event.windowNumber,
                context: nil,
                eventNumber: event.eventNumber,
                clickCount: event.clickCount,
                pressure: event.pressure
            ) {
                super.sendEvent(stripped)
                return
            }
        default:
            break
        }
        super.sendEvent(event)
    }
}

// Close minimap → deactivate WM
private class MinimapWindowDelegate: NSObject, NSWindowDelegate {
    weak var controller: CanvasWMWindowController?
    init(controller: CanvasWMWindowController) { self.controller = controller }
    func windowWillClose(_ notification: Notification) {
        controller?.deactivate()
    }
}
