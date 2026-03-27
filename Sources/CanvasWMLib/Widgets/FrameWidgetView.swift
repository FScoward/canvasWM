import SwiftUI

public struct FrameWidgetView: View {
    let frame: Frame
    let isSelected: Bool
    @Bindable var canvasState: CanvasState
    @State private var isEditingLabel = false
    @State private var editLabel: String = ""
    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                if isEditingLabel {
                    TextField("Label", text: $editLabel, onCommit: {
                        canvasState.updateFrameLabel(id: frame.id, label: editLabel)
                        isEditingLabel = false
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold))
                } else {
                    Text(frame.label)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Color(hex: frame.borderColor) ?? .blue)
                        .onTapGesture(count: 2) { editLabel = frame.label; isEditingLabel = true }
                }
                Spacer()
                Button(action: { canvasState.deleteFrame(id: frame.id) }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)

            Spacer()
        }
        .frame(width: frame.width * canvasState.scale, height: frame.height * canvasState.scale)
        .background((Color(hex: frame.backgroundColor) ?? .blue.opacity(0.06)).opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(hex: frame.borderColor) ?? .blue, lineWidth: isSelected ? 2.5 : 1.5)
                .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 3]))
        )
        .cornerRadius(6)
        .onTapGesture { canvasState.bringToFront(id: frame.id) }
    }
}
