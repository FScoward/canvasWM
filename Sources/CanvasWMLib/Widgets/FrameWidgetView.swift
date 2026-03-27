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

struct FrameWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        let state = CanvasState()
        let frame = Frame(id: "preview-1", x: 0, y: 0, width: 400, height: 300,
                          label: "Feature Group", borderColor: "#3B82F6", backgroundColor: "#3B82F610", zIndex: 0)
        FrameWidgetView(frame: frame, isSelected: false, canvasState: state)
            .previewDisplayName("blue")

        let state2 = CanvasState()
        let frame2 = Frame(id: "preview-2", x: 0, y: 0, width: 400, height: 300,
                           label: "Selected Group", borderColor: "#10B981", backgroundColor: "#10B98110", zIndex: 0)
        FrameWidgetView(frame: frame2, isSelected: true, canvasState: state2)
            .previewDisplayName("selected green")
    }
}
