import SwiftUI
import AppKit

public struct FileManagerWidgetView: View {
    let fm: FileManagerState
    let isSelected: Bool
    @Bindable var canvasState: CanvasState
    @State private var entries: [FileEntry] = []

    struct FileEntry: Identifiable {
        let id: String
        let name: String
        let path: String
        let isDirectory: Bool
        let ext: String
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(abbreviatePath(fm.rootPath))
                    .font(.system(size: 11, weight: .medium)).foregroundColor(.secondary).lineLimit(1)
                Spacer()
                Button(action: changeRootDir) {
                    Image(systemName: "folder.badge.plus").font(.system(size: 11))
                }.buttonStyle(.plain)
                Button(action: { canvasState.deleteFileManager(id: fm.id) }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.orange.opacity(0.1))

            // File tree
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 1) {
                    ForEach(entries) { entry in
                        fileRow(entry: entry)
                    }
                }
                .padding(4)
            }
        }
        .frame(width: fm.width * canvasState.scale, height: fm.height * canvasState.scale)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 1, y: 1)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
        .onTapGesture { canvasState.bringToFront(id: fm.id) }
        .onAppear { loadDirectory(fm.rootPath) }
        .onChange(of: fm.rootPath) { _, newPath in loadDirectory(newPath) }
        .onChange(of: fm.expandedDirs) { _, _ in loadDirectory(fm.rootPath) }
    }

    @ViewBuilder
    private func fileRow(entry: FileEntry) -> some View {
        HStack(spacing: 4) {
            Image(systemName: entry.isDirectory ? "folder.fill" : fileIcon(ext: entry.ext))
                .foregroundColor(entry.isDirectory ? .blue : .secondary)
                .font(.system(size: 12))
            Text(entry.name).font(.system(size: 12)).lineLimit(1)
            Spacer()
        }
        .padding(.vertical, 2).padding(.horizontal, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            if entry.isDirectory {
                canvasState.toggleFileManagerDir(id: fm.id, dirPath: entry.path)
            } else {
                openFile(entry)
            }
        }
    }

    private func fileIcon(ext: String) -> String {
        switch ext.lowercased() {
        case "md", "txt": return "doc.text"
        case "png", "jpg", "jpeg", "gif", "webp": return "photo"
        case "swift", "js", "ts", "py": return "chevron.left.forwardslash.chevron.right"
        default: return "doc"
        }
    }

    private func openFile(_ entry: FileEntry) {
        let ext = entry.ext.lowercased()
        let world = ViewportMath.screenToWorld(screenX: (fm.x + fm.width + 20) * canvasState.scale + canvasState.panX,
                                                screenY: fm.y * canvasState.scale + canvasState.panY,
                                                panX: canvasState.panX, panY: canvasState.panY, scale: canvasState.scale)
        switch ext {
        case "md", "txt":
            if let content = try? String(contentsOfFile: entry.path, encoding: .utf8) {
                canvasState.addMarkdown(x: world.worldX, y: world.worldY, text: content)
            }
        case "png", "jpg", "jpeg", "gif", "webp":
            canvasState.addImage(x: world.worldX, y: world.worldY, src: entry.path)
        default:
            if let content = try? String(contentsOfFile: entry.path, encoding: .utf8) {
                canvasState.addMarkdown(x: world.worldX, y: world.worldY, text: "```\n\(content)\n```")
            }
        }
    }

    private func loadDirectory(_ rootPath: String) {
        let expandedPath = NSString(string: rootPath).expandingTildeInPath
        entries = listRecursive(path: expandedPath, depth: 0)
    }

    private func listRecursive(path: String, depth: Int) -> [FileEntry] {
        guard depth < 5 else { return [] }
        let mgr = FileManager.default
        guard let items = try? mgr.contentsOfDirectory(atPath: path) else { return [] }

        var result: [FileEntry] = []
        let sorted = items.filter { !$0.hasPrefix(".") }.sorted()

        // Directories first
        let dirs = sorted.filter { var isDir: ObjCBool = false; mgr.fileExists(atPath: "\(path)/\($0)", isDirectory: &isDir); return isDir.boolValue }
        let files = sorted.filter { !dirs.contains($0) }

        for dir in dirs {
            let fullPath = "\(path)/\(dir)"
            let indented = String(repeating: "  ", count: depth) + dir
            result.append(FileEntry(id: fullPath, name: indented, path: fullPath, isDirectory: true, ext: ""))
            if fm.expandedDirs.contains(fullPath) {
                result.append(contentsOf: listRecursive(path: fullPath, depth: depth + 1))
            }
        }
        for file in files {
            let fullPath = "\(path)/\(file)"
            let ext = (file as NSString).pathExtension
            let indented = String(repeating: "  ", count: depth) + file
            result.append(FileEntry(id: fullPath, name: indented, path: fullPath, isDirectory: false, ext: ext))
        }
        return result
    }

    private func changeRootDir() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            canvasState.fileManagers[fm.id]?.rootPath = url.path
        }
    }

    private func abbreviatePath(_ path: String) -> String {
        path.replacingOccurrences(of: NSHomeDirectory(), with: "~")
    }
}
