import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    public var onTerminate: (() -> Void)?
    private var mainWindow: NSWindow?
    public let tilingController = TilingWindowController()
    public let stickyNoteController = StickyNoteWindowController()

    public func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBarIcon()
        mainWindow = NSApplication.shared.windows.first
        tilingController.stickyNoteController = stickyNoteController
        stickyNoteController.restoreAllWindows()
        // Prepare canvas WM (hidden) — minimap appears on Option+Control hold
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.tilingController.prepare()
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }

    public func applicationWillTerminate(_ notification: Notification) {
        tilingController.deactivate()
        tilingController.cleanup()
        onTerminate?()
    }

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "CanvasWM")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Canvas", action: #selector(showCanvas), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "New Sticky Note", action: #selector(newStickyNote), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "New Markdown", action: #selector(newMarkdown), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "New Browser", action: #selector(newBrowser), keyEquivalent: "b"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Canvas WM (Ctrl+T)", action: #selector(toggleTiling), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    @objc private func showCanvas() {
        guard let window = mainWindow ?? NSApplication.shared.windows.first else { return }
        window.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    @objc private func newStickyNote() {
        stickyNoteController.createNote()
    }

    @objc private func newMarkdown() {
        stickyNoteController.createMarkdown()
    }

    @objc private func newBrowser() {
        stickyNoteController.createBrowser()
    }

    @objc private func toggleTiling() {
        tilingController.toggle()
    }
}
