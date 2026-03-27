import SwiftUI

public struct MainView: View {
    @Bindable var canvasState: CanvasState
    @Bindable var workspaceState: WorkspaceState
    @State private var canvasSize: CGSize = CGSize(width: 800, height: 600)
    @State private var showSidebar: Bool = false

    public init(canvasState: CanvasState, workspaceState: WorkspaceState) {
        self.canvasState = canvasState
        self.workspaceState = workspaceState
    }

    public var body: some View {
        VStack(spacing: 0) {
            ToolbarView(canvasState: canvasState, canvasSize: $canvasSize, showSidebar: $showSidebar)

            HStack(spacing: 0) {
                if showSidebar {
                    WorkspaceSidebarView(canvasState: canvasState, workspaceState: workspaceState)
                    Divider()
                }

                ZStack(alignment: .bottomTrailing) {
                    InfiniteCanvasView(canvasState: canvasState)
                        .background(
                            GeometryReader { geometry in
                                Color.clear.onAppear { canvasSize = geometry.size }
                                    .onChange(of: geometry.size) { _, newSize in canvasSize = newSize }
                            }
                        )

                    MinimapView(canvasState: canvasState, canvasSize: canvasSize)
                        .padding(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { loadWorkspace() }
        .onKeyPress(.delete) { canvasState.deleteSelected(); return .handled }
        .onKeyPress(.escape) { canvasState.selectedWidgetId = nil; canvasState.toolMode = .select; return .handled }
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

    public init(canvasState: CanvasState, canvasSize: Binding<CGSize>, showSidebar: Binding<Bool>) {
        self.canvasState = canvasState
        self._canvasSize = canvasSize
        self._showSidebar = showSidebar
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
