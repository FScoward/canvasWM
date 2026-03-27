import SwiftUI

/// Floating minimap view — shows all windows on an infinite canvas
public struct CanvasWMOverlayView: View {
    @Bindable var state: CanvasWMState
    let engine: CanvasWMEngine
    var stickyNoteController: StickyNoteWindowController?
    @State private var dragStart: CGPoint? = nil
    @State private var lastMouse: CGPoint = .zero
    @State private var windowDragId: String? = nil
    @State private var windowDragOffset: CGSize = .zero
    @State private var widgetDragId: String? = nil
    @State private var widgetDragOffset: CGSize = .zero
    @State private var showBookmarks: Bool = false

    public init(state: CanvasWMState, engine: CanvasWMEngine) {
        self.state = state
        self.engine = engine
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                canvasGrid
                monitorBounds(screenSize: geometry.size)
                windowsLayer
                stickyNotesLayer
                statusBar

                if showBookmarks {
                    VStack {
                        HStack {
                            Spacer()
                            WMBookmarkedAreaListView(state: state, engine: engine, showBookmarks: $showBookmarks)
                                .padding(8)
                        }
                        Spacer()
                    }
                }

            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(panGesture)
            .onContinuousHover { phase in
                if case .active(let loc) = phase { lastMouse = loc }
            }
            // Scroll zoom is handled by NSEvent monitor in CanvasWMWindowController
            .onAppear {
                state.autoFit(minimapSize: geometry.size)
            }
        }
    }

    private var canvasGrid: some View {
        CanvasWMGrid(scale: state.scale, panX: state.panX, panY: state.panY)
    }

    private var windowsLayer: some View {
        ForEach(state.sortedWindows) { win in
            WindowPlaceholder(window: win, isSelected: state.selectedWindowId == win.id, isHighlighted: state.highlightedWindowIds.contains(win.id), scale: state.scale, thumbnail: state.thumbnails[win.id])
                .position(
                    x: win.x * state.scale + state.panX + (win.width * state.scale / 2),
                    y: win.y * state.scale + state.panY + (win.height * state.scale / 2)
                )
                .gesture(windowDragGesture(for: win))
                .onTapGesture(count: 2) { centerOnWindow(win) }
                .onTapGesture { state.bringToFront(id: win.id) }
        }
    }

    @State private var viewportDragStart: CGPoint? = nil

    private func monitorBounds(screenSize: CGSize) -> some View {
        let fullScreen = state.primaryScreenFrame.width > 0 ? state.primaryScreenFrame.size : screenSize
        let w = fullScreen.width * state.scale
        let h = fullScreen.height * state.scale
        let x = state.viewportX * state.scale + state.panX
        let y = state.viewportY * state.scale + state.panY
        return ZStack {
            Rectangle()
                .fill(Color.blue.opacity(0.08))
                .frame(width: w, height: h)
                .position(x: x + w / 2, y: y + h / 2)
            Rectangle()
                .stroke(Color.blue.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                .frame(width: w, height: h)
                .position(x: x + w / 2, y: y + h / 2)
            Text("Monitor")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(.blue.opacity(0.8))
                .position(x: x + w / 2, y: y + 10)
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    if viewportDragStart == nil {
                        viewportDragStart = CGPoint(x: state.viewportX, y: state.viewportY)
                        engine.isDragging = true
                    }
                    if let start = viewportDragStart {
                        state.viewportX = start.x + value.translation.width / state.scale
                        state.viewportY = start.y + value.translation.height / state.scale
                        engine.syncToScreen()
                    }
                }
                .onEnded { _ in viewportDragStart = nil; engine.isDragging = false }
        )
    }

    private var stickyNotesLayer: some View {
        let notes = stickyNoteController?.notes.values.sorted(by: { $0.id < $1.id }) ?? []
        let markdowns = stickyNoteController?.markdowns.values.sorted(by: { $0.id < $1.id }) ?? []
        let browsers = stickyNoteController?.browsers.values.sorted(by: { $0.id < $1.id }) ?? []
        return Group {
            ForEach(notes) { note in
                let w = note.width * state.scale
                let h = note.height * state.scale
                let x = note.x * state.scale + state.panX + w / 2
                let y = note.y * state.scale + state.panY + h / 2
                let bgHex = DesktopStickyNote.colors[note.colorName]?.bg ?? "#FFF9C4"
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: bgHex) ?? .yellow.opacity(0.5))
                    .frame(width: w, height: h)
                    .overlay(
                        Text(note.text.isEmpty ? "Note" : note.text.prefix(20).description)
                            .font(.system(size: max(7, 9 * state.scale)))
                            .foregroundColor(.black.opacity(0.6))
                            .lineLimit(2)
                            .padding(2)
                        , alignment: .topLeading
                    )
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.orange.opacity(0.5), lineWidth: 1))
                    .position(x: x, y: y)
                    .gesture(widgetDragGesture(id: note.id, currentX: note.x, currentY: note.y))
            }
            ForEach(markdowns) { md in
                let w = md.width * state.scale
                let h = md.height * state.scale
                let x = md.x * state.scale + state.panX + w / 2
                let y = md.y * state.scale + state.panY + h / 2
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: w, height: h)
                    .overlay(
                        Text(md.text.isEmpty ? "Markdown" : md.text.prefix(20).description)
                            .font(.system(size: max(7, 9 * state.scale)))
                            .foregroundColor(.black.opacity(0.6))
                            .lineLimit(2)
                            .padding(2)
                        , alignment: .topLeading
                    )
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.purple.opacity(0.5), lineWidth: 1))
                    .position(x: x, y: y)
                    .gesture(widgetDragGesture(id: md.id, currentX: md.x, currentY: md.y))
            }
            ForEach(browsers) { br in
                let w = br.width * state.scale
                let h = br.height * state.scale
                let x = br.x * state.scale + state.panX + w / 2
                let y = br.y * state.scale + state.panY + h / 2
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: w, height: h)
                    .overlay(
                        HStack(spacing: 2) {
                            Image(systemName: "globe")
                                .font(.system(size: max(6, 8 * state.scale)))
                            Text(br.url.prefix(30).description)
                                .font(.system(size: max(7, 9 * state.scale)))
                                .lineLimit(1)
                        }
                        .foregroundColor(.black.opacity(0.6))
                        .padding(2)
                        , alignment: .topLeading
                    )
                    .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.orange.opacity(0.7), lineWidth: 1.5))
                    .position(x: x, y: y)
                    .gesture(widgetDragGesture(id: br.id, currentX: br.x, currentY: br.y))
            }
        }
    }

    private func widgetDragGesture(id: String, currentX: Double, currentY: Double) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if widgetDragId != id {
                    widgetDragId = id
                    widgetDragOffset = CGSize(width: currentX, height: currentY)
                    engine.isDragging = true
                }
                let newX = widgetDragOffset.width + value.translation.width / state.scale
                let newY = widgetDragOffset.height + value.translation.height / state.scale
                if let ctrl = stickyNoteController {
                    if ctrl.notes[id] != nil { ctrl.notes[id]?.x = newX; ctrl.notes[id]?.y = newY }
                    if ctrl.markdowns[id] != nil { ctrl.markdowns[id]?.x = newX; ctrl.markdowns[id]?.y = newY }
                    if ctrl.browsers[id] != nil { ctrl.browsers[id]?.x = newX; ctrl.browsers[id]?.y = newY }
                }
                // Don't call syncToScreen during drag — it fights with off-viewport hiding
            }
            .onEnded { _ in
                widgetDragId = nil
                widgetDragOffset = .zero
                engine.isDragging = false
                engine.syncToScreen()
            }
    }

    private var statusBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("\(state.windows.count) windows")

                Spacer()

                Button(action: { promptBookmarkName() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "bookmark")
                        Text("Save")
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showBookmarks.toggle() } }) {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                        Text("Areas")
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)

                Text(String(format: "%.0f%%", state.scale * 100))
                    .foregroundColor(.blue)
            }
            .font(.system(size: 13, design: .monospaced))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
        }
    }

    private var panGesture: some Gesture {
        DragGesture(minimumDistance: 3)
            .onChanged { value in
                if dragStart == nil {
                    dragStart = CGPoint(x: state.panX, y: state.panY)
                    engine.isDragging = true
                }
                if let start = dragStart {
                    state.panX = start.x + value.translation.width
                    state.panY = start.y + value.translation.height
                    engine.syncToScreen()
                }
            }
            .onEnded { _ in dragStart = nil; engine.isDragging = false }
    }

    private func promptBookmarkName() {
        let nextNum = state.bookmarkedAreas.count + 1
        let defaultName = "Area \(nextNum)"
        BookmarkNamePrompt.prompt(defaultName: defaultName) { [state] name in
            if let name {
                state.addBookmarkedArea(name: name)
            }
        }
    }

    private func centerOnWindow(_ win: ManagedWindow) {
        let frame = state.primaryScreenFrame
        guard frame.width > 0 else { return }
        let screenSize = (w: Double(frame.width), h: Double(frame.height))
        state.centerViewport(on: win, screenSize: screenSize)
        state.bringToFront(id: win.id)
        engine.syncToScreen()
    }

    private func windowDragGesture(for win: ManagedWindow) -> some Gesture {
        DragGesture()
            .onChanged { value in
                if windowDragId != win.id {
                    windowDragId = win.id
                    windowDragOffset = CGSize(width: win.x, height: win.y)
                    engine.isDragging = true
                }
                state.moveWindow(id: win.id,
                    x: windowDragOffset.width + value.translation.width / state.scale,
                    y: windowDragOffset.height + value.translation.height / state.scale)
                engine.syncToScreen()
            }
            .onEnded { _ in windowDragId = nil; windowDragOffset = .zero; engine.isDragging = false }
    }
}

