import Foundation

public final class PersistenceManager {
    public static let shared = PersistenceManager()

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var debounceTask: Task<Void, Never>?
    private let debounceDuration: UInt64 = 1_000_000_000

    private var baseURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("CanvasWM", isDirectory: true)
    }

    private var workspacesURL: URL { baseURL.appendingPathComponent("workspaces", isDirectory: true) }
    private var workspaceListURL: URL { baseURL.appendingPathComponent("workspaces.json") }

    private init() {
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try? fileManager.createDirectory(at: workspacesURL, withIntermediateDirectories: true)
    }

    public func save(workspaceId: String, snapshotProvider: @escaping () -> CanvasData) {
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds: self?.debounceDuration ?? 1_000_000_000)
                let canvasData = snapshotProvider()
                try self?.writeToDisk(workspaceId: workspaceId, canvasData: canvasData)
            } catch is CancellationError {
            } catch { print("[PersistenceManager] Save failed: \(error)") }
        }
    }

    public func saveImmediate(workspaceId: String, canvasData: CanvasData) {
        try? writeToDisk(workspaceId: workspaceId, canvasData: canvasData)
    }

    private func writeToDisk(workspaceId: String, canvasData: CanvasData) throws {
        let data = try encoder.encode(canvasData)
        try data.write(to: workspacesURL.appendingPathComponent("\(workspaceId).json"), options: .atomic)
    }

    public func load(workspaceId: String) -> CanvasData? {
        guard let data = try? Data(contentsOf: workspacesURL.appendingPathComponent("\(workspaceId).json")) else { return nil }
        return try? decoder.decode(CanvasData.self, from: data)
    }

    public func saveWorkspaces(_ workspaces: [Workspace]) {
        if let data = try? encoder.encode(workspaces) { try? data.write(to: workspaceListURL, options: .atomic) }
    }

    public func loadWorkspaces() -> [Workspace]? {
        guard let data = try? Data(contentsOf: workspaceListURL) else { return nil }
        return try? decoder.decode([Workspace].self, from: data)
    }

    public func listWorkspaces() -> [Workspace] { loadWorkspaces() ?? [] }
}
