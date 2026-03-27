import AppKit
import SwiftUI

public final class FloatingWidgetManager {
    public static let shared = FloatingWidgetManager()
    private var floatingPanels: [String: NSPanel] = [:]
    private init() {}

    public func showFloatingStickyNote(_ note: StickyNote, canvasState: CanvasState) {
        if let existing = floatingPanels[note.id] {
            existing.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: note.x, y: note.y, width: note.width, height: note.height),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titlebarAppearsTransparent = true
        panel.titleVisibility = .hidden
        panel.isMovableByWindowBackground = true
        panel.backgroundColor = NSColor(red: 1.0, green: 0.98, blue: 0.8, alpha: 0.95)

        let hostView = NSHostingView(rootView:
            VStack {
                Text(note.text.isEmpty ? "Floating Note" : note.text)
                    .font(.system(size: note.fontSize))
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        )
        panel.contentView = hostView
        panel.makeKeyAndOrderFront(nil)

        floatingPanels[note.id] = panel
    }

    public func hideFloatingWidget(id: String) {
        floatingPanels[id]?.close()
        floatingPanels.removeValue(forKey: id)
    }

    public func hideAll() {
        floatingPanels.values.forEach { $0.close() }
        floatingPanels.removeAll()
    }

    public func isFloating(id: String) -> Bool {
        floatingPanels[id] != nil
    }
}
