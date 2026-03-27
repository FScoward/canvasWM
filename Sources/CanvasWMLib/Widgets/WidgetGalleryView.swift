import SwiftUI

struct WidgetGalleryItem: Identifiable {
    let id = UUID()
    let kind: WidgetKind
    let name: String
    let icon: String
    let description: String
}

public struct WidgetGalleryView: View {
    @Bindable var canvasState: CanvasState
    let canvasSize: CGSize
    @Binding var isPresented: Bool

    private let items: [WidgetGalleryItem] = [
        WidgetGalleryItem(kind: .stickyNote, name: "Sticky Note", icon: "note.text.badge.plus",
                          description: "Quick notes on the canvas"),
        WidgetGalleryItem(kind: .markdown, name: "Markdown", icon: "doc.richtext",
                          description: "Rich text with Markdown"),
        WidgetGalleryItem(kind: .terminal, name: "Terminal", icon: "terminal",
                          description: "Embedded terminal"),
        WidgetGalleryItem(kind: .browser, name: "Browser", icon: "globe",
                          description: "Embedded web browser"),
        WidgetGalleryItem(kind: .frame, name: "Frame", icon: "rectangle.dashed",
                          description: "Group widgets together"),
        WidgetGalleryItem(kind: .fileManager, name: "File Manager", icon: "folder",
                          description: "Browse local files"),
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Widget")
                .font(.headline)
                .padding(.horizontal, 4)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(items) { item in
                    WidgetPreviewCard(item: item) {
                        addWidget(kind: item.kind)
                        isPresented = false
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    private func addWidget(kind: WidgetKind) {
        let world = ViewportMath.screenToWorld(
            screenX: canvasSize.width / 2, screenY: canvasSize.height / 2,
            panX: canvasState.panX, panY: canvasState.panY, scale: canvasState.scale)
        switch kind {
        case .stickyNote: canvasState.addStickyNote(x: world.worldX, y: world.worldY)
        case .markdown: canvasState.addMarkdown(x: world.worldX, y: world.worldY)
        case .terminal: _ = canvasState.addTerminal(x: world.worldX, y: world.worldY)
        case .browser: _ = canvasState.addBrowser(x: world.worldX, y: world.worldY)
        case .frame: canvasState.addFrame(x: world.worldX, y: world.worldY)
        case .fileManager: canvasState.addFileManager(x: world.worldX, y: world.worldY)
        case .image, .drawing: break
        }
    }
}

struct WidgetPreviewCard: View {
    let item: WidgetGalleryItem
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 6) {
            widgetMiniPreview(kind: item.kind)
                .frame(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack(spacing: 4) {
                Image(systemName: item.icon)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text(item.name)
                    .font(.system(size: 12, weight: .medium))
            }

            Text(item.description)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isHovered ? Color.accentColor.opacity(0.08) : Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor.opacity(0.4) : Color.gray.opacity(0.2), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture { onTap() }
    }

    @ViewBuilder
    private func widgetMiniPreview(kind: WidgetKind) -> some View {
        switch kind {
        case .stickyNote:
            stickyNotePreview
        case .markdown:
            markdownPreview
        case .terminal:
            terminalPreview
        case .browser:
            browserPreview
        case .frame:
            framePreview
        case .fileManager:
            fileManagerPreview
        default:
            Color.gray.opacity(0.1)
        }
    }

    private var stickyNotePreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Note").font(.system(size: 7, weight: .medium)).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Color.yellow.opacity(0.3))

            Text("Hello, World!\nThis is a sticky note.")
                .font(.system(size: 7))
                .foregroundColor(.primary)
                .padding(.horizontal, 4)
            Spacer()
        }
        .background(Color(red: 1.0, green: 0.98, blue: 0.8))
        .cornerRadius(3)
    }

    private var markdownPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("Markdown").font(.system(size: 7, weight: .medium)).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Color.purple.opacity(0.1))

            VStack(alignment: .leading, spacing: 1) {
                Text("# Title").font(.system(size: 8, weight: .bold))
                Text("Some **paragraph** text.").font(.system(size: 7))
                Text("- Item 1").font(.system(size: 7))
                Text("- Item 2").font(.system(size: 7))
            }
            .padding(.horizontal, 4)
            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(3)
    }

    private var terminalPreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 2) {
                Circle().fill(Color.green).frame(width: 4, height: 4)
                Text("Terminal").font(.system(size: 7, weight: .medium)).foregroundColor(.gray)
                Spacer()
            }
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Color.black.opacity(0.8))

            VStack(alignment: .leading, spacing: 1) {
                Text("$ ls -la").font(.system(size: 7, design: .monospaced)).foregroundColor(.green)
                Text("drwxr-xr-x  5 user").font(.system(size: 6, design: .monospaced)).foregroundColor(.gray)
                Text("-rw-r--r--  1 user").font(.system(size: 6, design: .monospaced)).foregroundColor(.gray)
                Text("> _").font(.system(size: 7, design: .monospaced)).foregroundColor(.white)
            }
            .padding(4)
            Spacer()
        }
        .background(Color(red: 0.118, green: 0.118, blue: 0.118))
        .cornerRadius(3)
    }

    private var browserPreview: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                Image(systemName: "chevron.left").font(.system(size: 6)).foregroundColor(.secondary)
                Image(systemName: "chevron.right").font(.system(size: 6)).foregroundColor(.secondary)
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .frame(height: 10)
                    .overlay(
                        Text("https://example.com")
                            .font(.system(size: 6))
                            .foregroundColor(.secondary)
                    )
                Spacer()
            }
            .padding(.horizontal, 4).padding(.vertical, 3)
            .background(.bar)

            VStack(alignment: .leading, spacing: 2) {
                Text("Example Domain").font(.system(size: 8, weight: .bold))
                Text("This domain is for use in examples.").font(.system(size: 6)).foregroundColor(.secondary)
                RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.2)).frame(height: 6)
                    .overlay(Text("More info...").font(.system(size: 5)).foregroundColor(.blue))
            }
            .padding(4)
            Spacer()
        }
        .background(Color.white)
        .cornerRadius(3)
    }

    private var framePreview: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Group")
                .font(.system(size: 7, weight: .semibold))
                .foregroundColor(.blue)
                .padding(.horizontal, 4)
                .padding(.top, 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.blue.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 2]))
                .foregroundColor(.blue.opacity(0.5))
        )
        .cornerRadius(4)
    }

    private var fileManagerPreview: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text("~/Documents").font(.system(size: 7, weight: .medium)).foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4).padding(.vertical, 2)
            .background(Color.orange.opacity(0.1))

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 2) {
                    Image(systemName: "folder.fill").font(.system(size: 7)).foregroundColor(.blue)
                    Text("Projects").font(.system(size: 7))
                }
                HStack(spacing: 2) {
                    Image(systemName: "folder.fill").font(.system(size: 7)).foregroundColor(.blue)
                    Text("Downloads").font(.system(size: 7))
                }
                HStack(spacing: 2) {
                    Image(systemName: "doc.text").font(.system(size: 7)).foregroundColor(.secondary)
                    Text("readme.md").font(.system(size: 7))
                }
                HStack(spacing: 2) {
                    Image(systemName: "photo").font(.system(size: 7)).foregroundColor(.secondary)
                    Text("photo.png").font(.system(size: 7))
                }
            }
            .padding(.horizontal, 4)
            Spacer()
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(3)
    }
}
