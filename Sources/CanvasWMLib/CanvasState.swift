import Foundation
import Observation

@Observable
public final class CanvasState {
    public var scale: Double = 1.0
    public var panX: Double = 0
    public var panY: Double = 0
    public var stickyNotes: [String: StickyNote] = [:]
    public var frames: [String: Frame] = [:]
    public var drawings: [String: Drawing] = [:]
    public var images: [String: ImageModel] = [:]
    public var markdowns: [String: MarkdownNote] = [:]
    public var terminals: [String: TerminalState] = [:]
    public var browsers: [String: BrowserState] = [:]
    public var fileManagers: [String: FileManagerState] = [:]
    public var selectedWidgetId: String? = nil
    public var nextZIndex: Int = 1
    public var toolMode: ToolMode = .select
    public var drawingColor: String = "#000000"
    public var drawingStrokeWidth: Double = 2.0
    public var currentDrawingId: String? = nil
    public init() {}

    private func nextZ() -> Int { let z = nextZIndex; nextZIndex += 1; return z }

    // MARK: - StickyNote CRUD

    public func addStickyNote(x: Double, y: Double) {
        let id = UUID().uuidString
        stickyNotes[id] = StickyNote(id: id, x: x, y: y, width: StickyNote.defaultWidth, height: StickyNote.defaultHeight,
                                      text: "", fontSize: StickyNote.defaultFontSize, zIndex: nextZ())
        selectedWidgetId = id
    }

    public func deleteStickyNote(id: String) {
        stickyNotes.removeValue(forKey: id)
        if selectedWidgetId == id { selectedWidgetId = nil }
    }

    public func moveStickyNote(id: String, x: Double, y: Double) { stickyNotes[id]?.x = x; stickyNotes[id]?.y = y }

    public func resizeStickyNote(id: String, width: Double, height: Double) {
        stickyNotes[id]?.width = min(max(width, StickyNote.minWidth), StickyNote.maxWidth)
        stickyNotes[id]?.height = min(max(height, StickyNote.minHeight), StickyNote.maxHeight)
    }

    public func updateStickyNoteText(id: String, text: String) {
        stickyNotes[id]?.text = String(text.prefix(StickyNote.maxTextLength))
    }

    // MARK: - Frame CRUD

    public func addFrame(x: Double, y: Double) {
        let id = UUID().uuidString
        frames[id] = Frame(id: id, x: x, y: y, zIndex: nextZ())
        selectedWidgetId = id
    }

    public func deleteFrame(id: String) { frames.removeValue(forKey: id); if selectedWidgetId == id { selectedWidgetId = nil } }
    public func moveFrame(id: String, x: Double, y: Double) { frames[id]?.x = x; frames[id]?.y = y }

    public func resizeFrame(id: String, width: Double, height: Double) {
        frames[id]?.width = min(max(width, Frame.minWidth), Frame.maxWidth)
        frames[id]?.height = min(max(height, Frame.minHeight), Frame.maxHeight)
    }

    public func updateFrameLabel(id: String, label: String) { frames[id]?.label = label }
    public func updateFrameColors(id: String, borderColor: String, backgroundColor: String) {
        frames[id]?.borderColor = borderColor; frames[id]?.backgroundColor = backgroundColor
    }

    // MARK: - Drawing CRUD

    public func startDrawing(at point: DrawingPoint) {
        let id = UUID().uuidString
        drawings[id] = Drawing(id: id, points: [point], color: drawingColor, strokeWidth: drawingStrokeWidth, zIndex: nextZ())
        currentDrawingId = id
    }

    public func continueDrawing(point: DrawingPoint) {
        guard let id = currentDrawingId else { return }
        drawings[id]?.points.append(point)
    }

    public func finishDrawing() {
        if let id = currentDrawingId, let drawing = drawings[id] {
            drawings[id]?.points = PathSimplify.simplify(drawing.points, tolerance: 1.5)
        }
        currentDrawingId = nil
    }

    public func deleteDrawing(id: String) { drawings.removeValue(forKey: id) }

    // MARK: - Image CRUD

    public func addImage(x: Double, y: Double, src: String, originalWidth: Double = 0, originalHeight: Double = 0) {
        let id = UUID().uuidString
        let w = originalWidth > 0 ? min(originalWidth, 800) : ImageModel.defaultWidth
        let h = originalHeight > 0 ? min(originalHeight, 600) : ImageModel.defaultHeight
        images[id] = ImageModel(id: id, x: x, y: y, width: w, height: h, src: src,
                                originalWidth: originalWidth, originalHeight: originalHeight, zIndex: nextZ())
        selectedWidgetId = id
    }

