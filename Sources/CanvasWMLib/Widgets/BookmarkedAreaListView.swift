import SwiftUI

struct BookmarkedAreaListView: View {
    @Bindable var canvasState: CanvasState
    @State private var editingId: String? = nil
    @State private var editingName: String = ""

    var sortedAreas: [BookmarkedArea] {
        canvasState.bookmarkedAreas.values.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Bookmarks")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if sortedAreas.isEmpty {
                Text("No bookmarks yet.\nUse Cmd+Shift+B to bookmark the current view.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(sortedAreas) { area in
                            BookmarkedAreaRow(
                                area: area,
                                isEditing: editingId == area.id,
                                editingName: editingId == area.id ? $editingName : .constant(""),
                                onJump: { canvasState.jumpToArea(id: area.id) },
                                onStartRename: {
                                    editingId = area.id
                                    editingName = area.name
                                },
                                onCommitRename: {
                                    if !editingName.isEmpty {
                                        canvasState.renameBookmarkedArea(id: area.id, name: editingName)
                                    }
                                    editingId = nil
                                },
                                onDelete: { canvasState.deleteBookmarkedArea(id: area.id) }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
            }
        }
        .frame(width: 220)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
}

private struct BookmarkedAreaRow: View {
    let area: BookmarkedArea
    let isEditing: Bool
    @Binding var editingName: String
    let onJump: () -> Void
    let onStartRename: () -> Void
    let onCommitRename: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 10))
                .foregroundColor(.accentColor)

            if isEditing {
                TextField("Name", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit { onCommitRename() }
            } else {
                Text(area.name)
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text(String(format: "%.0f%%", area.scale * 100))
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))
        .contentShape(Rectangle())
        .onTapGesture { onJump() }
        .contextMenu {
            Button("Rename") { onStartRename() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}
