import SwiftUI

public struct WorkspaceSidebarView: View {
    @Bindable var canvasState: CanvasState
    @Bindable var workspaceState: WorkspaceState
    @State private var editingId: String? = nil
    @State private var editName: String = ""

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Workspaces").font(.system(size: 13, weight: .bold))
                Spacer()
                Button(action: addWorkspace) {
                    Image(systemName: "plus").font(.system(size: 12))
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            Divider()

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(workspaceState.workspaces) { ws in
                        workspaceRow(ws)
                    }
                }
                .padding(4)
            }
        }
        .frame(width: 200)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    @ViewBuilder
    private func workspaceRow(_ ws: Workspace) -> some View {
        HStack {
            if editingId == ws.id {
                TextField("Name", text: $editName, onCommit: {
                    workspaceState.renameWorkspace(id: ws.id, name: editName)
                    editingId = nil
                })
                .textFieldStyle(.plain)
                .font(.system(size: 12))
            } else {
                Text(ws.name)
                    .font(.system(size: 12, weight: workspaceState.activeWorkspaceId == ws.id ? .bold : .regular))
                    .foregroundColor(workspaceState.activeWorkspaceId == ws.id ? .accentColor : .primary)
            }
            Spacer()
            if workspaceState.workspaces.count > 1 {
                Button(action: { deleteWorkspace(ws) }) {
                    Image(systemName: "trash").font(.system(size: 10)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8).padding(.vertical, 4)
        .background(workspaceState.activeWorkspaceId == ws.id ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(4)
        .contentShape(Rectangle())
        .onTapGesture { switchToWorkspace(ws.id) }
        .onTapGesture(count: 2) { editingId = ws.id; editName = ws.name }
    }

    private func addWorkspace() {
        let ws = workspaceState.addWorkspace(name: "Workspace \(workspaceState.workspaces.count + 1)")
        switchToWorkspace(ws.id)
    }

    private func deleteWorkspace(_ ws: Workspace) {
        if let activeId = workspaceState.activeWorkspaceId {
            PersistenceManager.shared.saveImmediate(workspaceId: activeId, canvasData: canvasState.toCanvasData())
        }
        workspaceState.deleteWorkspace(id: ws.id)
        if let newActiveId = workspaceState.activeWorkspaceId {
            if let data = PersistenceManager.shared.load(workspaceId: newActiveId) {
                canvasState.loadFromCanvasData(data)
            } else { canvasState.reset() }
        }
    }

    private func switchToWorkspace(_ id: String) {
        guard id != workspaceState.activeWorkspaceId else { return }
        if let currentId = workspaceState.activeWorkspaceId {
            PersistenceManager.shared.saveImmediate(workspaceId: currentId, canvasData: canvasState.toCanvasData())
        }
        workspaceState.switchWorkspace(id: id)
        if let data = PersistenceManager.shared.load(workspaceId: id) {
            canvasState.loadFromCanvasData(data)
        } else { canvasState.reset() }
    }
}
