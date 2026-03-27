# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CanvasWM is a macOS native canvas-based window manager built with Swift and SwiftUI. It has two modes:

1. **Canvas Mode** — An infinite canvas app (SwiftUI `WindowGroup`) where users place widgets (sticky notes, terminals, browsers, markdown editors, file managers, frames, drawings, images) on a pannable/zoomable surface with workspace persistence.
2. **Tiling WM Mode** — A minimap overlay that captures real macOS windows onto an infinite canvas, enabling spatial window arrangement. Activated via Option+Control toggle or Ctrl+T for persistent mode. Uses Accessibility API to move/resize real windows based on canvas viewport position.

## Build & Test Commands

```bash
# Build
swift build

# Run the app
swift run CanvasWM

# Run tests (custom test executable, not XCTest)
swift run CanvasWMTests
```

Tests use a custom assertion framework (not XCTest) defined in `Tests/CanvasWMTests/ViewportMathTests.swift` with `assert()` and `assertEqualDouble()` helpers. The test executable returns exit code 1 on failure.

## Architecture

### Two Separate State Systems

The app has two independent state trees that share `ViewportMath` for coordinate transforms:

- **`CanvasState`** (`@Observable`) — Widget canvas state. Manages all widget types as `[String: WidgetType]` dictionaries keyed by UUID. Handles CRUD, z-ordering, selection, and serialization to/from `CanvasData`.
- **`CanvasWMState`** (`@Observable`) — Window manager state. Tracks real macOS windows as `ManagedWindow` entries with `CGWindowID` and `pid_t`. Manages viewport position that maps canvas coordinates to screen coordinates.

### Coordinate System

`ViewportMath` (pure enum, no state) handles all coordinate transforms:
- **World coordinates** — Position on the infinite canvas (used by all widget/window models)
- **Screen coordinates** — Pixel position on display
- Transform: `screenToWorld`, `worldToScreen`, `zoomAtPoint` (zoom anchored at cursor)

In Tiling WM mode, the viewport concept is different: `CanvasWMState.viewportX/Y` represents where the physical monitor "window" sits on the canvas. Windows within the viewport are shown on screen; others are hidden off-screen at (99999, 99999).

### Key Engine: `CanvasWMEngine`

Bidirectional sync between canvas and real macOS windows at 30fps:
- Canvas drag → moves real window via Accessibility API (`WindowCapture`)
- User moves real window on screen → detected and synced back to canvas position
- Periodic recapture (every 3s) detects new/closed windows
- External notification via `~/.canvaswm/notify` file (write app name to highlight matching windows)

### Persistence

`PersistenceManager` (singleton) saves workspace data as JSON to `~/Library/Application Support/CanvasWM/workspaces/{workspaceId}.json`. Uses debounced saves (1s) with immediate save on app termination.

### Widget Architecture

All widgets follow the same pattern:
- Model struct in `Models.swift` (Codable, Identifiable, with static size constraints)
- CRUD methods on `CanvasState`
- SwiftUI view in `Widgets/` directory
- Rendered in `InfiniteCanvasView` sorted by zIndex

### Floating Desktop Widgets

`StickyNoteWindowController` manages floating NSWindows (sticky notes, markdown, browser) that exist outside the canvas as independent desktop windows. These sync with `CanvasWMEngine` viewport when Tiling WM is active.

## Swift Configuration

- Swift Tools Version: 6.0 with `.swiftLanguageMode(.v5)` (Swift 5 language mode)
- Minimum deployment: macOS 14
- Uses Swift Observation framework (`@Observable`, `@Bindable`)
- No external dependencies
