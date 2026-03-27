import Foundation
@testable import CanvasWMLib

func runCanvasStateTests() {
    // MARK: - StickyNote CRUD

    // addStickyNote creates a note and selects it
    do {
        let state = CanvasState()
        state.addStickyNote(x: 100, y: 200)
        assert(state.stickyNotes.count == 1, "addStickyNote creates one note")
        let note = state.stickyNotes.values.first!
        assertEqualDouble(note.x, 100, message: "addStickyNote x")
        assertEqualDouble(note.y, 200, message: "addStickyNote y")
        assertEqualDouble(note.width, StickyNote.defaultWidth, message: "addStickyNote default width")
        assertEqualDouble(note.height, StickyNote.defaultHeight, message: "addStickyNote default height")
        assert(note.text == "", "addStickyNote empty text")
        assert(state.selectedWidgetId == note.id, "addStickyNote selects the note")
    }

    // deleteStickyNote removes and clears selection
    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0)
        let id = state.stickyNotes.keys.first!
        assert(state.selectedWidgetId == id, "selected before delete")
        state.deleteStickyNote(id: id)
        assert(state.stickyNotes.isEmpty, "deleteStickyNote removes note")
        assert(state.selectedWidgetId == nil, "deleteStickyNote clears selection")
    }

    // moveStickyNote updates position
    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0)
        let id = state.stickyNotes.keys.first!
        state.moveStickyNote(id: id, x: 50, y: 75)
        assertEqualDouble(state.stickyNotes[id]!.x, 50, message: "moveStickyNote x")
        assertEqualDouble(state.stickyNotes[id]!.y, 75, message: "moveStickyNote y")
    }

    // resizeStickyNote clamps to min/max
    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0)
        let id = state.stickyNotes.keys.first!
        state.resizeStickyNote(id: id, width: 10, height: 10)
        assertEqualDouble(state.stickyNotes[id]!.width, StickyNote.minWidth, message: "resizeStickyNote clamp min width")
        assertEqualDouble(state.stickyNotes[id]!.height, StickyNote.minHeight, message: "resizeStickyNote clamp min height")
        state.resizeStickyNote(id: id, width: 9999, height: 9999)
        assertEqualDouble(state.stickyNotes[id]!.width, StickyNote.maxWidth, message: "resizeStickyNote clamp max width")
        assertEqualDouble(state.stickyNotes[id]!.height, StickyNote.maxHeight, message: "resizeStickyNote clamp max height")
    }

    // updateStickyNoteText truncates at maxTextLength
    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0)
        let id = state.stickyNotes.keys.first!
        state.updateStickyNoteText(id: id, text: "hello")
        assert(state.stickyNotes[id]!.text == "hello", "updateStickyNoteText sets text")
        let longText = String(repeating: "a", count: StickyNote.maxTextLength + 100)
        state.updateStickyNoteText(id: id, text: longText)
        assert(state.stickyNotes[id]!.text.count == StickyNote.maxTextLength, "updateStickyNoteText truncates")
    }

    // MARK: - Frame CRUD

    do {
        let state = CanvasState()
        state.addFrame(x: 10, y: 20)
        assert(state.frames.count == 1, "addFrame creates one frame")
        let id = state.frames.keys.first!
        assert(state.selectedWidgetId == id, "addFrame selects")

        state.moveFrame(id: id, x: 30, y: 40)
        assertEqualDouble(state.frames[id]!.x, 30, message: "moveFrame x")
        assertEqualDouble(state.frames[id]!.y, 40, message: "moveFrame y")

        state.resizeFrame(id: id, width: 50, height: 50)
        assertEqualDouble(state.frames[id]!.width, Frame.minWidth, message: "resizeFrame clamp min width")
        assertEqualDouble(state.frames[id]!.height, Frame.minHeight, message: "resizeFrame clamp min height")

        state.resizeFrame(id: id, width: 99999, height: 99999)
        assertEqualDouble(state.frames[id]!.width, Frame.maxWidth, message: "resizeFrame clamp max width")
        assertEqualDouble(state.frames[id]!.height, Frame.maxHeight, message: "resizeFrame clamp max height")

        state.updateFrameLabel(id: id, label: "Test Label")
        assert(state.frames[id]!.label == "Test Label", "updateFrameLabel")

        state.updateFrameColors(id: id, borderColor: "#FF0000", backgroundColor: "#00FF00")
        assert(state.frames[id]!.borderColor == "#FF0000", "updateFrameColors border")
        assert(state.frames[id]!.backgroundColor == "#00FF00", "updateFrameColors bg")

        state.deleteFrame(id: id)
        assert(state.frames.isEmpty, "deleteFrame removes")
        assert(state.selectedWidgetId == nil, "deleteFrame clears selection")
    }

    // MARK: - Drawing CRUD

    do {
        let state = CanvasState()
        state.startDrawing(at: DrawingPoint(x: 0, y: 0))
        assert(state.drawings.count == 1, "startDrawing creates one drawing")
        assert(state.currentDrawingId != nil, "startDrawing sets currentDrawingId")

        state.continueDrawing(point: DrawingPoint(x: 10, y: 10))
        state.continueDrawing(point: DrawingPoint(x: 20, y: 20))
        let id = state.currentDrawingId!
        assert(state.drawings[id]!.points.count == 3, "continueDrawing adds points")

        state.finishDrawing()
        assert(state.currentDrawingId == nil, "finishDrawing clears currentDrawingId")

        state.deleteDrawing(id: id)
        assert(state.drawings.isEmpty, "deleteDrawing removes")
    }

    // continueDrawing does nothing without active drawing
    do {
        let state = CanvasState()
        state.continueDrawing(point: DrawingPoint(x: 10, y: 10))
        assert(state.drawings.isEmpty, "continueDrawing without start does nothing")
    }

    // MARK: - Image CRUD

    do {
        let state = CanvasState()
        state.addImage(x: 50, y: 60, src: "file:///test.png", originalWidth: 1200, originalHeight: 900)
        assert(state.images.count == 1, "addImage creates one")
        let id = state.images.keys.first!
        assertEqualDouble(state.images[id]!.width, 800, message: "addImage clamps large width to 800")
        assertEqualDouble(state.images[id]!.height, 600, message: "addImage clamps large height to 600")

        state.moveImage(id: id, x: 100, y: 200)
        assertEqualDouble(state.images[id]!.x, 100, message: "moveImage x")

        state.resizeImage(id: id, width: 10, height: 10)
        assertEqualDouble(state.images[id]!.width, 50, message: "resizeImage clamp min width")
        assertEqualDouble(state.images[id]!.height, 50, message: "resizeImage clamp min height")

        state.deleteImage(id: id)
        assert(state.images.isEmpty, "deleteImage removes")
    }

    // addImage with zero original size uses defaults
    do {
        let state = CanvasState()
        state.addImage(x: 0, y: 0, src: "test.png")
        let img = state.images.values.first!
        assertEqualDouble(img.width, ImageModel.defaultWidth, message: "addImage default width")
        assertEqualDouble(img.height, ImageModel.defaultHeight, message: "addImage default height")
    }

    // MARK: - Markdown CRUD

    do {
        let state = CanvasState()
        state.addMarkdown(x: 10, y: 20, text: "# Hello")
        assert(state.markdowns.count == 1, "addMarkdown creates one")
        let id = state.markdowns.keys.first!
        assert(state.markdowns[id]!.text == "# Hello", "addMarkdown text")

        state.moveMarkdown(id: id, x: 30, y: 40)
        assertEqualDouble(state.markdowns[id]!.x, 30, message: "moveMarkdown x")

        state.resizeMarkdown(id: id, width: 50, height: 20)
        assertEqualDouble(state.markdowns[id]!.width, MarkdownNote.minWidth, message: "resizeMarkdown clamp min width")
        assertEqualDouble(state.markdowns[id]!.height, MarkdownNote.minHeight, message: "resizeMarkdown clamp min height")

        let longText = String(repeating: "x", count: MarkdownNote.maxTextLength + 100)
        state.updateMarkdownText(id: id, text: longText)
        assert(state.markdowns[id]!.text.count == MarkdownNote.maxTextLength, "updateMarkdownText truncates")

        state.deleteMarkdown(id: id)
        assert(state.markdowns.isEmpty, "deleteMarkdown removes")
    }

    // MARK: - Terminal CRUD

    do {
        let state = CanvasState()
        let id = state.addTerminal(x: 10, y: 20)
        assert(id != nil, "addTerminal returns id")
        assert(state.terminals.count == 1, "addTerminal creates one")

        state.moveTerminal(id: id!, x: 30, y: 40)
        assertEqualDouble(state.terminals[id!]!.x, 30, message: "moveTerminal x")

        state.resizeTerminal(id: id!, width: 50, height: 20)
        assertEqualDouble(state.terminals[id!]!.width, TerminalState.minWidth, message: "resizeTerminal clamp min width")
        assertEqualDouble(state.terminals[id!]!.height, TerminalState.minHeight, message: "resizeTerminal clamp min height")

        state.markTerminalDead(id: id!)
        assert(state.terminals[id!]!.isAlive == false, "markTerminalDead")

        state.deleteTerminal(id: id!)
        assert(state.terminals.isEmpty, "deleteTerminal removes")
    }

    // addTerminal enforces max limit
    do {
        let state = CanvasState()
        for i in 0..<TerminalState.maxTerminals {
            let result = state.addTerminal(x: Double(i * 10), y: 0)
            assert(result != nil, "addTerminal \(i) within limit")
        }
        let overflow = state.addTerminal(x: 0, y: 0)
        assert(overflow == nil, "addTerminal returns nil at max")
        assert(state.terminals.count == TerminalState.maxTerminals, "terminals at max count")
    }

    // MARK: - Browser CRUD

    do {
        let state = CanvasState()
        let id = state.addBrowser(x: 10, y: 20, url: "https://example.com")
        assert(id != nil, "addBrowser returns id")
        let browser = state.browsers[id!]!
        assert(browser.url == "https://example.com", "addBrowser url")

        state.moveBrowser(id: id!, x: 30, y: 40)
        assertEqualDouble(state.browsers[id!]!.x, 30, message: "moveBrowser x")

        state.resizeBrowser(id: id!, width: 50, height: 20)
        assertEqualDouble(state.browsers[id!]!.width, BrowserState.minWidth, message: "resizeBrowser clamp min width")
        assertEqualDouble(state.browsers[id!]!.height, BrowserState.minHeight, message: "resizeBrowser clamp min height")

        state.updateBrowserUrl(id: id!, url: "https://test.com")
        assert(state.browsers[id!]!.url == "https://test.com", "updateBrowserUrl")

        state.deleteBrowser(id: id!)
        assert(state.browsers.isEmpty, "deleteBrowser removes")
    }

    // addBrowser enforces max limit
    do {
        let state = CanvasState()
        for i in 0..<BrowserState.maxBrowsers {
            let result = state.addBrowser(x: Double(i * 10), y: 0)
            assert(result != nil, "addBrowser \(i) within limit")
        }
        let overflow = state.addBrowser(x: 0, y: 0)
        assert(overflow == nil, "addBrowser returns nil at max")
    }

    // MARK: - FileManager CRUD

    do {
        let state = CanvasState()
        state.addFileManager(x: 10, y: 20, rootPath: "/tmp")
        assert(state.fileManagers.count == 1, "addFileManager creates one")
        let id = state.fileManagers.keys.first!
        assert(state.fileManagers[id]!.rootPath == "/tmp", "addFileManager rootPath")

        state.moveFileManager(id: id, x: 30, y: 40)
        assertEqualDouble(state.fileManagers[id]!.x, 30, message: "moveFileManager x")

        state.resizeFileManager(id: id, width: 50, height: 20)
        assertEqualDouble(state.fileManagers[id]!.width, FileManagerState.minWidth, message: "resizeFileManager clamp min width")
        assertEqualDouble(state.fileManagers[id]!.height, FileManagerState.minHeight, message: "resizeFileManager clamp min height")

        state.toggleFileManagerDir(id: id, dirPath: "/tmp/a")
        assert(state.fileManagers[id]!.expandedDirs.contains("/tmp/a"), "toggleFileManagerDir expand")
        state.toggleFileManagerDir(id: id, dirPath: "/tmp/a")
        assert(!state.fileManagers[id]!.expandedDirs.contains("/tmp/a"), "toggleFileManagerDir collapse")

        state.deleteFileManager(id: id)
        assert(state.fileManagers.isEmpty, "deleteFileManager removes")
    }

    // MARK: - Z-Index & Selection

    // bringToFront updates zIndex for each widget type
    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0)
        let noteId = state.stickyNotes.keys.first!
        let oldZ = state.stickyNotes[noteId]!.zIndex
        state.addStickyNote(x: 100, y: 100) // creates another, advances nextZ
        state.bringToFront(id: noteId)
        assert(state.stickyNotes[noteId]!.zIndex > oldZ, "bringToFront increases zIndex")
        assert(state.selectedWidgetId == noteId, "bringToFront selects widget")
    }

    // nextZIndex increments correctly
    do {
        let state = CanvasState()
        assert(state.nextZIndex == 1, "initial nextZIndex is 1")
        state.addStickyNote(x: 0, y: 0)
        assert(state.nextZIndex == 2, "nextZIndex after one add")
        state.addFrame(x: 0, y: 0)
        assert(state.nextZIndex == 3, "nextZIndex after two adds")
    }

    // MARK: - widgetAt

    do {
        let state = CanvasState()
        state.addStickyNote(x: 100, y: 100) // default 300x150
        let noteId = state.stickyNotes.keys.first!
        // Inside the note
        let hit = state.widgetAt(worldX: 200, worldY: 150)
        assert(hit == noteId, "widgetAt finds note inside bounds")
        // Outside
        let miss = state.widgetAt(worldX: 500, worldY: 500)
        assert(miss == nil, "widgetAt returns nil outside")
    }

    // widgetAt returns topmost (highest zIndex)
    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0) // z=1
        state.addFrame(x: 0, y: 0)      // z=2, overlapping
        let frameId = state.frames.keys.first!
        let hit = state.widgetAt(worldX: 50, worldY: 50)
        assert(hit == frameId, "widgetAt returns topmost widget")
    }

    // MARK: - widgetOrigin

    do {
        let state = CanvasState()
        state.addStickyNote(x: 42, y: 84)
        let id = state.stickyNotes.keys.first!
        let origin = state.widgetOrigin(id: id)
        assert(origin != nil, "widgetOrigin finds note")
        assertEqualDouble(origin!.x, 42, message: "widgetOrigin x")
        assertEqualDouble(origin!.y, 84, message: "widgetOrigin y")
        assert(state.widgetOrigin(id: "nonexistent") == nil, "widgetOrigin nil for bad id")
    }

    // MARK: - moveWidget (generic)

    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0)
        let id = state.stickyNotes.keys.first!
        state.moveWidget(id: id, x: 999, y: 888)
        assertEqualDouble(state.stickyNotes[id]!.x, 999, message: "moveWidget x")
        assertEqualDouble(state.stickyNotes[id]!.y, 888, message: "moveWidget y")
    }

    // MARK: - deleteSelected

    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0)
        let id = state.stickyNotes.keys.first!
        state.selectedWidgetId = id
        state.deleteSelected()
        assert(state.stickyNotes.isEmpty, "deleteSelected removes note")
        assert(state.selectedWidgetId == nil, "deleteSelected clears selection")
    }

    // deleteSelected with no selection does nothing
    do {
        let state = CanvasState()
        state.addStickyNote(x: 0, y: 0)
        state.selectedWidgetId = nil
        state.deleteSelected()
        assert(state.stickyNotes.count == 1, "deleteSelected with nil does nothing")
    }

    // MARK: - toCanvasData / loadFromCanvasData round trip

    do {
        let state = CanvasState()
        state.scale = 2.0; state.panX = 100; state.panY = -50
        state.addStickyNote(x: 10, y: 20)
        state.addFrame(x: 30, y: 40)
        state.addMarkdown(x: 50, y: 60)
        state.addBookmarkedArea(name: "Test")
        let data = state.toCanvasData()

        let state2 = CanvasState()
        state2.loadFromCanvasData(data)
        assertEqualDouble(state2.scale, 2.0, message: "loadFromCanvasData scale")
        assertEqualDouble(state2.panX, 100, message: "loadFromCanvasData panX")
        assertEqualDouble(state2.panY, -50, message: "loadFromCanvasData panY")
        assert(state2.stickyNotes.count == 1, "loadFromCanvasData stickyNotes")
        assert(state2.frames.count == 1, "loadFromCanvasData frames")
        assert(state2.markdowns.count == 1, "loadFromCanvasData markdowns")
        assert(state2.bookmarkedAreas.count == 1, "loadFromCanvasData bookmarkedAreas")
        assert(state2.selectedWidgetId == nil, "loadFromCanvasData clears selection")
    }

    // MARK: - reset

    do {
        let state = CanvasState()
        state.scale = 3.0; state.panX = 500; state.panY = 500
        state.addStickyNote(x: 0, y: 0)
        state.addFrame(x: 0, y: 0)
        state.addMarkdown(x: 0, y: 0)
        state.addBookmarkedArea(name: "X")
        state.reset()
        assertEqualDouble(state.scale, 1.0, message: "reset scale")
        assertEqualDouble(state.panX, 0, message: "reset panX")
        assertEqualDouble(state.panY, 0, message: "reset panY")
        assert(state.stickyNotes.isEmpty, "reset stickyNotes")
        assert(state.frames.isEmpty, "reset frames")
        assert(state.markdowns.isEmpty, "reset markdowns")
        assert(state.bookmarkedAreas.isEmpty, "reset bookmarkedAreas")
        assert(state.selectedWidgetId == nil, "reset selection")
        assert(state.nextZIndex == 1, "reset nextZIndex")
    }

    print("CanvasState Tests: \(_passes) passed, \(_failures) failed")
}
