import Foundation

// MARK: - Desktop Sticky Note (floating window)

public struct DesktopStickyNote: Codable, Identifiable {
    public let id: String
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var colorName: String

    public static let defaultWidth: Double = 200
    public static let defaultHeight: Double = 200
    public static let minWidth: Double = 120
    public static let minHeight: Double = 80

    public static let colors: [String: (bg: String, titleBg: String)] = [
        "yellow": ("#FFF9C4", "#FFF176"),
        "green":  ("#C8E6C9", "#81C784"),
        "blue":   ("#BBDEFB", "#64B5F6"),
        "pink":   ("#F8BBD0", "#F06292"),
        "orange": ("#FFE0B2", "#FFB74D"),
    ]

    public init(id: String = UUID().uuidString, text: String = "", x: Double = 100, y: Double = 100,
                width: Double = defaultWidth, height: Double = defaultHeight, colorName: String = "yellow") {
        self.id = id; self.text = text; self.x = x; self.y = y
        self.width = width; self.height = height; self.colorName = colorName
    }
}

// MARK: - Desktop Markdown Viewer (floating window)

public struct DesktopMarkdownNote: Codable, Identifiable {
    public let id: String
    public var text: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public static let defaultWidth: Double = 400
    public static let defaultHeight: Double = 300
    public static let minWidth: Double = 200
    public static let minHeight: Double = 150

    public init(id: String = UUID().uuidString, text: String = "# New Note\n\nStart writing...",
                x: Double = 100, y: Double = 100,
                width: Double = defaultWidth, height: Double = defaultHeight) {
        self.id = id; self.text = text; self.x = x; self.y = y
        self.width = width; self.height = height
    }
}

// MARK: - Desktop Browser (floating window)

public struct DesktopBrowser: Codable, Identifiable {
    public let id: String
    public var url: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public static let defaultWidth: Double = 600
    public static let defaultHeight: Double = 400
    public static let minWidth: Double = 300
    public static let minHeight: Double = 200

    public init(id: String = UUID().uuidString, url: String = "https://www.google.com",
                x: Double = 100, y: Double = 100,
                width: Double = defaultWidth, height: Double = defaultHeight) {
        self.id = id; self.url = url; self.x = x; self.y = y
        self.width = width; self.height = height
    }
}

// MARK: - BookmarkedArea

public struct BookmarkedArea: Codable, Identifiable {
    public let id: String
    public var name: String
    public var panX: Double
    public var panY: Double
    public var scale: Double
    public var createdAt: Date

    public init(id: String = UUID().uuidString, name: String, panX: Double, panY: Double, scale: Double, createdAt: Date = .now) {
        self.id = id; self.name = name; self.panX = panX; self.panY = panY
        self.scale = scale; self.createdAt = createdAt
    }
}
