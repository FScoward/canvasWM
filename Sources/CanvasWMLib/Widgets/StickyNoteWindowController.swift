import AppKit
import SwiftUI
import Observation

/// Manages all floating desktop widgets (sticky notes, markdown, browsers) with canvas-coordinate positioning
@Observable
public final class StickyNoteWindowController {
    public var notes: [String: DesktopStickyNote] = [:]
    public var markdowns: [String: DesktopMarkdownNote] = [:]
    public var browsers: [String: DesktopBrowser] = [:]
    private var windows: [String: NSPanel] = [:]
    private var saveTask: Task<Void, Never>?
    private var isSyncing = false
    private var lastAppliedFrames: [String: CGRect] = [:]
    private var lastViewportX: Double = 0
    private var lastViewportY: Double = 0

    private var storageURL: URL { storageDir.appendingPathComponent("sticky-notes.json") }
    private var markdownURL: URL { storageDir.appendingPathComponent("desktop-markdowns.json") }
    private var browserURL: URL { storageDir.appendingPathComponent("desktop-browsers.json") }

    private var storageDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("CanvasWM", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public init() {
        loadAll()
    }

    // MARK: - Create

    public func createNote(viewportX: Double = 0, viewportY: Double = 0,
                           screenWidth: Double = 400, screenHeight: Double = 400) {
        let cx = viewportX + screenWidth / 2 - DesktopStickyNote.defaultWidth / 2 + Double.random(in: -50...50)
        let cy = viewportY + screenHeight / 2 - DesktopStickyNote.defaultHeight / 2 + Double.random(in: -50...50)
        let note = DesktopStickyNote(x: cx, y: cy)
        notes[note.id] = note
        showNoteWindow(note)
        scheduleSave()
    }

    public func createMarkdown(viewportX: Double = 0, viewportY: Double = 0,
                               screenWidth: Double = 400, screenHeight: Double = 400) {
        let cx = viewportX + screenWidth / 2 - DesktopMarkdownNote.defaultWidth / 2 + Double.random(in: -50...50)
        let cy = viewportY + screenHeight / 2 - DesktopMarkdownNote.defaultHeight / 2 + Double.random(in: -50...50)
        let md = DesktopMarkdownNote(x: cx, y: cy)
        markdowns[md.id] = md
        showMarkdownWindow(md)
        scheduleSave()
    }

    public func createBrowser(viewportX: Double = 0, viewportY: Double = 0,
                              screenWidth: Double = 400, screenHeight: Double = 400) {
        let cx = viewportX + screenWidth / 2 - DesktopBrowser.defaultWidth / 2 + Double.random(in: -50...50)
        let cy = viewportY + screenHeight / 2 - DesktopBrowser.defaultHeight / 2 + Double.random(in: -50...50)
        let br = DesktopBrowser(x: cx, y: cy)
        browsers[br.id] = br
        showBrowserWindow(br)
        scheduleSave()
    }

    // MARK: - Delete

    public func deleteNote(id: String) {
        notes.removeValue(forKey: id)
        closeWindow(id: id)
        scheduleSave()
    }

    public func deleteMarkdown(id: String) {
        markdowns.removeValue(forKey: id)
        closeWindow(id: id)
        scheduleSave()
    }

    public func deleteBrowser(id: String) {
        browsers.removeValue(forKey: id)
        closeWindow(id: id)
        scheduleSave()
    }

    private func closeWindow(id: String) {
        windows[id]?.orderOut(nil)
        windows.removeValue(forKey: id)
    }

    // MARK: - Restore

    public func restoreAllWindows() {
        for note in notes.values { showNoteWindow(note) }
        for md in markdowns.values { showMarkdownWindow(md) }
        for br in browsers.values { showBrowserWindow(br) }
    }

    /// Capture actual panel screen positions into canvas coordinates.
    /// Call before starting sync so canvas coords are fresh and syncPositions
    /// won't force widgets back to stale persisted positions.
    public func captureCurrentPositions(viewportX: Double, viewportY: Double, screenFrame: CGRect) {
        let screenW = Double(screenFrame.width)
        let screenH = Double(screenFrame.height)
        for (id, panel) in windows {
            let frame = panel.frame
            let fx = Double(frame.origin.x)
            let fy = Double(frame.origin.y)

            // Skip panels that are off-screen (placed there by syncPanel during viewport drag)
            // Their canvas coords from the last sync are still correct.
            let isOffScreen = fx < -200 || fx > screenW + 200 || fy < -200 || fy > screenH + 200
            if isOffScreen {
                continue
            }

            // Get model height and current canvas coords
            var h: Double = Double(frame.height)
            var curCanvasX: Double = 0, curCanvasY: Double = 0
            if let note = notes[id] { h = note.height; curCanvasX = note.x; curCanvasY = note.y }
            else if let md = markdowns[id] { h = md.height; curCanvasX = md.x; curCanvasY = md.y }
            else if let br = browsers[id] { h = br.height; curCanvasX = br.x; curCanvasY = br.y }
            else { continue }

            // Check if panel is at the position canvas coords predict
            let expectedScreenX = curCanvasX - viewportX
            let expectedFlippedY = Double(screenFrame.height) - (curCanvasY - viewportY) - h + Double(screenFrame.minY)
            let dx = abs(fx - expectedScreenX)
            let dy = abs(fy - expectedFlippedY)

            if dx <= 5 && dy <= 5 {
                continue
            }

            // Panel is on-screen but doesn't match canvas coords — recapture
            let screenY = screenH - fy - h + Double(screenFrame.minY)
            let canvasX = fx + viewportX
            let canvasY = screenY + viewportY
            if notes[id] != nil { notes[id]?.x = canvasX; notes[id]?.y = canvasY }
            if markdowns[id] != nil { markdowns[id]?.x = canvasX; markdowns[id]?.y = canvasY }
            if browsers[id] != nil { browsers[id]?.x = canvasX; browsers[id]?.y = canvasY }
            lastAppliedFrames[id] = frame
        }
        lastViewportX = viewportX
        lastViewportY = viewportY
    }

    // MARK: - Viewport Sync

    public func syncPositions(viewportX: Double, viewportY: Double, screenFrame: CGRect,
                              forceSkipUserMoveDetection: Bool = false) {
        isSyncing = true
        defer { isSyncing = false }

        // Detect viewport movement — skip user-move detection while viewport is moving
        let viewportMoved = abs(viewportX - lastViewportX) > 0.5 || abs(viewportY - lastViewportY) > 0.5
        lastViewportX = viewportX
        lastViewportY = viewportY

        let skipUserMove = forceSkipUserMoveDetection || viewportMoved

        for (id, note) in notes {
            syncPanel(id: id, canvasX: note.x, canvasY: note.y, w: note.width, h: note.height,
                      viewportX: viewportX, viewportY: viewportY, screenFrame: screenFrame,
                      skipUserMoveDetection: skipUserMove)
        }
        for (id, md) in markdowns {
            syncPanel(id: id, canvasX: md.x, canvasY: md.y, w: md.width, h: md.height,
                      viewportX: viewportX, viewportY: viewportY, screenFrame: screenFrame,
                      skipUserMoveDetection: skipUserMove)
        }
        for (id, br) in browsers {
            syncPanel(id: id, canvasX: br.x, canvasY: br.y, w: br.width, h: br.height,
                      viewportX: viewportX, viewportY: viewportY, screenFrame: screenFrame,
                      skipUserMoveDetection: skipUserMove)
        }
    }

    private func syncPanel(id: String, canvasX: Double, canvasY: Double, w: Double, h: Double,
                           viewportX: Double, viewportY: Double, screenFrame: CGRect,
                           skipUserMoveDetection: Bool = false) {
        guard let panel = windows[id] else { return }

        // Detect user-initiated move: compare actual panel position with last applied
        // Skip when viewport is moving to avoid false positives from programmatic repositioning
        let actualFrame = panel.frame
        if !skipUserMoveDetection, let lastFrame = lastAppliedFrames[id] {
            let dx = abs(actualFrame.origin.x - lastFrame.origin.x)
            let dy = abs(actualFrame.origin.y - lastFrame.origin.y)
            if dx > 3 || dy > 3 {
                // User moved the panel — convert screen position back to canvas coords
                let screenX = Double(actualFrame.origin.x)
                // Flip Y back from bottom-left to top-left
                let screenY = Double(screenFrame.height) - Double(actualFrame.origin.y) - h + Double(screenFrame.minY)
                let newCanvasX = screenX + viewportX
                let newCanvasY = screenY + viewportY
                // Update the appropriate model
                if notes[id] != nil { notes[id]?.x = newCanvasX; notes[id]?.y = newCanvasY }
                if markdowns[id] != nil { markdowns[id]?.x = newCanvasX; markdowns[id]?.y = newCanvasY }
                if browsers[id] != nil { browsers[id]?.x = newCanvasX; browsers[id]?.y = newCanvasY }
                lastAppliedFrames[id] = actualFrame
                scheduleSave()
                return  // Don't override what the user just did
            }
        }

        let screenX = canvasX - viewportX
        let screenY = canvasY - viewportY
        let visible = screenX + w > -100 && screenX < Double(screenFrame.width) + 100 &&
                      screenY + h > -100 && screenY < Double(screenFrame.height) + 100

        if visible {
            let flippedY = Double(screenFrame.height) - screenY - h + Double(screenFrame.minY)
            // Only update position, preserve panel's current size (frame includes title bar)
            let cur = panel.frame
            if abs(screenX - Double(cur.origin.x)) > 1
                || abs(flippedY - Double(cur.origin.y)) > 1 {
                var newFrame = cur
                newFrame.origin = CGPoint(x: screenX, y: flippedY)
                panel.setFrame(newFrame, display: true)
                lastAppliedFrames[id] = newFrame
            }
            panel.orderFront(nil)
        } else {
            let cur = panel.frame
            if cur.origin.x != -10000 || cur.origin.y != -10000 {
                var offFrame = cur
                offFrame.origin = CGPoint(x: -10000, y: -10000)
                panel.setFrame(offFrame, display: false)
                lastAppliedFrames[id] = offFrame
            }
        }
    }

    // MARK: - Window Creation

    private func makePanel(rect: CGRect, minSize: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: rect,
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered, defer: false
        )
        panel.title = ""
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.level = .floating
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.minSize = minSize
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = .clear
        return panel
    }

