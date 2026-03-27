import SwiftUI
import CanvasWMLib

@main
struct CanvasWMApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var canvasState = CanvasState()
    @State private var workspaceState = WorkspaceState()

    var body: some Scene {
        WindowGroup {
            MainView(canvasState: canvasState, workspaceState: workspaceState)
                .onAppear {
                    appDelegate.onTerminate = { [canvasState, workspaceState] in
                        if let wsId = workspaceState.activeWorkspaceId {
                            PersistenceManager.shared.saveImmediate(
                                workspaceId: wsId,
                                canvasData: canvasState.toCanvasData()
                            )
                        }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
    }
}
