import SwiftUI
import AppKit

public struct ImageWidgetView: View {
    let imageModel: ImageModel
    let isSelected: Bool
    @Bindable var canvasState: CanvasState
    @State private var nsImage: NSImage?

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Image").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Button(action: { canvasState.deleteImage(id: imageModel.id) }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color.gray.opacity(0.1))

            if let nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Text("Loading...")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: imageModel.width * canvasState.scale, height: imageModel.height * canvasState.scale)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(4)
        .shadow(color: .black.opacity(0.1), radius: 3, x: 1, y: 1)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
        .onTapGesture { canvasState.bringToFront(id: imageModel.id) }
        .onAppear { loadImage() }
    }

    init(imageModel: ImageModel, isSelected: Bool, canvasState: CanvasState, previewImage: NSImage? = nil) {
        self.imageModel = imageModel
        self.isSelected = isSelected
        self.canvasState = canvasState
        self._nsImage = State(initialValue: previewImage)
    }

    private func loadImage() {
        guard nsImage == nil else { return }
        if imageModel.src.hasPrefix("/") || imageModel.src.hasPrefix("~") {
            let path = NSString(string: imageModel.src).expandingTildeInPath
            nsImage = NSImage(contentsOfFile: path)
        } else if let url = URL(string: imageModel.src) {
            Task {
                if let (data, _) = try? await URLSession.shared.data(from: url) {
                    await MainActor.run { nsImage = NSImage(data: data) }
                }
            }
        }
    }
}

struct ImageWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        let state = CanvasState()
        let img = ImageModel(id: "preview-1", x: 0, y: 0, width: 400, height: 300, src: "", zIndex: 0)
        let placeholder = NSImage(size: NSSize(width: 400, height: 300), flipped: false) { rect in
            NSColor.systemBlue.withAlphaComponent(0.3).setFill()
            rect.fill()
            let text = "Preview Image" as NSString
            let attrs: [NSAttributedString.Key: Any] = [
                .foregroundColor: NSColor.white,
                .font: NSFont.systemFont(ofSize: 24, weight: .bold)
            ]
            let size = text.size(withAttributes: attrs)
            text.draw(at: NSPoint(x: (rect.width - size.width) / 2, y: (rect.height - size.height) / 2), withAttributes: attrs)
            return true
        }
        ImageWidgetView(imageModel: img, isSelected: false, canvasState: state, previewImage: placeholder)
            .previewDisplayName("with placeholder")

        let state2 = CanvasState()
        let img2 = ImageModel(id: "preview-2", x: 0, y: 0, width: 400, height: 300, src: "", zIndex: 0)
        ImageWidgetView(imageModel: img2, isSelected: false, canvasState: state2)
            .previewDisplayName("loading")
    }
}
