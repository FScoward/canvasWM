import SwiftUI

/// Floating markdown editor/viewer with live preview
struct DesktopMarkdownView: View {
    @Binding var note: DesktopMarkdownNote
    let onDelete: () -> Void
    let onChanged: () -> Void
    @State private var showEditor = true

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if showEditor {
                editorView
            } else {
                previewView
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Image(systemName: "doc.richtext")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
            Text("Markdown")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
            Spacer()
            Button(action: { showEditor.toggle() }) {
                Image(systemName: showEditor ? "eye" : "pencil")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help(showEditor ? "Preview" : "Edit")
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }

    private var editorView: some View {
        TextEditor(text: $note.text)
            .font(.system(size: 13, design: .monospaced))
            .scrollContentBackground(.hidden)
            .padding(4)
            .onChange(of: note.text) { _, _ in onChanged() }
    }

    private var previewView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(note.text.components(separatedBy: "\n").enumerated()), id: \.offset) { _, line in
                    markdownLine(line)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
        }
    }

    @ViewBuilder
    private func markdownLine(_ line: String) -> some View {
        if line.hasPrefix("### ") {
            Text(line.dropFirst(4))
                .font(.system(size: 14, weight: .semibold))
                .padding(.top, 4)
        } else if line.hasPrefix("## ") {
            Text(line.dropFirst(3))
                .font(.system(size: 16, weight: .bold))
                .padding(.top, 6)
        } else if line.hasPrefix("# ") {
            Text(line.dropFirst(2))
                .font(.system(size: 20, weight: .bold))
                .padding(.top, 8)
        } else if line.hasPrefix("- ") {
            HStack(alignment: .top, spacing: 4) {
                Text("•").font(.system(size: 13))
                Text(line.dropFirst(2)).font(.system(size: 13))
            }
        } else if line.hasPrefix("```") {
            Text(line).font(.system(size: 12, design: .monospaced))
                .foregroundColor(.secondary)
        } else if line.trimmingCharacters(in: .whitespaces).isEmpty {
            Spacer().frame(height: 6)
        } else {
            Text(line).font(.system(size: 13))
        }
    }
}
