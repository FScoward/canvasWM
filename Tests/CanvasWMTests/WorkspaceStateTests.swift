import Foundation
@testable import CanvasWMLib

func runWorkspaceStateTests() {
    // Initial state has one default workspace
    do {
        let state = WorkspaceState()
        assert(state.workspaces.count == 1, "initial has 1 workspace")
        assert(state.activeWorkspaceId != nil, "initial has active workspace")
        assert(state.activeWorkspace?.name == "Default", "initial workspace name is Default")
    }

    // addWorkspace adds and returns new workspace
    do {
        let state = WorkspaceState()
        let ws = state.addWorkspace(name: "Project A")
        assert(state.workspaces.count == 2, "addWorkspace increases count")
        assert(ws.name == "Project A", "addWorkspace name")
    }

    // switchWorkspace changes active
    do {
        let state = WorkspaceState()
        let ws = state.addWorkspace(name: "Second")
        state.switchWorkspace(id: ws.id)
        assert(state.activeWorkspaceId == ws.id, "switchWorkspace updates activeId")
        assert(state.activeWorkspace?.name == "Second", "switchWorkspace updates activeWorkspace")
    }

    // renameWorkspace
    do {
        let state = WorkspaceState()
        let id = state.workspaces[0].id
        state.renameWorkspace(id: id, name: "Renamed")
        assert(state.workspaces[0].name == "Renamed", "renameWorkspace")
    }

    // deleteWorkspace removes and switches active if needed
    do {
        let state = WorkspaceState()
        let ws = state.addWorkspace(name: "ToDelete")
        state.switchWorkspace(id: ws.id)
        assert(state.activeWorkspaceId == ws.id, "active is ToDelete")
        state.deleteWorkspace(id: ws.id)
        assert(state.workspaces.count == 1, "deleteWorkspace removes")
        assert(state.activeWorkspaceId == state.workspaces.first?.id, "deleteWorkspace switches active")
    }

    // deleteWorkspace prevents deleting the last workspace
    do {
        let state = WorkspaceState()
        let id = state.workspaces[0].id
        state.deleteWorkspace(id: id)
        assert(state.workspaces.count == 1, "cannot delete last workspace")
    }

    // renameWorkspace with non-existent id does nothing
    do {
        let state = WorkspaceState()
        state.renameWorkspace(id: "nonexistent", name: "Whatever")
        assert(state.workspaces[0].name == "Default", "rename non-existent does nothing")
    }

    print("WorkspaceState Tests: \(_passes) passed, \(_failures) failed")
}
