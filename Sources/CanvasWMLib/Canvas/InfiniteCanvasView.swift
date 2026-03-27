import SwiftUI
import AppKit

public struct InfiniteCanvasView: View {
    @Bindable var canvasState: CanvasState

    public init(canvasState: CanvasState) { self.canvasState = canvasState }

    @State private var lastMouseLocation: CGPoint = .zero
    @State private var dragStart: CGPoint? = nil
    @State private var draggingWidgetId: String? = nil
    @State private var dragWidgetOrigin: CGSize = .zero

    public var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background with grid — receives pan gesture
                CanvasBackground(scale: canvasState.scale, panX: canvasState.panX, panY: canvasState.panY)

                // Drawing layer
                ForEach(sortedDrawings, id: \.id) { drawing in
                    DrawingPath(drawing: drawing, scale: canvasState.scale, panX: canvasState.panX, panY: canvasState.panY)
                        .allowsHitTesting(false)
                }

                // Frames (behind other widgets)
                ForEach(sortedFrames, id: \.id) { frame in
                    FrameWidgetView(frame: frame, isSelected: canvasState.selectedWidgetId == frame.id, canvasState: canvasState)
                        .position(widgetPosition(x: frame.x, y: frame.y, w: frame.width, h: frame.height))
                }

                // Sticky notes
                ForEach(sortedStickyNotes, id: \.id) { note in
                    StickyNoteView(note: note, isSelected: canvasState.selectedWidgetId == note.id, canvasState: canvasState)
                        .position(widgetPosition(x: note.x, y: note.y, w: note.width, h: note.height))
                }

                // Images
                ForEach(sortedImages, id: \.id) { img in
                    ImageWidgetView(imageModel: img, isSelected: canvasState.selectedWidgetId == img.id, canvasState: canvasState)
                        .position(widgetPosition(x: img.x, y: img.y, w: img.width, h: img.height))
                }

                // Markdowns
                ForEach(sortedMarkdowns, id: \.id) { md in
                    MarkdownWidgetView(note: md, isSelected: canvasState.selectedWidgetId == md.id, canvasState: canvasState)
                        .position(widgetPosition(x: md.x, y: md.y, w: md.width, h: md.height))
                }

                // Terminals
                ForEach(sortedTerminals, id: \.id) { term in
                    TerminalWidgetView(terminal: term, isSelected: canvasState.selectedWidgetId == term.id, canvasState: canvasState)
                        .position(widgetPosition(x: term.x, y: term.y, w: term.width, h: term.height))
                }

                // Browsers
                ForEach(sortedBrowsers, id: \.id) { browser in
                    BrowserWidgetView(browser: browser, isSelected: canvasState.selectedWidgetId == browser.id, canvasState: canvasState)
                        .position(widgetPosition(x: browser.x, y: browser.y, w: browser.width, h: browser.height))
                }

