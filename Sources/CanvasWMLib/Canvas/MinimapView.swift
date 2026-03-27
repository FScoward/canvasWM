import SwiftUI

public struct MinimapView: View {
    @Bindable var canvasState: CanvasState
    let canvasSize: CGSize

    private let minimapWidth: Double = 150
    private let minimapHeight: Double = 100

    public var body: some View {
        ZStack {
            // Background
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
                .frame(width: minimapWidth, height: minimapHeight)

            // Widget dots
            ForEach(allWidgetPositions, id: \.id) { widget in
                Circle()
                    .fill(widget.color)
                    .frame(width: 4, height: 4)
                    .position(x: widget.minimapX, y: widget.minimapY)
            }

            // Viewport rectangle
            Rectangle()
                .stroke(Color.blue.opacity(0.6), lineWidth: 1)
                .frame(width: viewportWidth, height: viewportHeight)
                .position(x: viewportCenterX, y: viewportCenterY)
        }
        .frame(width: minimapWidth, height: minimapHeight)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    let ratioX = value.location.x / minimapWidth
                    let ratioY = value.location.y / minimapHeight
                    let worldX = (ratioX - 0.5) * worldBoundsWidth
                    let worldY = (ratioY - 0.5) * worldBoundsHeight
                    canvasState.panX = -worldX * canvasState.scale + canvasSize.width / 2
                    canvasState.panY = -worldY * canvasState.scale + canvasSize.height / 2
                }
        )
    }

    private struct MinimapWidget: Identifiable {
        let id: String
        let minimapX: Double
        let minimapY: Double
        let color: Color
    }

    private var allWidgetPositions: [MinimapWidget] {
        var widgets: [MinimapWidget] = []
        for (id, n) in canvasState.stickyNotes { widgets.append(MinimapWidget(id: id, minimapX: toMinimapX(n.x), minimapY: toMinimapY(n.y), color: .yellow)) }
        for (id, f) in canvasState.frames { widgets.append(MinimapWidget(id: id, minimapX: toMinimapX(f.x), minimapY: toMinimapY(f.y), color: .blue)) }
        for (id, t) in canvasState.terminals { widgets.append(MinimapWidget(id: id, minimapX: toMinimapX(t.x), minimapY: toMinimapY(t.y), color: .green)) }
        for (id, b) in canvasState.browsers { widgets.append(MinimapWidget(id: id, minimapX: toMinimapX(b.x), minimapY: toMinimapY(b.y), color: .orange)) }
        for (id, m) in canvasState.markdowns { widgets.append(MinimapWidget(id: id, minimapX: toMinimapX(m.x), minimapY: toMinimapY(m.y), color: .purple)) }
        for (id, i) in canvasState.images { widgets.append(MinimapWidget(id: id, minimapX: toMinimapX(i.x), minimapY: toMinimapY(i.y), color: .pink)) }
        for (id, f) in canvasState.fileManagers { widgets.append(MinimapWidget(id: id, minimapX: toMinimapX(f.x), minimapY: toMinimapY(f.y), color: .orange)) }
        return widgets
    }

    private var worldBoundsWidth: Double { max(canvasSize.width * 3, 3000) }
    private var worldBoundsHeight: Double { max(canvasSize.height * 3, 2000) }

    private func toMinimapX(_ worldX: Double) -> Double { (worldX / worldBoundsWidth + 0.5) * minimapWidth }
    private func toMinimapY(_ worldY: Double) -> Double { (worldY / worldBoundsHeight + 0.5) * minimapHeight }

    private var viewportWidth: Double { (canvasSize.width / canvasState.scale) / worldBoundsWidth * minimapWidth }
    private var viewportHeight: Double { (canvasSize.height / canvasState.scale) / worldBoundsHeight * minimapHeight }
    private var viewportCenterX: Double { toMinimapX(-canvasState.panX / canvasState.scale + canvasSize.width / 2 / canvasState.scale) }
    private var viewportCenterY: Double { toMinimapY(-canvasState.panY / canvasState.scale + canvasSize.height / 2 / canvasState.scale) }
}
