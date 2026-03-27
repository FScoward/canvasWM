# CanvasWM

A macOS native **canvas-based window manager** built with Swift and SwiftUI. Place widgets on an infinite canvas, or manage real macOS windows spatially through a minimap overlay.

## Features

### Canvas Mode

An infinite, pannable and zoomable canvas where you place and organize widgets:

- **Sticky Notes** - Quick text notes with customizable font size and colors
- **Markdown Editor** - Write and preview Markdown documents
- **Terminal** - Embedded terminal emulator with PTY support
- **Browser** - Inline web browser widget
- **File Manager** - Browse files directly on the canvas
- **Image** - Display images on the canvas
- **Frame** - Group widgets visually with labeled frames
- **Drawing** - Freehand drawing with path simplification

All widgets support drag, resize, z-ordering, and selection. Workspaces are persisted automatically as JSON.

### Tiling WM Mode

A minimap overlay that captures your real macOS windows onto the infinite canvas:

- **Bidirectional sync** at 30fps - drag windows on the minimap to move real windows, and vice versa
- **Spatial arrangement** - organize windows beyond your physical screen by panning the viewport
- **Auto-capture** - new windows are detected and added every 3 seconds
- **External notification** - write an app name to `~/.canvaswm/notify` to highlight matching windows
- **Floating desktop widgets** - sticky notes, Markdown editors, and browsers as independent desktop windows that sync with the viewport

| Shortcut | Action |
|----------|--------|
| `Option + Control` (hold) | Show minimap while held |
| `Ctrl + T` | Toggle persistent minimap mode |

### Menu Bar

CanvasWM lives in your menu bar with quick access to:

- Show/hide the canvas window
- Create new sticky notes (`N`), Markdown docs (`M`), or browsers (`B`)
- Toggle Tiling WM mode

### Workspaces

Switch between multiple workspaces via the sidebar. Each workspace saves its own set of widgets, positions, and layout. Data is stored at:

```
~/Library/Application Support/CanvasWM/workspaces/{workspaceId}.json
```

## Requirements

- macOS 14 (Sonoma) or later
- Accessibility permissions (required for Tiling WM mode to move/resize windows)

## Build & Run

```bash
# Build
swift build

# Run
swift run CanvasWM

# Run tests
swift run CanvasWMTests
```

No external dependencies. Built entirely with Swift 6.0 (Swift 5 language mode), AppKit, and SwiftUI.

## Architecture

```
Sources/CanvasWMLib/
├── CanvasWM/              # Tiling window manager
│   ├── CanvasWMEngine     # Bidirectional sync engine (30fps)
│   ├── CanvasWMState      # Viewport & managed window state
│   ├── CanvasWMWindowController  # Minimap toggle & lifecycle
│   └── CanvasWMOverlayView      # Minimap overlay UI
├── Canvas/                # Canvas views
│   ├── InfiniteCanvasView # Main pan/zoom canvas
│   └── MinimapView        # Canvas minimap
├── Widgets/               # Widget views (StickyNote, Terminal, Browser, etc.)
├── VirtualDesktop/        # macOS window capture & Accessibility API
├── Terminal/              # PTY session management
├── Models.swift           # All widget model structs
├── CanvasState.swift      # Widget canvas state (@Observable)
├── ViewportMath.swift     # Coordinate transforms (world <-> screen)
├── PersistenceManager.swift  # JSON workspace persistence
└── MainView.swift         # Root SwiftUI view
```

### Coordinate System

`ViewportMath` handles all coordinate transforms between:

- **World coordinates** - position on the infinite canvas
- **Screen coordinates** - pixel position on display

In Tiling WM mode, the viewport represents where the physical monitor sits on the canvas. Windows within the viewport are displayed on screen; windows outside are hidden off-screen.

## License

MIT