                // File managers
                ForEach(sortedFileManagers, id: \.id) { fm in
                    FileManagerWidgetView(fm: fm, isSelected: canvasState.selectedWidgetId == fm.id, canvasState: canvasState)
                        .position(widgetPosition(x: fm.x, y: fm.y, w: fm.width, h: fm.height))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle()) // Make entire area tappable
            .gesture(
                DragGesture(minimumDistance: 3)
                    .onChanged { value in
                        if canvasState.toolMode == .pen {
                            let world = ViewportMath.screenToWorld(screenX: value.location.x, screenY: value.location.y,
                                panX: canvasState.panX, panY: canvasState.panY, scale: canvasState.scale)
                            let point = DrawingPoint(x: world.worldX, y: world.worldY)
                            if canvasState.currentDrawingId == nil { canvasState.startDrawing(at: point) }
                            else { canvasState.continueDrawing(point: point) }
                        } else if draggingWidgetId == nil && dragStart == nil {
                            // First frame: hit-test to decide widget drag vs canvas pan
                            let world = ViewportMath.screenToWorld(screenX: value.startLocation.x, screenY: value.startLocation.y,
                                panX: canvasState.panX, panY: canvasState.panY, scale: canvasState.scale)
                            if let wid = canvasState.widgetAt(worldX: world.worldX, worldY: world.worldY),
                               let origin = canvasState.widgetOrigin(id: wid) {
                                draggingWidgetId = wid
                                dragWidgetOrigin = CGSize(width: origin.x, height: origin.y)
                                canvasState.bringToFront(id: wid)
                            } else {
                                dragStart = CGPoint(x: canvasState.panX, y: canvasState.panY)
                            }
                        }

                        if let wid = draggingWidgetId {
                            canvasState.moveWidget(id: wid,
                                x: dragWidgetOrigin.width + value.translation.width / canvasState.scale,
                                y: dragWidgetOrigin.height + value.translation.height / canvasState.scale)
                        } else if let start = dragStart {
                            canvasState.panX = start.x + value.translation.width
                            canvasState.panY = start.y + value.translation.height
                        }
                    }
                    .onEnded { _ in
                        if canvasState.toolMode == .pen { canvasState.finishDrawing() }
                        dragStart = nil
                        draggingWidgetId = nil
                        dragWidgetOrigin = .zero
                    }
            )
            .onTapGesture(count: 2) {
                let world = ViewportMath.screenToWorld(screenX: lastMouseLocation.x, screenY: lastMouseLocation.y,
                    panX: canvasState.panX, panY: canvasState.panY, scale: canvasState.scale)
                canvasState.addStickyNote(x: world.worldX, y: world.worldY)
            }
            .onTapGesture {
                canvasState.selectedWidgetId = nil
            }
            .onContinuousHover { phase in
                if case .active(let location) = phase { lastMouseLocation = location }
            }
            .background(
                ScrollGestureNSView { delta in
                    let zoomDelta = delta > 0 ? ViewportMath.zoomStep : -ViewportMath.zoomStep
                    let result = ViewportMath.zoomAtPoint(currentScale: canvasState.scale, delta: zoomDelta,
                        pointX: lastMouseLocation.x, pointY: lastMouseLocation.y,
                        panX: canvasState.panX, panY: canvasState.panY)
                    canvasState.scale = result.newScale
                    canvasState.panX = result.newPanX
                    canvasState.panY = result.newPanY
                }
            )
        }
    }

    private func widgetPosition(x: Double, y: Double, w: Double, h: Double) -> CGPoint {
        CGPoint(x: x * canvasState.scale + canvasState.panX + (w * canvasState.scale / 2),
                y: y * canvasState.scale + canvasState.panY + (h * canvasState.scale / 2))
    }

    private var sortedStickyNotes: [StickyNote] { canvasState.stickyNotes.values.sorted { $0.zIndex < $1.zIndex } }
    private var sortedFrames: [Frame] { canvasState.frames.values.sorted { $0.zIndex < $1.zIndex } }
    private var sortedImages: [ImageModel] { canvasState.images.values.sorted { $0.zIndex < $1.zIndex } }
    private var sortedMarkdowns: [MarkdownNote] { canvasState.markdowns.values.sorted { $0.zIndex < $1.zIndex } }
    private var sortedTerminals: [TerminalState] { canvasState.terminals.values.sorted { $0.zIndex < $1.zIndex } }
    private var sortedBrowsers: [BrowserState] { canvasState.browsers.values.sorted { $0.zIndex < $1.zIndex } }
    private var sortedFileManagers: [FileManagerState] { canvasState.fileManagers.values.sorted { $0.zIndex < $1.zIndex } }
    private var sortedDrawings: [Drawing] { canvasState.drawings.values.sorted { $0.zIndex < $1.zIndex } }
}

// MARK: - Drawing Path

struct DrawingPath: View {
    let drawing: Drawing
    let scale: Double
    let panX: Double
    let panY: Double

    var body: some View {
        Path { path in
            guard let first = drawing.points.first else { return }
            path.move(to: worldToScreen(first))
            for point in drawing.points.dropFirst() { path.addLine(to: worldToScreen(point)) }
        }
        .stroke(Color(hex: drawing.color) ?? .black, lineWidth: drawing.strokeWidth * scale)
    }

    private func worldToScreen(_ point: DrawingPoint) -> CGPoint {
        let screen = ViewportMath.worldToScreen(worldX: point.x, worldY: point.y, panX: panX, panY: panY, scale: scale)
        return CGPoint(x: screen.screenX, y: screen.screenY)
    }
}

// MARK: - Grid Background

struct CanvasBackground: View {
    let scale: Double
    let panX: Double
    let panY: Double

    var body: some View {
        GeometryReader { geometry in
            let gridSize = 40.0 * scale
            let offsetX = panX.truncatingRemainder(dividingBy: gridSize)
            let offsetY = panY.truncatingRemainder(dividingBy: gridSize)

            Path { path in
                let cols = Int(geometry.size.width / gridSize) + 2
                let rows = Int(geometry.size.height / gridSize) + 2
                for col in 0...cols {
                    let x = Double(col) * gridSize + offsetX
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                }
                for row in 0...rows {
                    let y = Double(row) * gridSize + offsetY
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                }
            }
            .stroke(Color.gray.opacity(0.15), lineWidth: scale > 0.5 ? 0.5 : 0.25)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
}

// MARK: - Scroll Gesture (NSView-based for scroll wheel capture)

struct ScrollGestureNSView: NSViewRepresentable {
    let onScroll: (Double) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = ScrollInterceptView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        (nsView as? ScrollInterceptView)?.onScroll = onScroll
    }
}

final class ScrollInterceptView: NSView {
    var onScroll: ((Double) -> Void)?

    override func scrollWheel(with event: NSEvent) {
        let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY : event.scrollingDeltaY * 3
        onScroll?(delta)
    }
}
