import Foundation
@testable import CanvasWMLib

func runModelsSerializationTests() {
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601

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

    // MARK: - BookmarkedArea round trip
    do {
        let bm = BookmarkedArea(id: "bm1", name: "Area", panX: 100, panY: 200, scale: 1.5)
        let data = try! encoder.encode(bm)
        let decoded = try! decoder.decode(BookmarkedArea.self, from: data)
        assert(decoded.id == "bm1", "BookmarkedArea id")
        assert(decoded.name == "Area", "BookmarkedArea name")
        assertEqualDouble(decoded.panX, 100, message: "BookmarkedArea panX")
        assertEqualDouble(decoded.scale, 1.5, message: "BookmarkedArea scale")
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

    print("Models Serialization Tests: \(_passes) passed, \(_failures) failed")
}
