import Foundation
import Observation

@Observable
public final class WorkspaceState {
    public var workspaces: [Workspace] = []
    public var activeWorkspaceId: String? = nil

    public init() {
        let defaultWorkspace = Workspace(name: "Default")
        workspaces = [defaultWorkspace]
        activeWorkspaceId = defaultWorkspace.id
    }

    public var activeWorkspace: Workspace? {
        workspaces.first { $0.id == activeWorkspaceId }
    }

    @discardableResult
    public func addWorkspace(name: String) -> Workspace {
        let ws = Workspace(name: name)
        workspaces.append(ws)
        return ws
    }

    public func deleteWorkspace(id: String) {
        guard workspaces.count > 1 else { return }
        workspaces.removeAll { $0.id == id }
        if activeWorkspaceId == id { activeWorkspaceId = workspaces.first?.id }
    }

    public func renameWorkspace(id: String, name: String) {
        if let idx = workspaces.firstIndex(where: { $0.id == id }) {
            workspaces[idx].name = name
        }
    }

    public func switchWorkspace(id: String) { activeWorkspaceId = id }
}
