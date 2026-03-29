# CanvasWM

A macOS native **spatial window manager** built with Swift and SwiftUI.

Manage real macOS windows spatially through a minimap overlay on an infinite canvas.

**[日本語版は下にあります / Japanese version below](#canvaswm-日本語)**

---

## Table of Contents

- [Spatial WM](#spatial-wm)
- [Floating Widgets](#floating-widgets)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Menu Bar](#menu-bar)
- [External Integrations](#external-integrations)
- [Build & Run](#build--run)
- [Requirements](#requirements)
- [Architecture](#architecture)
- [License](#license)

---

## Spatial WM

Captures real macOS windows and manages them spatially on an infinite canvas minimap.

- **Bidirectional sync** (60fps): Drag windows on the minimap to move real windows, and vice versa
- **Spatial arrangement**: Pan the viewport to place windows beyond your physical monitor
- **Auto-capture**: New windows are detected and added every 3 seconds
- **Window highlighting**: External triggers highlight specific app windows for 5 seconds
- **Floating widgets**: Sticky notes, Markdown editors, and browsers as independent desktop windows that sync with the viewport

### Minimap Display Modes

| Mode | Action | Description |
|------|--------|-------------|
| Transient | Hold `Option + Control` | Hidden when keys are released |
| Persistent | Toggle with `Ctrl + T` | Stays visible until toggled off |

The minimap shows content previews for each window, bookmark regions, and monitor boundaries.

---

## Floating Widgets

Floating desktop widgets are independent NSWindows that sync with the spatial WM viewport.

### Sticky Note

Quick text notes. 5 color themes (yellow, green, blue, pink, orange). Available from the menu bar.

### Markdown Editor

Write and preview Markdown. Toggle between edit mode (monospaced font) and preview mode. Renders H1–H3 headings, bold/italic, code blocks, and lists.

### Browser

Embedded WebKit browser with back/forward/reload navigation and URL bar. Auto-prepends `https://` when the protocol is omitted.

---

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Esc` | Close minimap |
| `Option + Control` (hold) | Show minimap while held |
| `Ctrl + T` | Toggle persistent minimap |
| `Ctrl + R` | Refresh window capture |

---

## Menu Bar

CanvasWM lives in your menu bar with quick access to:

- **New Sticky Note** (`N`) – Create a floating sticky note
- **New Markdown** (`M`) – Create a floating Markdown editor
- **New Browser** (`B`) – Create a floating browser
- **Canvas WM** (`Ctrl+T`) – Toggle spatial WM minimap
- **Gather Windows on Quit** – Move all windows back to the monitor on quit (toggle)
- **Quit** (`Q`)

---

## External Integrations

### Window Highlight Notifications

Write an app name to `~/.canvaswm/notify` to highlight matching windows on the minimap for 5 seconds.

```bash
echo "Terminal" > ~/.canvaswm/notify
```

`CanvasWMEngine` polls this file every 0.5 seconds and deletes it after reading.

### Claude Code Integration

Configure a [Notification hook](https://docs.anthropic.com/en/docs/claude-code) in Claude Code to make terminal windows flash on the minimap when tasks complete.

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Terminal' > ~/.canvaswm/notify"
          }
        ]
      }
    ]
  }
}
```

Every time Claude Code sends a notification, the terminal window highlights on the minimap for visual confirmation.

---

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

---

## Requirements

- macOS 14 (Sonoma) or later
- Accessibility permissions (required for moving/resizing windows)

---

## Architecture

```
Sources/CanvasWMLib/
├── CanvasWM/              # Spatial window manager
│   ├── CanvasWMEngine     # Bidirectional sync engine (60fps)
│   ├── CanvasWMState      # Viewport & managed window state
│   ├── CanvasWMWindowController  # Minimap toggle & lifecycle
│   └── CanvasWMOverlayView      # WM minimap UI
├── Widgets/               # Floating desktop widgets
│   ├── Desktop*.swift     # Floating widget views (sticky note, markdown, browser)
│   └── StickyNoteWindowController  # Floating widget management
├── VirtualDesktop/        # macOS window capture & Accessibility API
├── Models.swift           # Model definitions (Desktop widgets, BookmarkedArea)
├── ViewportMath.swift     # Coordinate transforms (World ↔ Screen)
└── ColorExtension.swift   # Hex color parsing
```

### Coordinate System

`ViewportMath` handles all coordinate transforms:

- **World coordinates** – Position on the infinite canvas
- **Screen coordinates** – Pixel position on display

The viewport represents where the physical monitor sits on the canvas. Windows inside the viewport are shown on screen; windows outside are moved off-screen to (99999, 99999).

Data location:

```
~/Library/Application Support/CanvasWM/
├── sticky-notes.json          # Floating sticky notes
├── desktop-markdowns.json     # Floating Markdown widgets
└── desktop-browsers.json      # Floating browsers
```

---

## License

MIT

---
---

# CanvasWM (日本語)

macOS native の**空間ウィンドウマネージャー**。Swift / SwiftUI 製。

実際の macOS ウィンドウを無限キャンバス上のミニマップで空間的に管理できます。

---

## 目次

- [Spatial WM](#spatial-wm-1)
- [フローティングウィジェット](#フローティングウィジェット)
- [キーボードショートカット](#キーボードショートカット)
- [メニューバー](#メニューバー)
- [外部連携](#外部連携)
- [ビルド・実行](#ビルド実行)
- [動作要件](#動作要件)
- [アーキテクチャ](#アーキテクチャ)
- [ライセンス](#ライセンス-1)

---

## Spatial WM

実際の macOS ウィンドウをキャプチャし、無限キャンバス上のミニマップで空間的に管理します。

- **双方向同期** (60fps): ミニマップ上のウィンドウをドラッグすると実ウィンドウが移動し、逆も同様
- **空間配置**: ビューポートをパンして物理モニターの範囲外にウィンドウを配置可能
- **自動キャプチャ**: 3 秒ごとに新しいウィンドウを検出・追加
- **ウィンドウハイライト**: 外部トリガーで特定アプリのウィンドウを 5 秒間ハイライト表示
- **フローティングウィジェット**: 付箋・Markdown・ブラウザを独立したデスクトップウィンドウとして配置可能

### ミニマップの表示モード

| モード | 操作 | 説明 |
|--------|------|------|
| 一時表示 | `Option + Control` を押し続ける | キーを離すと非表示になる |
| 常時表示 | `Ctrl + T` でトグル | 再度押すまで表示し続ける |

ミニマップでは各ウィンドウの内容がプレビュー表示され、ブックマーク領域やモニター境界も視覚化されます。

---

## フローティングウィジェット

フローティングウィジェットは、Spatial WM のビューポートと同期する独立した NSWindow です。

### Sticky Note (付箋)

テキストをすばやくメモ。5 色のカラーテーマ (黄・緑・青・ピンク・オレンジ)。メニューバーから作成可能。

### Markdown Editor

Markdown の編集・プレビュー。編集モード (等幅フォント) とプレビューモードをトグルで切り替え。H1-H3 見出し、太字/斜体、コードブロック、リストをレンダリング。

### Browser

WebKit ベースのブラウザ。戻る/進む/リロードのナビゲーションと URL バーを搭載。プロトコル省略時は https:// を自動補完。

---

## キーボードショートカット

| ショートカット | アクション |
|----------------|------------|
| `Esc` | ミニマップを閉じる |
| `Option + Control` (押し続ける) | ミニマップを一時表示 |
| `Ctrl + T` | ミニマップの常時表示をトグル |
| `Ctrl + R` | ウィンドウキャプチャを更新 |

---

## メニューバー

CanvasWM はメニューバーに常駐し、以下の操作にすばやくアクセスできます:

- **New Sticky Note** (`N`) - フローティング付箋を作成
- **New Markdown** (`M`) - フローティング Markdown エディタを作成
- **New Browser** (`B`) - フローティングブラウザを作成
- **Canvas WM** (`Ctrl+T`) - Spatial WM ミニマップのトグル
- **Gather Windows on Quit** - 終了時にすべてのウィンドウをモニター内に戻す (トグル)
- **Quit** (`Q`)

---

## 外部連携

### ウィンドウハイライト通知

`~/.canvaswm/notify` ファイルにアプリ名を書き込むと、ミニマップ上で該当ウィンドウが 5 秒間ハイライトされます。

```bash
echo "Terminal" > ~/.canvaswm/notify
```

CanvasWMEngine が 0.5 秒間隔でこのファイルを監視し、読み取り後に自動削除します。

### Claude Code との連携

Claude Code の [Notification フック](https://docs.anthropic.com/en/docs/claude-code) を設定すると、タスク完了時にミニマップ上でターミナルウィンドウが光ります。

`~/.claude/settings.json` に以下を追加:

```json
{
  "hooks": {
    "Notification": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "echo 'Terminal' > ~/.canvaswm/notify"
          }
        ]
      }
    ]
  }
}
```

Claude Code が通知を発行するたびにミニマップ上のターミナルウィンドウがハイライトされ、作業完了を視覚的に確認できます。

---

## ビルド・実行

```bash
# ビルド
swift build

# 実行
swift run CanvasWM

# テスト
swift run CanvasWMTests
```

外部依存なし。Swift 6.0 (Swift 5 言語モード)、AppKit、SwiftUI のみで構築されています。

---

## 動作要件

- macOS 14 (Sonoma) 以降
- アクセシビリティ権限 (ウィンドウの移動・リサイズに必要)

---

## アーキテクチャ

```
Sources/CanvasWMLib/
├── CanvasWM/              # 空間ウィンドウマネージャー
│   ├── CanvasWMEngine     # 双方向同期エンジン (60fps)
│   ├── CanvasWMState      # ビューポート & マネージドウィンドウ状態
│   ├── CanvasWMWindowController  # ミニマップのトグル & ライフサイクル
│   └── CanvasWMOverlayView      # WM ミニマップ UI
├── Widgets/               # フローティングウィジェット
│   ├── Desktop*.swift     # フローティングウィジェットビュー (付箋、Markdown、ブラウザ)
│   └── StickyNoteWindowController  # フローティングウィジェット管理
├── VirtualDesktop/        # macOS ウィンドウキャプチャ & Accessibility API
├── Models.swift           # モデル定義 (デスクトップウィジェット、BookmarkedArea)
├── ViewportMath.swift     # 座標変換 (World ↔ Screen)
└── ColorExtension.swift   # Hex カラーパーサー
```

### 座標系

`ViewportMath` がすべての座標変換を担当:

- **World 座標**: 無限キャンバス上の位置
- **Screen 座標**: ディスプレイ上のピクセル位置

ビューポートは物理モニターがキャンバス上のどこに位置するかを表します。ビューポート内のウィンドウは画面に表示され、ビューポート外のウィンドウはオフスクリーン (99999, 99999) に移動されます。

データの保存先:

```
~/Library/Application Support/CanvasWM/
├── sticky-notes.json          # フローティング付箋
├── desktop-markdowns.json     # フローティング Markdown
└── desktop-browsers.json      # フローティングブラウザ
```

---

## ライセンス

MIT
