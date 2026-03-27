import Foundation

// MARK: - Widget Kind

public enum WidgetKind: String, Codable {
    case stickyNote, terminal, browser, frame, image, markdown, fileManager, drawing
}

public enum ToolMode: String, Codable {
    case select, pen
}

// MARK: - StickyNote

public struct StickyNote: Codable, Identifiable {
    public let id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var text: String
    public var fontSize: Double
    public var zIndex: Int

    public static let defaultWidth: Double = 300
    public static let defaultHeight: Double = 150
    public static let minWidth: Double = 100
    public static let minHeight: Double = 100
    public static let maxWidth: Double = 600
    public static let maxHeight: Double = 400
    public static let defaultFontSize: Double = 14
    public static let minFontSize: Double = 12
    public static let maxFontSize: Double = 28
    public static let maxTextLength: Int = 10_000

    public init(id: String, x: Double, y: Double, width: Double, height: Double, text: String, fontSize: Double, zIndex: Int) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.text = text; self.fontSize = fontSize; self.zIndex = zIndex
    }
}

// MARK: - Frame

public struct Frame: Codable, Identifiable {
    public let id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var label: String
    public var borderColor: String
    public var backgroundColor: String
    public var zIndex: Int

    public static let defaultWidth: Double = 400
    public static let defaultHeight: Double = 300
    public static let minWidth: Double = 100
    public static let minHeight: Double = 100
    public static let maxWidth: Double = 2000
    public static let maxHeight: Double = 2000

    public static let presetColors: [(border: String, bg: String)] = [
        ("#3B82F6", "#3B82F610"), ("#10B981", "#10B98110"),
        ("#F59E0B", "#F59E0B10"), ("#EF4444", "#EF444410"),
        ("#8B5CF6", "#8B5CF610"), ("#6B7280", "#6B728010")
    ]

    public init(id: String, x: Double, y: Double, width: Double = defaultWidth, height: Double = defaultHeight,
                label: String = "Group", borderColor: String = "#3B82F6", backgroundColor: String = "#3B82F610", zIndex: Int) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.label = label; self.borderColor = borderColor; self.backgroundColor = backgroundColor; self.zIndex = zIndex
    }
}

// MARK: - Drawing

public struct DrawingPoint: Codable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

public struct Drawing: Codable, Identifiable {
    public let id: String
    public var points: [DrawingPoint]
    public var color: String
    public var strokeWidth: Double
    public var zIndex: Int
    public var createdAt: Date

    public init(id: String, points: [DrawingPoint] = [], color: String = "#000000", strokeWidth: Double = 2.0, zIndex: Int, createdAt: Date = .now) {
        self.id = id; self.points = points; self.color = color; self.strokeWidth = strokeWidth
        self.zIndex = zIndex; self.createdAt = createdAt
    }
}

// MARK: - ImageModel

public struct ImageModel: Codable, Identifiable {
    public let id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var src: String
    public var originalWidth: Double
    public var originalHeight: Double
    public var zIndex: Int

    public static let defaultWidth: Double = 400
    public static let defaultHeight: Double = 300

    public init(id: String, x: Double, y: Double, width: Double = defaultWidth, height: Double = defaultHeight,
                src: String, originalWidth: Double = 0, originalHeight: Double = 0, zIndex: Int) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.src = src; self.originalWidth = originalWidth; self.originalHeight = originalHeight; self.zIndex = zIndex
    }
}

// MARK: - MarkdownNote

public struct MarkdownNote: Codable, Identifiable {
    public let id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var text: String
    public var zIndex: Int
    public var createdAt: Date
    public var updatedAt: Date

    public static let defaultWidth: Double = 500
    public static let defaultHeight: Double = 400
    public static let minWidth: Double = 200
    public static let minHeight: Double = 100
    public static let maxTextLength: Int = 100_000

    public init(id: String, x: Double, y: Double, width: Double = defaultWidth, height: Double = defaultHeight,
                text: String = "", zIndex: Int, createdAt: Date = .now, updatedAt: Date = .now) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.text = text; self.zIndex = zIndex; self.createdAt = createdAt; self.updatedAt = updatedAt
    }
}

// MARK: - TerminalState

public struct TerminalState: Codable, Identifiable {
    public let id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var isAlive: Bool
    public var themeKey: String
    public var fontFamily: String
    public var fontSize: Double
    public var zIndex: Int

    public static let defaultWidth: Double = 500
    public static let defaultHeight: Double = 300
    public static let minWidth: Double = 200
    public static let minHeight: Double = 100
    public static let maxTerminals: Int = 10