    public func deleteImage(id: String) { images.removeValue(forKey: id); if selectedWidgetId == id { selectedWidgetId = nil } }
    public func moveImage(id: String, x: Double, y: Double) { images[id]?.x = x; images[id]?.y = y }
    public func resizeImage(id: String, width: Double, height: Double) { images[id]?.width = max(width, 50); images[id]?.height = max(height, 50) }

    // MARK: - Markdown CRUD

    public func addMarkdown(x: Double, y: Double, text: String = "") {
        let id = UUID().uuidString
        markdowns[id] = MarkdownNote(id: id, x: x, y: y, text: text, zIndex: nextZ())
        selectedWidgetId = id
    }

    public func deleteMarkdown(id: String) { markdowns.removeValue(forKey: id); if selectedWidgetId == id { selectedWidgetId = nil } }
    public func moveMarkdown(id: String, x: Double, y: Double) { markdowns[id]?.x = x; markdowns[id]?.y = y }

    public func resizeMarkdown(id: String, width: Double, height: Double) {
        markdowns[id]?.width = max(width, MarkdownNote.minWidth)
        markdowns[id]?.height = max(height, MarkdownNote.minHeight)
    }

    public func updateMarkdownText(id: String, text: String) {
        markdowns[id]?.text = String(text.prefix(MarkdownNote.maxTextLength))
        markdowns[id]?.updatedAt = .now
    }

    // MARK: - Terminal CRUD

    public func addTerminal(x: Double, y: Double) -> String? {
        guard terminals.count < TerminalState.maxTerminals else { return nil }
        let id = UUID().uuidString
        terminals[id] = TerminalState(id: id, x: x, y: y, zIndex: nextZ())
        selectedWidgetId = id
        return id
    }

    public func deleteTerminal(id: String) { terminals.removeValue(forKey: id); if selectedWidgetId == id { selectedWidgetId = nil } }
    public func moveTerminal(id: String, x: Double, y: Double) { terminals[id]?.x = x; terminals[id]?.y = y }

    public func resizeTerminal(id: String, width: Double, height: Double) {
        terminals[id]?.width = max(width, TerminalState.minWidth)
        terminals[id]?.height = max(height, TerminalState.minHeight)
    }

    public func markTerminalDead(id: String) { terminals[id]?.isAlive = false }

    // MARK: - Browser CRUD

    public func addBrowser(x: Double, y: Double, url: String = "https://www.google.com") -> String? {
        guard browsers.count < BrowserState.maxBrowsers else { return nil }
        let id = UUID().uuidString
        browsers[id] = BrowserState(id: id, x: x, y: y, url: url, zIndex: nextZ())
        selectedWidgetId = id
        return id
    }

    public func deleteBrowser(id: String) { browsers.removeValue(forKey: id); if selectedWidgetId == id { selectedWidgetId = nil } }
    public func moveBrowser(id: String, x: Double, y: Double) { browsers[id]?.x = x; browsers[id]?.y = y }

    public func resizeBrowser(id: String, width: Double, height: Double) {
        browsers[id]?.width = max(width, BrowserState.minWidth)
        browsers[id]?.height = max(height, BrowserState.minHeight)
    }

    public func updateBrowserUrl(id: String, url: String) { browsers[id]?.url = url }

    // MARK: - FileManager CRUD

    public func addFileManager(x: Double, y: Double, rootPath: String = "~") {
        let id = UUID().uuidString
        fileManagers[id] = FileManagerState(id: id, x: x, y: y, rootPath: rootPath, zIndex: nextZ())
        selectedWidgetId = id
    }

    public func deleteFileManager(id: String) { fileManagers.removeValue(forKey: id); if selectedWidgetId == id { selectedWidgetId = nil } }
    public func moveFileManager(id: String, x: Double, y: Double) { fileManagers[id]?.x = x; fileManagers[id]?.y = y }

    public func resizeFileManager(id: String, width: Double, height: Double) {
        fileManagers[id]?.width = max(width, FileManagerState.minWidth)
        fileManagers[id]?.height = max(height, FileManagerState.minHeight)
    }

    public func toggleFileManagerDir(id: String, dirPath: String) {
        if fileManagers[id]?.expandedDirs.contains(dirPath) == true {
            fileManagers[id]?.expandedDirs.remove(dirPath)
        } else {
            fileManagers[id]?.expandedDirs.insert(dirPath)
        }
    }

    // MARK: - Generic