// MARK: - Window Placeholder

struct WindowPlaceholder: View {
    let window: ManagedWindow
    let isSelected: Bool
    let isHighlighted: Bool
    let scale: Double
    var thumbnail: NSImage? = nil
    @State private var glowPhase: Bool = false

    // Warm amber/gold accent
    private let accentColor = Color(red: 1.0, green: 0.76, blue: 0.28) // #FFC247

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else {
                Rectangle().fill(Color(nsColor: .controlBackgroundColor).opacity(0.15))
            }
        }
        .frame(width: window.width * scale, height: window.height * scale)
        .cornerRadius(4)
        // Soft breathing glow
        .shadow(color: isHighlighted ? accentColor.opacity(glowPhase ? 0.9 : 0.3) : .black.opacity(isSelected ? 0.3 : 0.1),
                radius: isHighlighted ? (glowPhase ? 24 : 8) : (isSelected ? 4 : 2), x: 0, y: 0)
        .shadow(color: isHighlighted ? accentColor.opacity(glowPhase ? 0.4 : 0.0) : .clear,
                radius: isHighlighted ? (glowPhase ? 40 : 16) : 0, x: 0, y: 0)
        // Clean border
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(
                    isHighlighted ? accentColor.opacity(glowPhase ? 1.0 : 0.5) :
                    isSelected ? Color.blue : Color.gray.opacity(0.3),
                    lineWidth: isHighlighted ? (glowPhase ? 3 : 2) : (isSelected ? 2 : 0.5)
                )
        )
        .onChange(of: isHighlighted) { _, newValue in
            if newValue {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    glowPhase = true
                }
            } else {
                withAnimation(.easeOut(duration: 0.5)) {
                    glowPhase = false
                }
            }
        }
        .onAppear {
            if isHighlighted {
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    glowPhase = true
                }
            }
        }
    }

    private var titleBar: some View {
        HStack(spacing: 3) {
            Circle().fill(.red).frame(width: 6, height: 6)
            Circle().fill(.yellow).frame(width: 6, height: 6)
            Circle().fill(.green).frame(width: 6, height: 6)
            Text(window.displayName).font(.system(size: 8, weight: .medium)).lineLimit(1)
            Spacer()
        }
        .padding(.horizontal, 4).padding(.vertical, 3)
        .background(Color(nsColor: .windowBackgroundColor).opacity(0.7))
    }
}