    public static let themes: [String: TerminalTheme] = [
        "dark": TerminalTheme(bg: "#1E1E1E", fg: "#D4D4D4", cursor: "#AEAFAD"),
        "dracula": TerminalTheme(bg: "#282A36", fg: "#F8F8F2", cursor: "#F8F8F2"),
        "monokai": TerminalTheme(bg: "#272822", fg: "#F8F8F2", cursor: "#F8F8F0"),
        "solarized": TerminalTheme(bg: "#002B36", fg: "#839496", cursor: "#93A1A1"),
        "nord": TerminalTheme(bg: "#2E3440", fg: "#D8DEE9", cursor: "#D8DEE9"),
        "tokyoNight": TerminalTheme(bg: "#1A1B26", fg: "#A9B1D6", cursor: "#C0CAF5"),
        "catppuccin": TerminalTheme(bg: "#1E1E2E", fg: "#CDD6F4", cursor: "#F5E0DC")
    ]

    public init(id: String, x: Double, y: Double, width: Double = defaultWidth, height: Double = defaultHeight,
                isAlive: Bool = true, themeKey: String = "dark", fontFamily: String = "Menlo", fontSize: Double = 13, zIndex: Int) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.isAlive = isAlive; self.themeKey = themeKey; self.fontFamily = fontFamily
        self.fontSize = fontSize; self.zIndex = zIndex
    }
}

public struct TerminalTheme: Codable {
    public let bg: String
    public let fg: String
    public let cursor: String
    public init(bg: String, fg: String, cursor: String) { self.bg = bg; self.fg = fg; self.cursor = cursor }
}

// MARK: - BrowserState

public struct BrowserState: Codable, Identifiable {
    public let id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var url: String
    public var zIndex: Int

    public static let defaultWidth: Double = 600
    public static let defaultHeight: Double = 400
    public static let minWidth: Double = 300
    public static let minHeight: Double = 150
    public static let maxBrowsers: Int = 10

    public init(id: String, x: Double, y: Double, width: Double = defaultWidth, height: Double = defaultHeight,
                url: String = "https://www.google.com", zIndex: Int) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.url = url; self.zIndex = zIndex
    }
}

// MARK: - FileManagerState

public struct FileManagerState: Codable, Identifiable {
    public let id: String
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var rootPath: String
    public var expandedDirs: Set<String>
    public var zIndex: Int

    public static let defaultWidth: Double = 400
    public static let defaultHeight: Double = 300
    public static let minWidth: Double = 200
    public static let minHeight: Double = 100

    public init(id: String, x: Double, y: Double, width: Double = defaultWidth, height: Double = defaultHeight,
                rootPath: String = "~", expandedDirs: Set<String> = [], zIndex: Int) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.rootPath = rootPath; self.expandedDirs = expandedDirs; self.zIndex = zIndex
    }
}

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

// MARK: - Workspace

public struct Workspace: Codable, Identifiable {
    public let id: String
    public var name: String
    public var createdAt: Date

    public init(id: String = UUID().uuidString, name: String, createdAt: Date = .now) {
        self.id = id; self.name = name; self.createdAt = createdAt
    }
}

// MARK: - CanvasData

public struct CanvasData: Codable {
    public var scale: Double
    public var panX: Double
    public var panY: Double
    public var stickyNotes: [String: StickyNote]
    public var frames: [String: Frame]
    public var drawings: [String: Drawing]
    public var images: [String: ImageModel]
    public var markdowns: [String: MarkdownNote]
    public var terminals: [String: TerminalState]
    public var browsers: [String: BrowserState]
    public var fileManagers: [String: FileManagerState]
    public var nextZIndex: Int

    public init(
        scale: Double = 1.0, panX: Double = 0, panY: Double = 0,
        stickyNotes: [String: StickyNote] = [:], frames: [String: Frame] = [:],
        drawings: [String: Drawing] = [:], images: [String: ImageModel] = [:],
        markdowns: [String: MarkdownNote] = [:], terminals: [String: TerminalState] = [:],
        browsers: [String: BrowserState] = [:], fileManagers: [String: FileManagerState] = [:],
        nextZIndex: Int = 1
    ) {
        self.scale = scale; self.panX = panX; self.panY = panY
        self.stickyNotes = stickyNotes; self.frames = frames; self.drawings = drawings
        self.images = images; self.markdowns = markdowns; self.terminals = terminals
        self.browsers = browsers; self.fileManagers = fileManagers; self.nextZIndex = nextZIndex
    }
}
