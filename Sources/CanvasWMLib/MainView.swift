import SwiftUI

public struct MainView: View {
    @Bindable var canvasState: CanvasState
    @Bindable var workspaceState: WorkspaceState
    @State private var canvasSize: CGSize = CGSize(width: 800, height: 600)
    @State private var showSidebar: Bool = false
    @State private var showBookmarks: Bool = false
    @State private var showBookmarkNameInput: Bool = false
    @State private var newBookmarkName: String = ""

    public init(canvasState: CanvasState, workspaceState: WorkspaceState) {
        self.canvasState = canvasState
        self.workspaceState = workspaceState
    }

    public var body: some View {
        VStack(spacing: 0) {
            ToolbarView(canvasState: canvasState, canvasSize: $canvasSize, showSidebar: $showSidebar,
                        showBookmarks: $showBookmarks, showBookmarkNameInput: $showBookmarkNameInput)

            HStack(spacing: 0) {
                if showSidebar {
                    WorkspaceSidebarView(canvasState: canvasState, workspaceState: workspaceState)
                    Divider()
                }

                ZStack(alignment: .bottomTrailing) {
                    ZStack(alignment: .topTrailing) {
                        InfiniteCanvasView(canvasState: canvasState)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.onAppear { canvasSize = geometry.size }
                                        .onChange(of: geometry.size) { _, newSize in canvasSize = newSize }
                                }
                            )

                        if showBookmarks {
                            BookmarkedAreaListView(canvasState: canvasState)
                                .padding(8)
                                .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }

                    MinimapView(canvasState: canvasState, canvasSize: canvasSize)
                        .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadWorkspace() }
        .onKeyPress(.delete) { canvasState.deleteSelected(); return .handled }
        .onKeyPress(.escape) { canvasState.selectedWidgetId = nil; canvasState.toolMode = .select; return .handled }
        .onKeyPress(characters: CharacterSet(charactersIn: "b"), phases: .down) { press in
            if press.modifiers == [.command, .shift] {
                showBookmarkNameInput = true
                return .handled
            } else if press.modifiers == .command {
                withAnimation(.easeInOut(duration: 0.2)) { showBookmarks.toggle() }
                return .handled
            }
            return .ignored
        }
        .sheet(isPresented: $showBookmarkNameInput) {
            BookmarkNameInputSheet(canvasState: canvasState, isPresented: $showBookmarkNameInput)
        }
    }

    private func loadWorkspace() {
        if let wsId = workspaceState.activeWorkspaceId,
           let data = PersistenceManager.shared.load(workspaceId: wsId) {
            canvasState.loadFromCanvasData(data)
        }
    }
}

public struct ToolbarView: View {
    @Bindable var canvasState: CanvasState
    @Binding var canvasSize: CGSize
    @Binding var showSidebar: Bool
    @Binding var showBookmarks: Bool
    @Binding var showBookmarkNameInput: Bool

    public init(canvasState: CanvasState, canvasSize: Binding<CGSize>, showSidebar: Binding<Bool>,
                showBookmarks: Binding<Bool>, showBookmarkNameInput: Binding<Bool>) {
        self.canvasState = canvasState
        self._canvasSize = canvasSize
        self._showSidebar = showSidebar
        self._showBookmarks = showBookmarks
        self._showBookmarkNameInput = showBookmarkNameInput
    }

    public var body: some View {
        HStack(spacing: 8) {
            Button(action: { showSidebar.toggle() }) {
                Image(systemName: "sidebar.left")
            }.buttonStyle(.plain)

            Divider().frame(height: 16)

            Button(action: { addWidgetAtCenter { canvasState.addStickyNote(x: $0, y: $1) } }) {
                Label("Note", systemImage: "note.text.badge.plus")
            }.buttonStyle(.bordered)

            Button(action: { addWidgetAtCenter { canvasState.addFrame(x: $0, y: $1) } }) {
                Label("Frame", systemImage: "rectangle.dashed")
            }.buttonStyle(.bordered)

            Button(action: { addWidgetAtCenter { _ = canvasState.addTerminal(x: $0, y: $1) } }) {
                Label("Terminal", systemImage: "terminal")
            }.buttonStyle(.bordered)

            Button(action: { addWidgetAtCenter { _ = canvasState.addBrowser(x: $0, y: $1) } }) {
                Label("Browser", systemImage: "globe")
            }.buttonStyle(.bordered)

            Button(action: { addWidgetAtCenter { canvasState.addFileManager(x: $0, y: $1) } }) {
                Label("Files", systemImage: "folder")
            }.buttonStyle(.bordered)

            Button(action: { addWidgetAtCenter { canvasState.addMarkdown(x: $0, y: $1) } }) {
                Label("Markdown", systemImage: "doc.richtext")
            }.buttonStyle(.bordered)

            Divider().frame(height: 16)

            if canvasState.toolMode == .pen {
                Button(action: { canvasState.toolMode = .select }) {
                    Label("Pen", systemImage: "pencil.tip")
                }.buttonStyle(.borderedProminent)
            } else {
                Button(action: { canvasState.toolMode = .pen }) {
                    Label("Pen", systemImage: "pencil.tip")
                }.buttonStyle(.bordered)
            }

            Divider().frame(height: 16)

            Button(action: { showBookmarkNameInput = true }) {
                Label("Bookmark", systemImage: "bookmark")
            }
            .buttonStyle(.bordered)
            .help("Bookmark current view (Cmd+Shift+B)")

            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showBookmarks.toggle() } }) {
                Label("Areas", systemImage: "list.bullet")
            }
            .buttonStyle(.bordered)
            .help("Toggle bookmarks panel (Cmd+B)")

            Spacer()

            Text(String(format: "%.0f%%", canvasState.scale * 100))
                .font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.bar)
    }

    private func addWidgetAtCenter(_ action: (Double, Double) -> Void) {
        let world = ViewportMath.screenToWorld(
            screenX: canvasSize.width / 2, screenY: canvasSize.height / 2,
            panX: canvasState.panX, panY: canvasState.panY, scale: canvasState.scale)
        action(world.worldX, world.worldY)
    }
}

struct BookmarkNameInputSheet: View {
    @Bindable var canvasState: CanvasState
    @Binding var isPresented: Bool
    @State private var name: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("Bookmark Current View")
                .font(.headline)

            TextField("Bookmark name", text: $name)
                .textFieldStyle(.roundedBorder)
                .onSubmit { save() }

            HStack {
                Button("Cancel") { isPresented = false }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Save") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        canvasState.addBookmarkedArea(name: trimmed)
        isPresented = false
    }
}
