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
    @State private var showWidgetGallery: Bool = false

    public init(state: CanvasWMState, engine: CanvasWMEngine) {
        self.state = state
        self.engine = engine
    }

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                canvasGrid
                bookmarkAreasLayer
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
                state.centerOnMonitor(minimapSize: geometry.size)
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
    @State private var monitorGlow: Bool = false
    @State private var monitorGradientAngle: Double = 0

    private func monitorBounds(screenSize: CGSize) -> some View {
        let fullScreen = state.primaryScreenFrame.width > 0 ? state.primaryScreenFrame.size : screenSize
        let w = fullScreen.width * state.scale
        let h = fullScreen.height * state.scale
        let x = state.viewport.currentX * state.scale + state.panX
        let y = state.viewport.currentY * state.scale + state.panY
        let monitorColor = Color(red: 0.2, green: 0.6, blue: 1.0) // bright blue
        return ZStack {
            // Background fill
            Rectangle()
                .fill(monitorColor.opacity(monitorGlow ? 0.15 : 0.05))
                .frame(width: w, height: h)
                .position(x: x + w / 2, y: y + h / 2)
            // Pattern B: Rotating angular gradient border
            Rectangle()
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [
                            monitorColor,
                            .cyan,
                            .white,
                            .cyan,
                            monitorColor,
                            monitorColor.opacity(0.2),
                            monitorColor.opacity(0.2),
                            monitorColor
                        ]),
                        center: .center,
                        angle: .degrees(monitorGradientAngle)
                    ),
                    lineWidth: 3.5
                )
                .frame(width: w, height: h)
                .position(x: x + w / 2, y: y + h / 2)
                .shadow(color: monitorColor.opacity(0.7), radius: 10)
            // Label
            Text("Monitor")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(monitorColor)
                .shadow(color: monitorColor.opacity(0.8), radius: 6)
                .position(x: x + w / 2, y: y + 12)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                monitorGlow = true
            }
            withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
                monitorGradientAngle = 360
            }
        }
        .gesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    if viewportDragStart == nil {
                        viewportDragStart = CGPoint(x: state.viewport.currentX, y: state.viewport.currentY)
                        engine.isDragging = true
                    }
                    if let start = viewportDragStart {
                        let newX = start.x + value.translation.width / state.scale
                        let newY = start.y + value.translation.height / state.scale
                        state.viewport.jump(toX: CGFloat(newX), toY: CGFloat(newY))
                        engine.syncToScreen()
                    }
                }
                .onEnded { _ in viewportDragStart = nil; engine.isDragging = false; engine.notifyDragEnded() }
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
                let titleHex = DesktopStickyNote.colors[note.colorName]?.titleBg ?? "#FFF176"
                VStack(spacing: 0) {
                    // Title bar
                    HStack(spacing: 3) {
                        ForEach(DesktopStickyNote.colors.keys.sorted(), id: \.self) { cn in
                            let dotHex = DesktopStickyNote.colors[cn]?.titleBg ?? "#FFF176"
                            Circle()
                                .fill(Color(hex: dotHex) ?? .yellow)
                                .frame(width: max(3, 5 * state.scale), height: max(3, 5 * state.scale))
                        }
                        Spacer()
                    }
                    .padding(.horizontal, max(2, 4 * state.scale))
                    .padding(.vertical, max(1, 2 * state.scale))
                    .background(Color(hex: titleHex)?.opacity(0.8) ?? .yellow.opacity(0.8))

                    // Content
                    Text(note.text.isEmpty ? "Double-click to edit..." : note.text)
                        .font(.system(size: max(5, 10 * state.scale)))
                        .foregroundColor(note.text.isEmpty ? .black.opacity(0.3) : .black.opacity(0.8))
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(max(2, 4 * state.scale))
                }
                .frame(width: w, height: h)
                .background(Color(hex: bgHex) ?? .yellow.opacity(0.5))
                .cornerRadius(max(2, 4 * state.scale))
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0.5, y: 1)
                .overlay(RoundedRectangle(cornerRadius: max(2, 4 * state.scale)).stroke(Color.orange.opacity(0.4), lineWidth: 0.5))
                .position(x: x, y: y)
                .gesture(widgetDragGesture(id: note.id, currentX: note.x, currentY: note.y))
            }
            ForEach(markdowns) { md in
                let w = md.width * state.scale
                let h = md.height * state.scale
                let x = md.x * state.scale + state.panX + w / 2
                let y = md.y * state.scale + state.panY + h / 2
                VStack(spacing: 0) {
                    // Toolbar
                    HStack(spacing: max(2, 4 * state.scale)) {
                        Image(systemName: "doc.richtext")
                            .font(.system(size: max(5, 8 * state.scale)))
                            .foregroundColor(.secondary)
                        Text("Markdown")
                            .font(.system(size: max(5, 8 * state.scale), weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, max(2, 4 * state.scale))
                    .padding(.vertical, max(1, 3 * state.scale))
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.9))

                    // Content preview
                    VStack(alignment: .leading, spacing: max(1, 2 * state.scale)) {
                        ForEach(Array(md.text.components(separatedBy: "\n").prefix(15).enumerated()), id: \.offset) { _, line in
                            if line.hasPrefix("# ") {
                                Text(line.dropFirst(2))
                                    .font(.system(size: max(6, 12 * state.scale), weight: .bold))
                            } else if line.hasPrefix("## ") {
                                Text(line.dropFirst(3))
                                    .font(.system(size: max(5, 10 * state.scale), weight: .bold))
                            } else if line.hasPrefix("- ") {
                                HStack(alignment: .top, spacing: 2) {
                                    Text("•").font(.system(size: max(4, 8 * state.scale)))
                                    Text(line.dropFirst(2)).font(.system(size: max(4, 8 * state.scale)))
                                }
                            } else if !line.trimmingCharacters(in: .whitespaces).isEmpty {
                                Text(line)
                                    .font(.system(size: max(4, 8 * state.scale)))
                            }
                        }
                    }
                    .foregroundColor(.primary.opacity(0.8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(max(2, 4 * state.scale))
                }
                .frame(width: w, height: h)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(max(2, 4 * state.scale))
                .shadow(color: .black.opacity(0.1), radius: 2, x: 0.5, y: 1)
                .overlay(RoundedRectangle(cornerRadius: max(2, 4 * state.scale)).stroke(Color.purple.opacity(0.3), lineWidth: 0.5))
                .position(x: x, y: y)
                .gesture(widgetDragGesture(id: md.id, currentX: md.x, currentY: md.y))
            }
            ForEach(browsers) { br in
                let w = br.width * state.scale
                let h = br.height * state.scale
                let x = br.x * state.scale + state.panX + w / 2
                let y = br.y * state.scale + state.panY + h / 2
                let shortURL = br.url
                    .replacingOccurrences(of: "https://www.", with: "")
                    .replacingOccurrences(of: "https://", with: "")
                    .replacingOccurrences(of: "http://www.", with: "")
                    .replacingOccurrences(of: "http://", with: "")
                VStack(spacing: 0) {
                    // URL bar - prominent
                    HStack(spacing: 3) {
                        Image(systemName: "globe")
                            .font(.system(size: max(6, 10 * state.scale), weight: .medium))
                            .foregroundColor(.blue)
                        Text(shortURL)
                            .font(.system(size: max(6, 10 * state.scale), weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                    }
                    .padding(.horizontal, max(3, 6 * state.scale))
                    .padding(.vertical, max(2, 4 * state.scale))
                    .background(Color.blue.opacity(0.08))

                    // Fake web content lines
                    VStack(alignment: .leading, spacing: max(2, 4 * state.scale)) {
                        // Title-like block
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.15))
                            .frame(width: w * 0.6, height: max(4, 8 * state.scale))
                        // Text-like blocks
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: w * 0.85, height: max(3, 5 * state.scale))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: w * 0.7, height: max(3, 5 * state.scale))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: w * 0.9, height: max(3, 5 * state.scale))
                        // Image-like block
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.blue.opacity(0.06))
                            .frame(width: w * 0.5, height: max(10, 20 * state.scale))
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.primary.opacity(0.08))
                            .frame(width: w * 0.75, height: max(3, 5 * state.scale))
                    }
                    .padding(max(3, 6 * state.scale))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                }
                .frame(width: w, height: h)
                .background(Color.white)
                .cornerRadius(max(2, 4 * state.scale))
                .shadow(color: .black.opacity(0.15), radius: 2, x: 0.5, y: 1)
                .overlay(RoundedRectangle(cornerRadius: max(2, 4 * state.scale)).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                .position(x: x, y: y)
                .gesture(widgetDragGesture(id: br.id, currentX: br.x, currentY: br.y))
            }
        }
    }

    private var bookmarkAreasLayer: some View {
        let screenFrame = state.primaryScreenFrame
        let screenW = screenFrame.width > 0 ? Double(screenFrame.width) : 1440.0
        let screenH = screenFrame.height > 0 ? Double(screenFrame.height) : 900.0
        let areas = state.bookmarkedAreas.values.sorted(by: { $0.createdAt < $1.createdAt })
        return ForEach(areas) { area in
            let w = screenW * state.scale
            let h = screenH * state.scale
            let x = area.panX * state.scale + state.panX
            let y = area.panY * state.scale + state.panY
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.orange.opacity(0.08))
                    .frame(width: w, height: h)
                Rectangle()
                    .stroke(Color.orange, style: StrokeStyle(lineWidth: 2.5, dash: [8, 4]))
                    .frame(width: w, height: h)
                    .shadow(color: Color.orange.opacity(0.4), radius: 4)
                HStack(spacing: 3) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 11))
                    Text(area.name)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .foregroundColor(.orange)
                .shadow(color: .orange.opacity(0.6), radius: 3)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .offset(x: 4, y: 4)
            }
            .position(x: x + w / 2, y: y + h / 2)
            .onTapGesture {
                state.jumpToArea(id: area.id, engine: engine)
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
                engine.notifyDragEnded()
                engine.syncToScreen()
            }
    }

    private var statusBar: some View {
        VStack {
            Spacer()
            HStack(spacing: 12) {
                Text("\(state.windows.count) windows")

                Spacer()

                Button(action: { showWidgetGallery.toggle() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.square")
                        Text("Add")
                    }
                    .font(.system(size: 13))
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
                .popover(isPresented: $showWidgetGallery, arrowEdge: .top) {
                    WMWidgetGalleryView(
                        state: state,
                        stickyNoteController: stickyNoteController,
                        isPresented: $showWidgetGallery
                    )
                }

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
            .onEnded { _ in dragStart = nil; engine.isDragging = false; engine.notifyDragEnded() }
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
            .onEnded { _ in windowDragId = nil; windowDragOffset = .zero; engine.isDragging = false; engine.notifyDragEnded() }
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

// MARK: - WM Widget Gallery

struct WMWidgetGalleryItem: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let description: String
    let kind: WMWidgetKind
}

enum WMWidgetKind {
    case stickyNote, markdown, browser
}

struct WMWidgetGalleryView: View {
    @Bindable var state: CanvasWMState
    var stickyNoteController: StickyNoteWindowController?
    @Binding var isPresented: Bool

    private let items: [WMWidgetGalleryItem] = [
        WMWidgetGalleryItem(name: "Sticky Note", icon: "note.text", description: "Floating desktop note",
                            kind: .stickyNote),
        WMWidgetGalleryItem(name: "Markdown", icon: "doc.richtext", description: "Markdown viewer/editor",
                            kind: .markdown),
        WMWidgetGalleryItem(name: "Browser", icon: "globe", description: "Embedded web browser",
                            kind: .browser),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Widget")
                .font(.headline)
                .padding(.horizontal, 4)

            ForEach(items) { item in
                WMWidgetPreviewCard(item: item) {
                    addWidget(kind: item.kind)
                    isPresented = false
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func addWidget(kind: WMWidgetKind) {
        let screenFrame = state.primaryScreenFrame
        let sw = screenFrame.width > 0 ? Double(screenFrame.width) : 1440.0
        let sh = screenFrame.height > 0 ? Double(screenFrame.height) : 900.0
        switch kind {
        case .stickyNote:
            stickyNoteController?.createNote(viewportX: state.viewportX, viewportY: state.viewportY,
                                              screenWidth: sw, screenHeight: sh)
        case .markdown:
            stickyNoteController?.createMarkdown(viewportX: state.viewportX, viewportY: state.viewportY,
                                                  screenWidth: sw, screenHeight: sh)
        case .browser:
            stickyNoteController?.createBrowser(viewportX: state.viewportX, viewportY: state.viewportY,
                                                 screenWidth: sw, screenHeight: sh)
        }
    }
}

struct WMWidgetPreviewCard: View {
    let item: WMWidgetGalleryItem
    let onTap: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 10) {
            miniPreview(kind: item.kind)
                .frame(width: 70, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: item.icon)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(item.name)
                        .font(.system(size: 13, weight: .medium))
                }
                Text(item.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isHovered ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
    }

    @ViewBuilder
    private func miniPreview(kind: WMWidgetKind) -> some View {
        switch kind {
        case .stickyNote:
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("Note").font(.system(size: 6, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(Color.yellow.opacity(0.3))
                Text("Hello World!")
                    .font(.system(size: 6))
                    .padding(.horizontal, 3)
                Spacer()
            }
            .background(Color(red: 1.0, green: 0.98, blue: 0.8))
            .cornerRadius(3)

        case .markdown:
            VStack(alignment: .leading, spacing: 1) {
                HStack {
                    Text("Markdown").font(.system(size: 6, weight: .medium)).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 3).padding(.vertical, 1)
                .background(Color.purple.opacity(0.1))
                Text("# Title").font(.system(size: 7, weight: .bold))
                    .padding(.horizontal, 3)
                Text("Some text...").font(.system(size: 6))
                    .padding(.horizontal, 3)
                Spacer()
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(3)

        case .browser:
            VStack(spacing: 0) {
                HStack(spacing: 2) {
                    Image(systemName: "chevron.left").font(.system(size: 5))
                    Image(systemName: "chevron.right").font(.system(size: 5))
                    RoundedRectangle(cornerRadius: 1).fill(Color.gray.opacity(0.2)).frame(height: 8)
                        .overlay(Text("example.com").font(.system(size: 5)).foregroundColor(.secondary))
                }
                .padding(.horizontal, 3).padding(.vertical, 2)
                .background(.bar)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Example").font(.system(size: 7, weight: .bold))
                    Text("Web content").font(.system(size: 5)).foregroundColor(.secondary)
                }
                .padding(3)
                Spacer()
            }
            .background(Color.white)
            .cornerRadius(3)
        }
    }
}

