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
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            if sortedAreas.isEmpty {
                Text("No bookmarks yet.\nUse Cmd+Shift+B to bookmark the current view.")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .padding(16)
            } else {
                ScrollView {
                    LazyVStack(spacing: 3) {
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
        }
        .frame(width: 280)
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
        HStack(spacing: 8) {
            Image(systemName: "bookmark.fill")
                .font(.system(size: 12))
                .foregroundColor(.accentColor)

            if isEditing {
                TextField("Name", text: $editingName)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { onCommitRename() }
            } else {
                Text(area.name)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Text(String(format: "%.0f%%", area.scale * 100))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.04)))
        .contentShape(Rectangle())
        .onTapGesture { onJump() }
        .contextMenu {
            Button("Rename") { onStartRename() }
            Button("Delete", role: .destructive) { onDelete() }
        }
    }
}
