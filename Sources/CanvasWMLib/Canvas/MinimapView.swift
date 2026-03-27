import SwiftUI

public struct MinimapView: View {
    @Bindable var canvasState: CanvasState
    let canvasSize: CGSize

    private let minimapWidth: Double = 150
    private let minimapHeight: Double = 100

    public var body: some View {
        ZStack {
            minimapBackground
            widgetRects
            viewportRect
        }
        .frame(width: minimapWidth, height: minimapHeight)
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
        .gesture(dragGesture)
    }

    private var minimapBackground: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(nsColor: .windowBackgroundColor).opacity(0.9))
            .frame(width: minimapWidth, height: minimapHeight)
    }

    private var widgetRects: some View {
        ForEach(allWidgetPositions, id: \.id) { widget in
            RoundedRectangle(cornerRadius: 1)
                .fill(widget.color)
                .frame(width: max(3, widget.minimapW), height: max(2, widget.minimapH))
                .position(x: widget.minimapX + widget.minimapW / 2,
                          y: widget.minimapY + widget.minimapH / 2)
        }
    }

    private var viewportRect: some View {
        Rectangle()
            .stroke(Color.blue.opacity(0.6), lineWidth: 1)
            .frame(width: viewportWidth, height: viewportHeight)
            .position(x: viewportCenterX, y: viewportCenterY)
    }

    private var dragGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let ratioX = value.location.x / minimapWidth
                let ratioY = value.location.y / minimapHeight
                let worldX = (ratioX - 0.5) * worldBoundsWidth
                let worldY = (ratioY - 0.5) * worldBoundsHeight
                canvasState.panX = -worldX * canvasState.scale + canvasSize.width / 2
                canvasState.panY = -worldY * canvasState.scale + canvasSize.height / 2
            }
    }

    private struct MinimapWidget: Identifiable {
        let id: String
        let minimapX: Double
        let minimapY: Double
        let minimapW: Double
        let minimapH: Double
        let color: Color
    }

    private func widget(_ id: String, _ x: Double, _ y: Double, _ w: Double, _ h: Double, _ color: Color) -> MinimapWidget {
        MinimapWidget(id: id, minimapX: toMinimapX(x), minimapY: toMinimapY(y),
                      minimapW: w / worldBoundsWidth * minimapWidth,
                      minimapH: h / worldBoundsHeight * minimapHeight, color: color)
    }

    private var allWidgetPositions: [MinimapWidget] {
        var widgets: [MinimapWidget] = []
        for (id, n) in canvasState.stickyNotes { widgets.append(widget(id, n.x, n.y, n.width, n.height, .yellow)) }
        for (id, f) in canvasState.frames { widgets.append(widget(id, f.x, f.y, f.width, f.height, .blue)) }
        for (id, t) in canvasState.terminals { widgets.append(widget(id, t.x, t.y, t.width, t.height, .green)) }
        for (id, b) in canvasState.browsers { widgets.append(widget(id, b.x, b.y, b.width, b.height, .orange)) }
        for (id, m) in canvasState.markdowns { widgets.append(widget(id, m.x, m.y, m.width, m.height, .purple)) }
        for (id, i) in canvasState.images { widgets.append(widget(id, i.x, i.y, i.width, i.height, .pink)) }
        for (id, f) in canvasState.fileManagers { widgets.append(widget(id, f.x, f.y, f.width, f.height, .orange)) }
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
