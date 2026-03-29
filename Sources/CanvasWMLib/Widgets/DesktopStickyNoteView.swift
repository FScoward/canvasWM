import SwiftUI
import AppKit

/// NSView that initiates window drag on mouseDown
struct WindowDragAreaView: NSViewRepresentable {
    func makeNSView(context: Context) -> DragNSView { DragNSView() }
    func updateNSView(_ nsView: DragNSView, context: Context) {}

    class DragNSView: NSView {
        override func mouseDown(with event: NSEvent) {
            window?.performDrag(with: event)
        }
    }
}

/// SwiftUI view for a floating desktop sticky note
struct DesktopStickyNoteView: View {
    @Binding var note: DesktopStickyNote
    let onDelete: () -> Void
    let onChanged: () -> Void
    @FocusState private var textFocused: Bool

    private var bgColor: Color {
        let hex = DesktopStickyNote.colors[note.colorName]?.bg ?? "#FFF9C4"
        return Color(hex: hex) ?? .yellow.opacity(0.3)
    }

    private var titleBgColor: Color {
        let hex = DesktopStickyNote.colors[note.colorName]?.titleBg ?? "#FFF176"
        return Color(hex: hex) ?? .yellow
    }

    var body: some View {
        VStack(spacing: 0) {
            titleBar
            contentArea
        }
        .background(bgColor)
    }

    private var titleBar: some View {
        HStack(spacing: 6) {
            colorDots
            Spacer()
                .overlay(WindowDragAreaView())
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.black.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(titleBgColor.opacity(0.8))
    }

    private var colorDots: some View {
        let sortedKeys = DesktopStickyNote.colors.keys.sorted()
        return ForEach(sortedKeys, id: \.self) { colorName in
            let titleHex = DesktopStickyNote.colors[colorName]?.titleBg ?? "#FFF176"
            let dotColor = Color(hex: titleHex) ?? .yellow
            Circle()
                .fill(dotColor)
                .frame(width: 10, height: 10)
                .overlay(
                    Circle().stroke(Color.black.opacity(0.3), lineWidth: note.colorName == colorName ? 1.5 : 0)
                )
                .onTapGesture {
                    note.colorName = colorName
                    onChanged()
                }
        }
    }

    private var contentArea: some View {
        TextEditor(text: $note.text)
            .font(.system(size: 14))
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .padding(6)
            .focused($textFocused)
            .onChange(of: note.text) { _, _ in onChanged() }
    }
}
