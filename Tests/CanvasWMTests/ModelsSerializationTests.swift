import Foundation
@testable import CanvasWMLib

func runModelsSerializationTests() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

    // MARK: - StickyNote round trip
    do {
        let note = StickyNote(id: "n1", x: 10, y: 20, width: 300, height: 150, text: "hello", fontSize: 14, zIndex: 5)
        let data = try! encoder.encode(note)
        let decoded = try! decoder.decode(StickyNote.self, from: data)
        assert(decoded.id == "n1", "StickyNote id")
        assertEqualDouble(decoded.x, 10, message: "StickyNote x")
        assertEqualDouble(decoded.y, 20, message: "StickyNote y")
        assert(decoded.text == "hello", "StickyNote text")
        assert(decoded.zIndex == 5, "StickyNote zIndex")
    }

    // MARK: - Frame round trip
    do {
        let frame = Frame(id: "f1", x: 100, y: 200, label: "Group A", borderColor: "#FF0000", backgroundColor: "#00FF0010", zIndex: 3)
        let data = try! encoder.encode(frame)
        let decoded = try! decoder.decode(Frame.self, from: data)
        assert(decoded.id == "f1", "Frame id")
        assert(decoded.label == "Group A", "Frame label")
        assert(decoded.borderColor == "#FF0000", "Frame borderColor")
    }

    // MARK: - Drawing round trip
    do {
        let drawing = Drawing(id: "d1", points: [DrawingPoint(x: 0, y: 0), DrawingPoint(x: 10, y: 20)],
                              color: "#000000", strokeWidth: 3.0, zIndex: 1)
        let data = try! encoder.encode(drawing)
        let decoded = try! decoder.decode(Drawing.self, from: data)
        assert(decoded.id == "d1", "Drawing id")
        assert(decoded.points.count == 2, "Drawing points count")
        assertEqualDouble(decoded.strokeWidth, 3.0, message: "Drawing strokeWidth")
    }

    // MARK: - ImageModel round trip
    do {
        let img = ImageModel(id: "i1", x: 50, y: 60, width: 400, height: 300, src: "file:///img.png",
                             originalWidth: 1200, originalHeight: 900, zIndex: 2)
        let data = try! encoder.encode(img)
        let decoded = try! decoder.decode(ImageModel.self, from: data)
        assert(decoded.id == "i1", "ImageModel id")
        assert(decoded.src == "file:///img.png", "ImageModel src")
        assertEqualDouble(decoded.originalWidth, 1200, message: "ImageModel originalWidth")
    }

    // MARK: - MarkdownNote round trip
    do {
        let md = MarkdownNote(id: "m1", x: 10, y: 20, text: "# Title", zIndex: 4)
        let data = try! encoder.encode(md)
        let decoded = try! decoder.decode(MarkdownNote.self, from: data)
        assert(decoded.id == "m1", "MarkdownNote id")
        assert(decoded.text == "# Title", "MarkdownNote text")
    }

    // MARK: - TerminalState round trip
    do {
        let term = TerminalState(id: "t1", x: 0, y: 0, themeKey: "dracula", zIndex: 1)
        let data = try! encoder.encode(term)
        let decoded = try! decoder.decode(TerminalState.self, from: data)
        assert(decoded.id == "t1", "TerminalState id")
        assert(decoded.themeKey == "dracula", "TerminalState themeKey")
        assert(decoded.isAlive == true, "TerminalState default isAlive")
    }

    // MARK: - BrowserState round trip
    do {
        let browser = BrowserState(id: "b1", x: 100, y: 200, url: "https://example.com", zIndex: 7)
        let data = try! encoder.encode(browser)
        let decoded = try! decoder.decode(BrowserState.self, from: data)
        assert(decoded.id == "b1", "BrowserState id")
        assert(decoded.url == "https://example.com", "BrowserState url")
    }

    // MARK: - FileManagerState round trip
    do {
        let fm = FileManagerState(id: "fm1", x: 0, y: 0, rootPath: "/Users/test", expandedDirs: ["/Users/test/Documents"], zIndex: 2)
        let data = try! encoder.encode(fm)
        let decoded = try! decoder.decode(FileManagerState.self, from: data)
        assert(decoded.id == "fm1", "FileManagerState id")
        assert(decoded.rootPath == "/Users/test", "FileManagerState rootPath")
        assert(decoded.expandedDirs.contains("/Users/test/Documents"), "FileManagerState expandedDirs")
    }

    // MARK: - DesktopStickyNote round trip
    do {
        let note = DesktopStickyNote(id: "ds1", text: "Desktop note", x: 200, y: 300, colorName: "green")
        let data = try! encoder.encode(note)
        let decoded = try! decoder.decode(DesktopStickyNote.self, from: data)
        assert(decoded.id == "ds1", "DesktopStickyNote id")
        assert(decoded.text == "Desktop note", "DesktopStickyNote text")
        assert(decoded.colorName == "green", "DesktopStickyNote colorName")
    }

    // MARK: - DesktopMarkdownNote round trip
    do {
        let md = DesktopMarkdownNote(id: "dm1", text: "# Desktop MD")
        let data = try! encoder.encode(md)
        let decoded = try! decoder.decode(DesktopMarkdownNote.self, from: data)
        assert(decoded.id == "dm1", "DesktopMarkdownNote id")
        assert(decoded.text == "# Desktop MD", "DesktopMarkdownNote text")
    }

    // MARK: - DesktopBrowser round trip
    do {
        let browser = DesktopBrowser(id: "db1", url: "https://test.com")
        let data = try! encoder.encode(browser)
        let decoded = try! decoder.decode(DesktopBrowser.self, from: data)
        assert(decoded.id == "db1", "DesktopBrowser id")
        assert(decoded.url == "https://test.com", "DesktopBrowser url")
    }

    // MARK: - Workspace round trip
    do {
        let ws = Workspace(id: "ws1", name: "My Workspace")
        let data = try! encoder.encode(ws)
        let decoded = try! decoder.decode(Workspace.self, from: data)
        assert(decoded.id == "ws1", "Workspace id")
        assert(decoded.name == "My Workspace", "Workspace name")
    }

    // MARK: - Full CanvasData round trip with all widget types
    do {
        let note = StickyNote(id: "n1", x: 0, y: 0, width: 300, height: 150, text: "t", fontSize: 14, zIndex: 1)
        let frame = Frame(id: "f1", x: 0, y: 0, zIndex: 2)
        let drawing = Drawing(id: "d1", points: [DrawingPoint(x: 0, y: 0)], zIndex: 3)
        let img = ImageModel(id: "i1", x: 0, y: 0, src: "test", zIndex: 4)
        let md = MarkdownNote(id: "m1", x: 0, y: 0, text: "md", zIndex: 5)
        let term = TerminalState(id: "t1", x: 0, y: 0, zIndex: 6)
        let browser = BrowserState(id: "b1", x: 0, y: 0, zIndex: 7)
        let fm = FileManagerState(id: "fm1", x: 0, y: 0, zIndex: 8)
        let bm = BookmarkedArea(id: "bm1", name: "Area", panX: 100, panY: 200, scale: 1.5)

        let canvas = CanvasData(
            scale: 2.0, panX: 50, panY: -30,
            stickyNotes: ["n1": note], frames: ["f1": frame], drawings: ["d1": drawing],
            images: ["i1": img], markdowns: ["m1": md], terminals: ["t1": term],
            browsers: ["b1": browser], fileManagers: ["fm1": fm], bookmarkedAreas: ["bm1": bm],
            nextZIndex: 9
        )

        let data = try! encoder.encode(canvas)
        let decoded = try! decoder.decode(CanvasData.self, from: data)
        assertEqualDouble(decoded.scale, 2.0, message: "CanvasData scale")
        assertEqualDouble(decoded.panX, 50, message: "CanvasData panX")
        assert(decoded.stickyNotes.count == 1, "CanvasData stickyNotes")
        assert(decoded.frames.count == 1, "CanvasData frames")
        assert(decoded.drawings.count == 1, "CanvasData drawings")
        assert(decoded.images.count == 1, "CanvasData images")
        assert(decoded.markdowns.count == 1, "CanvasData markdowns")
        assert(decoded.terminals.count == 1, "CanvasData terminals")
        assert(decoded.browsers.count == 1, "CanvasData browsers")
        assert(decoded.fileManagers.count == 1, "CanvasData fileManagers")
        assert(decoded.bookmarkedAreas.count == 1, "CanvasData bookmarkedAreas")
        assert(decoded.nextZIndex == 9, "CanvasData nextZIndex")
    }

    // MARK: - ManagedWindow round trip
    do {
        let win = ManagedWindow(x: 100, y: 200, width: 800, height: 600,
                                windowId: 42, ownerPid: 123, ownerName: "Test", windowTitle: "Title", zIndex: 5)
        let data = try! encoder.encode(win)
        let decoded = try! decoder.decode(ManagedWindow.self, from: data)
        assert(decoded.ownerName == "Test", "ManagedWindow ownerName")
        assert(decoded.windowTitle == "Title", "ManagedWindow windowTitle")
        assert(decoded.windowId == 42, "ManagedWindow windowId")
        assert(decoded.zIndex == 5, "ManagedWindow zIndex")
    }

    // MARK: - WidgetKind / ToolMode serialization
    do {
        let kinds: [WidgetKind] = [.stickyNote, .terminal, .browser, .frame, .image, .markdown, .fileManager, .drawing]
        for kind in kinds {
            let data = try! encoder.encode(kind)
            let decoded = try! decoder.decode(WidgetKind.self, from: data)
            assert(decoded == kind, "WidgetKind round trip \(kind.rawValue)")
        }
    }

    do {
        let modes: [ToolMode] = [.select, .pen]
        for mode in modes {
            let data = try! encoder.encode(mode)
            let decoded = try! decoder.decode(ToolMode.self, from: data)
            assert(decoded == mode, "ToolMode round trip \(mode.rawValue)")
        }
    }

    print("Models Serialization Tests: \(_passes) passed, \(_failures) failed")
}
