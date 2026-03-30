import AppKit

public final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    public var onTerminate: (() -> Void)?
    public let wmController = CanvasWMWindowController()
    public let stickyNoteController = StickyNoteWindowController()

    /// UserDefaults key for "gather windows on quit" setting
    private static let gatherOnQuitKey = "gatherWindowsOnQuit"

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Register default: gather windows on quit is ON by default
        UserDefaults.standard.register(defaults: [Self.gatherOnQuitKey: true])
        setupMenuBarIcon()
        wmController.stickyNoteController = stickyNoteController
        stickyNoteController.restoreAllWindows()
        // Prepare canvas WM (hidden) — minimap appears on Option+Control hold
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.wmController.prepare()
        }
    }

    public func applicationShouldTerminateAfterLastWindowClosed(_ app: NSApplication) -> Bool { false }

    public func applicationWillTerminate(_ notification: Notification) {
        stickyNoteController.saveNow()
        if UserDefaults.standard.bool(forKey: Self.gatherOnQuitKey) {
            wmController.gatherWindowsToMonitor()
        }
        wmController.deactivate()
        wmController.cleanup()
        onTerminate?()
    }

    private func setupMenuBarIcon() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "square.grid.3x3", accessibilityDescription: "CanvasWM")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "New Sticky Note", action: #selector(newStickyNote), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "New Markdown", action: #selector(newMarkdown), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "New Browser", action: #selector(newBrowser), keyEquivalent: "b"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Canvas WM (Ctrl+T)", action: #selector(toggleWM), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        let gatherItem = NSMenuItem(title: "Gather Windows on Quit", action: #selector(toggleGatherOnQuit(_:)), keyEquivalent: "")
        gatherItem.state = UserDefaults.standard.bool(forKey: Self.gatherOnQuitKey) ? .on : .off
        menu.addItem(gatherItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        statusItem?.menu = menu
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

    @objc private func toggleWM() {
        wmController.toggle()
    }

    @objc private func toggleGatherOnQuit(_ sender: NSMenuItem) {
        let current = UserDefaults.standard.bool(forKey: Self.gatherOnQuitKey)
        UserDefaults.standard.set(!current, forKey: Self.gatherOnQuitKey)
        sender.state = !current ? .on : .off
    }
}