    private func showNoteWindow(_ note: DesktopStickyNote) {
        guard windows[note.id] == nil else { return }
        let panel = makePanel(
            rect: CGRect(x: note.x, y: note.y, width: note.width, height: note.height),
            minSize: NSSize(width: DesktopStickyNote.minWidth, height: DesktopStickyNote.minHeight)
        )
        let noteId = note.id
        let view = DesktopStickyNoteView(
            note: Binding(
                get: { [weak self] in self?.notes[noteId] ?? note },
                set: { [weak self] in self?.notes[noteId] = $0 }
            ),
            onDelete: { [weak self] in self?.deleteNote(id: noteId) },
            onChanged: { [weak self] in self?.scheduleSave() }
        )
        panel.contentView = NSHostingView(rootView: view)
        registerObservers(id: noteId, panel: panel)
        panel.orderFront(nil)
        windows[noteId] = panel
        lastAppliedFrames[noteId] = panel.frame
    }

    private func showMarkdownWindow(_ md: DesktopMarkdownNote) {
        guard windows[md.id] == nil else { return }
        let panel = makePanel(
            rect: CGRect(x: md.x, y: md.y, width: md.width, height: md.height),
            minSize: NSSize(width: DesktopMarkdownNote.minWidth, height: DesktopMarkdownNote.minHeight)
        )
        let mdId = md.id
        let view = DesktopMarkdownView(
            note: Binding(
                get: { [weak self] in self?.markdowns[mdId] ?? md },
                set: { [weak self] in self?.markdowns[mdId] = $0 }
            ),
            onDelete: { [weak self] in self?.deleteMarkdown(id: mdId) },
            onChanged: { [weak self] in self?.scheduleSave() }
        )
        panel.contentView = NSHostingView(rootView: view)
        registerObservers(id: mdId, panel: panel)
        panel.orderFront(nil)
        windows[mdId] = panel
        lastAppliedFrames[mdId] = panel.frame
    }

