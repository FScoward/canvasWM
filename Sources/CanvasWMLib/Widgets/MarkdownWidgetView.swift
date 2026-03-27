import SwiftUI

public struct MarkdownWidgetView: View {
    let note: MarkdownNote
    let isSelected: Bool
    @Bindable var canvasState: CanvasState
    @State private var isEditing = false
    @State private var editText: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Markdown").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Button(action: { isEditing.toggle(); if isEditing { editText = note.text } }) {
                    Image(systemName: isEditing ? "eye" : "pencil")
                        .font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
                Button(action: { canvasState.deleteMarkdown(id: note.id) }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.purple.opacity(0.1))

            if isEditing {
                TextEditor(text: $editText)
                    .font(.system(size: 13, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(6)
                    .onChange(of: editText) { _, newValue in
                        canvasState.updateMarkdownText(id: note.id, text: newValue)
                    }
            } else {
                ScrollView {
                    MarkdownRenderer(text: note.text)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                }
            }
        }
        .frame(width: note.width * canvasState.scale, height: note.height * canvasState.scale)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 1, y: 1)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
        .onTapGesture { canvasState.bringToFront(id: note.id) }
    }
}

struct MarkdownWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        let state = CanvasState()
        let note = MarkdownNote(id: "preview-1", x: 0, y: 0, width: 500, height: 400,
                                text: "# Title\n\n## Subtitle\n\nSome paragraph text.\n\n- Item 1\n- Item 2\n- Item 3\n\n### Code\n\n```\nlet x = 42\n```", zIndex: 0)
        MarkdownWidgetView(note: note, isSelected: false, canvasState: state)
            .previewDisplayName("rendered")

        let state2 = CanvasState()
        let note2 = MarkdownNote(id: "preview-2", x: 0, y: 0, text: "", zIndex: 0)
        MarkdownWidgetView(note: note2, isSelected: false, canvasState: state2)
            .previewDisplayName("empty")
    }
}

struct MarkdownRenderer: View {
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                renderLine(line)
            }
        }
    }

    @ViewBuilder
    private func renderLine(_ line: String) -> some View {
        if line.hasPrefix("### ") {
            Text(String(line.dropFirst(4))).font(.system(size: 15, weight: .semibold))
        } else if line.hasPrefix("## ") {
            Text(String(line.dropFirst(3))).font(.system(size: 17, weight: .bold))
        } else if line.hasPrefix("# ") {
            Text(String(line.dropFirst(2))).font(.system(size: 20, weight: .bold))
        } else if line.hasPrefix("- ") || line.hasPrefix("* ") {
            HStack(alignment: .top, spacing: 4) {
                Text("•").font(.system(size: 13))
                Text(renderInline(String(line.dropFirst(2)))).font(.system(size: 13))
            }
        } else if line.hasPrefix("```") {
            Text(line).font(.system(size: 12, design: .monospaced)).foregroundColor(.secondary)
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 4)
        } else {
            Text(renderInline(line)).font(.system(size: 13))
        }
    }

    private func renderInline(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        // Bold: **text**
        if let range = result.range(of: "**") {
            _ = range // Basic inline rendering — full implementation would parse markdown AST
        }
        return result
    }
}
