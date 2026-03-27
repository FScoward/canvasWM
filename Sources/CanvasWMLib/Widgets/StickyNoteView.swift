import SwiftUI

public struct StickyNoteView: View {
    let note: StickyNote
    let isSelected: Bool
    @Bindable var canvasState: CanvasState
    @State private var isEditing = false
    @State private var editText: String = ""
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Note").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Button(action: { canvasState.deleteStickyNote(id: note.id) }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.yellow.opacity(0.3))

            if isEditing {
                TextEditor(text: $editText)
                    .font(.system(size: note.fontSize))
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .padding(6)
                    .onChange(of: editText) { _, newValue in
                        canvasState.updateStickyNoteText(id: note.id, text: newValue)
                    }
            } else {
                Text(note.text.isEmpty ? "Double-click to edit..." : note.text)
                    .font(.system(size: note.fontSize))
                    .foregroundColor(note.text.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(8)
            }
        }
        .frame(width: note.width * canvasState.scale, height: note.height * canvasState.scale)
        .background(Color(red: 1.0, green: 0.98, blue: 0.8))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 1, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
        .onTapGesture(count: 2) { isEditing = true; editText = note.text }
        .onTapGesture { canvasState.bringToFront(id: note.id) }
    }
}