// MARK: - Grid

struct CanvasWMGrid: View {
    let scale: Double
    let panX: Double
    let panY: Double

    var body: some View {
        GeometryReader { geometry in
            let gridSize = 60.0 * scale
            let offsetX = panX.truncatingRemainder(dividingBy: gridSize)
            let offsetY = panY.truncatingRemainder(dividingBy: gridSize)

            Path { path in
                let cols = Int(geometry.size.width / gridSize) + 2
                let rows = Int(geometry.size.height / gridSize) + 2
                for col in 0...cols {
                    let x = Double(col) * gridSize + offsetX
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for row in 0...rows {
                    let y = Double(row) * gridSize + offsetY
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.12), lineWidth: 0.5)
            .background(Color.clear)
        }
    }
}

// MARK: - WM Bookmarked Area List

struct WMBookmarkedAreaListView: View {
    @Bindable var state: CanvasWMState
    let engine: CanvasWMEngine
    @Binding var showBookmarks: Bool
    @State private var editingId: String? = nil
    @State private var editingName: String = ""

    var sortedAreas: [BookmarkedArea] {
        state.bookmarkedAreas.values.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Bookmarks")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: { showBookmarks = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11))
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if sortedAreas.isEmpty {
                Text("No bookmarks yet.\nClick \"Save\" to bookmark\nthe current viewport position.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
                        ForEach(sortedAreas) { area in
                            HStack(spacing: 6) {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.blue)

                                if editingId == area.id {
                                    TextField("Name", text: $editingName)
                                        .textFieldStyle(.plain)
                                        .font(.system(size: 13))
                                        .onSubmit {
                                            if !editingName.isEmpty {
                                                state.renameBookmarkedArea(id: area.id, name: editingName)
                                            }
                                            editingId = nil
                                        }
                                } else {
                                    Text(area.name)
                                        .font(.system(size: 13))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }

                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.05)))
                            .contentShape(Rectangle())
                            .onTapGesture { state.jumpToArea(id: area.id, engine: engine) }
                            .contextMenu {
                                Button("Rename") {
                                    editingId = area.id
                                    editingName = area.name
                                }
                                Button("Delete", role: .destructive) {
                                    state.deleteBookmarkedArea(id: area.id)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 260)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }
}

// MARK: - Bookmark Name Prompt (native NSAlert for reliable frontmost display)

enum BookmarkNamePrompt {
    static func prompt(defaultName: String, completion: @escaping (String?) -> Void) {
        DispatchQueue.main.async {
            NSApp.activate(ignoringOtherApps: true)

            let alert = NSAlert()
            alert.messageText = "Bookmark Current Position"
            alert.informativeText = "Enter a name for this bookmark:"
            alert.addButton(withTitle: "Save")
            alert.addButton(withTitle: "Cancel")

            let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
            input.stringValue = defaultName
            alert.accessoryView = input
            alert.window.initialFirstResponder = input
            alert.window.level = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)) + 1)

            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                let name = input.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
                completion(name.isEmpty ? nil : name)
            } else {
                completion(nil)
            }
        }
    }
}

