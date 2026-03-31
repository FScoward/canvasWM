# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

CanvasWM is a macOS native spatial window manager built with Swift and SwiftUI. It captures real macOS windows onto an infinite canvas minimap, enabling spatial window arrangement. Activated via Option+Control toggle or menu bar toggle for persistent mode. Uses Accessibility API to move/resize real windows based on canvas viewport position.

Additionally, it provides floating desktop widgets (sticky notes, markdown editors, browsers) that sync with the viewport.

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

### State

- **`CanvasWMState`** (`@Observable`) — Window manager state. Tracks real macOS windows as `ManagedWindow` entries with `CGWindowID` and `pid_t`. Manages viewport position that maps canvas coordinates to screen coordinates. Also manages bookmarked areas.

### Coordinate System

`ViewportMath` (pure enum, no state) handles all coordinate transforms:
- **World coordinates** — Position on the infinite canvas (used by all window/widget models)
- **Screen coordinates** — Pixel position on display
- Transform: `screenToWorld`, `worldToScreen`, `zoomAtPoint` (zoom anchored at cursor)

`CanvasWMState.viewportX/Y` represents where the physical monitor "window" sits on the canvas. Windows within the viewport are shown on screen; others are hidden off-screen at (99999, 99999).

### Key Engine: `CanvasWMEngine`

Bidirectional sync between canvas and real macOS windows at 60fps:
- Canvas drag → moves real window via Accessibility API (`WindowCapture`)
- User moves real window on screen → detected and synced back to canvas position
- Periodic recapture (every 3s) detects new/closed windows
- External notification via `~/.canvaswm/notify` file (write app name to highlight matching windows)

### Focus Key Shortcut

`Cmd + Control + Enter` centers the viewport on the currently focused macOS window without opening the minimap. Uses a CGEvent tap registered in `CanvasWMWindowController.registerFocusKeyMonitor()`. Does not work in apps with Secure Keyboard Entry enabled (e.g. iTerm2).

### Floating Desktop Widgets

`StickyNoteWindowController` manages floating NSWindows (sticky notes, markdown, browser) as independent desktop windows. These sync with `CanvasWMEngine` viewport position.

## Swift Configuration

- Swift Tools Version: 6.0 with `.swiftLanguageMode(.v5)` (Swift 5 language mode)
- Minimum deployment: macOS 14
- Uses Swift Observation framework (`@Observable`, `@Bindable`)
- No external dependencies