    public func bringToFront(id: String) {
        if stickyNotes[id] != nil { stickyNotes[id]?.zIndex = nextZ() }
        else if frames[id] != nil { frames[id]?.zIndex = nextZ() }
        else if images[id] != nil { images[id]?.zIndex = nextZ() }
        else if markdowns[id] != nil { markdowns[id]?.zIndex = nextZ() }
        else if terminals[id] != nil { terminals[id]?.zIndex = nextZ() }
        else if browsers[id] != nil { browsers[id]?.zIndex = nextZ() }
        else if fileManagers[id] != nil { fileManagers[id]?.zIndex = nextZ() }
        selectedWidgetId = id
    }

    /// Returns the ID of the topmost widget at the given world coordinate, or nil.
    public func widgetAt(worldX: Double, worldY: Double) -> String? {
        var best: (id: String, z: Int)? = nil
        func check(_ id: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ z: Int) {
            if worldX >= x && worldX <= x + w && worldY >= y && worldY <= y + h {
                if best == nil || z > best!.z { best = (id, z) }
            }
        }
        for (_, n) in stickyNotes { check(n.id, n.x, n.y, n.width, n.height, n.zIndex) }
        for (_, f) in frames { check(f.id, f.x, f.y, f.width, f.height, f.zIndex) }
        for (_, i) in images { check(i.id, i.x, i.y, i.width, i.height, i.zIndex) }
        for (_, m) in markdowns { check(m.id, m.x, m.y, m.width, m.height, m.zIndex) }
        for (_, t) in terminals { check(t.id, t.x, t.y, t.width, t.height, t.zIndex) }
        for (_, b) in browsers { check(b.id, b.x, b.y, b.width, b.height, b.zIndex) }
        for (_, f) in fileManagers { check(f.id, f.x, f.y, f.width, f.height, f.zIndex) }
        return best?.id
    }

    /// Returns the origin (x, y) of a widget by ID.
    public func widgetOrigin(id: String) -> (x: Double, y: Double)? {
        if let n = stickyNotes[id] { return (n.x, n.y) }
        if let f = frames[id] { return (f.x, f.y) }
        if let i = images[id] { return (i.x, i.y) }
        if let m = markdowns[id] { return (m.x, m.y) }
        if let t = terminals[id] { return (t.x, t.y) }
        if let b = browsers[id] { return (b.x, b.y) }
        if let f = fileManagers[id] { return (f.x, f.y) }
        return nil
    }

    /// Moves any widget type by ID.
    public func moveWidget(id: String, x: Double, y: Double) {
        if stickyNotes[id] != nil { stickyNotes[id]?.x = x; stickyNotes[id]?.y = y }
        else if frames[id] != nil { frames[id]?.x = x; frames[id]?.y = y }
        else if images[id] != nil { images[id]?.x = x; images[id]?.y = y }
        else if markdowns[id] != nil { markdowns[id]?.x = x; markdowns[id]?.y = y }
        else if terminals[id] != nil { terminals[id]?.x = x; terminals[id]?.y = y }
        else if browsers[id] != nil { browsers[id]?.x = x; browsers[id]?.y = y }
        else if fileManagers[id] != nil { fileManagers[id]?.x = x; fileManagers[id]?.y = y }
    }

    public func deleteSelected() {
        guard let id = selectedWidgetId else { return }
        deleteStickyNote(id: id); deleteFrame(id: id); deleteDrawing(id: id)
        deleteImage(id: id); deleteMarkdown(id: id); deleteTerminal(id: id)
        deleteBrowser(id: id); deleteFileManager(id: id)
        selectedWidgetId = nil
    }

    public func toCanvasData() -> CanvasData {
        CanvasData(scale: scale, panX: panX, panY: panY, stickyNotes: stickyNotes, frames: frames,
                   drawings: drawings, images: images, markdowns: markdowns, terminals: terminals,
                   browsers: browsers, fileManagers: fileManagers, nextZIndex: nextZIndex)
    }

    public func loadFromCanvasData(_ data: CanvasData) {
        scale = data.scale; panX = data.panX; panY = data.panY
        stickyNotes = data.stickyNotes; frames = data.frames; drawings = data.drawings
        images = data.images; markdowns = data.markdowns; terminals = data.terminals
        browsers = data.browsers; fileManagers = data.fileManagers
        nextZIndex = data.nextZIndex; selectedWidgetId = nil
    }

    public func reset() {
        scale = 1.0; panX = 0; panY = 0
        stickyNotes = [:]; frames = [:]; drawings = [:]; images = [:]; markdowns = [:]
        terminals = [:]; browsers = [:]; fileManagers = [:]
        selectedWidgetId = nil; nextZIndex = 1; toolMode = .select
    }
}