    private func showBrowserWindow(_ br: DesktopBrowser) {
        guard windows[br.id] == nil else { return }
        let panel = makePanel(
            rect: CGRect(x: br.x, y: br.y, width: br.width, height: br.height),
            minSize: NSSize(width: DesktopBrowser.minWidth, height: DesktopBrowser.minHeight)
        )
        let brId = br.id
        let view = DesktopBrowserView(
            browser: Binding(
                get: { [weak self] in self?.browsers[brId] ?? br },
                set: { [weak self] in self?.browsers[brId] = $0 }
            ),
            onDelete: { [weak self] in self?.deleteBrowser(id: brId) },
            onChanged: { [weak self] in self?.scheduleSave() }
        )
        panel.contentView = NSHostingView(rootView: view)
        registerObservers(id: brId, panel: panel)
        panel.orderFront(nil)
        windows[brId] = panel
        lastAppliedFrames[brId] = panel.frame
    }

    private func registerObservers(id: String, panel: NSPanel) {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.syncWindowSize(id: id, panel: panel) }
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: panel, queue: .main
        ) { [weak self] _ in
            self?.windows.removeValue(forKey: id)
            self?.notes.removeValue(forKey: id)
            self?.markdowns.removeValue(forKey: id)
            self?.browsers.removeValue(forKey: id)
            self?.lastAppliedFrames.removeValue(forKey: id)
            self?.scheduleSave()
        }
    }

    private func syncWindowSize(id: String, panel: NSPanel) {
        guard !isSyncing else { return }
        let frame = panel.frame
        let w = Double(frame.width), h = Double(frame.height)
        if notes[id] != nil { notes[id]?.width = w; notes[id]?.height = h }
        if markdowns[id] != nil { markdowns[id]?.width = w; markdowns[id]?.height = h }
        if browsers[id] != nil { browsers[id]?.width = w; browsers[id]?.height = h }
        scheduleSave()
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard !Task.isCancelled else { return }
            self?.saveAll()
        }
    }

    private func saveAll() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(Array(notes.values)) { try? data.write(to: storageURL, options: .atomic) }
        if let data = try? encoder.encode(Array(markdowns.values)) { try? data.write(to: markdownURL, options: .atomic) }
        if let data = try? encoder.encode(Array(browsers.values)) { try? data.write(to: browserURL, options: .atomic) }
    }

    private func loadAll() {
        if let data = try? Data(contentsOf: storageURL),
           let loaded = try? JSONDecoder().decode([DesktopStickyNote].self, from: data) {
            for n in loaded { notes[n.id] = n }
        }
        if let data = try? Data(contentsOf: markdownURL),
           let loaded = try? JSONDecoder().decode([DesktopMarkdownNote].self, from: data) {
            for n in loaded { markdowns[n.id] = n }
        }
        if let data = try? Data(contentsOf: browserURL),
           let loaded = try? JSONDecoder().decode([DesktopBrowser].self, from: data) {
            for n in loaded { browsers[n.id] = n }
        }
    }
}
