# CanvasWM

A macOS native **canvas-based window manager** built with Swift and SwiftUI.

Two modes: **Canvas Mode** for placing widgets on an infinite canvas, and **Tiling WM Mode** for spatially managing real macOS windows through a minimap overlay.

**[日本語版は下にあります / Japanese version below](#canvaswm-日本語)**

---

## Table of Contents

- [Canvas Mode](#canvas-mode)
- [Tiling WM Mode](#tiling-wm-mode)
- [Widgets](#widgets)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Menu Bar](#menu-bar)
- [Workspaces](#workspaces)
- [External Integrations](#external-integrations)
- [Build & Run](#build--run)
- [Requirements](#requirements)
- [Architecture](#architecture)
- [License](#license)

---

## Canvas Mode

An infinite, pannable and zoomable canvas for placing and organizing widgets.

- **Pan**: Drag on empty canvas area
- **Zoom**: Scroll wheel (0.1x – 5.0x)
- **Add widgets**: Click the "+ Add" button in the toolbar to open the gallery with visual previews
- **Pen tool**: Press `P` to switch to freehand drawing mode
- **Bookmarks**: Save the current viewport position with a name and jump back with one click
- **Minimap**: Bottom-right corner overview of the entire canvas; drag to pan

All widgets support drag, resize, z-ordering, and selection.

---

## Tiling WM Mode

Captures real macOS windows and manages them spatially on an infinite canvas minimap.

- **Bidirectional sync** (30fps): Drag windows on the minimap to move real windows, and vice versa
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

## Widgets

### Sticky Note

Quick text notes. 5 color themes (yellow, green, blue, pink, orange) and adjustable font size (12–28pt). Also available as floating desktop windows.

### Markdown Editor

Write and preview Markdown. Toggle between edit mode (monospaced font) and preview mode. Renders H1–H3 headings, bold/italic, code blocks, and lists.

### Terminal

Embedded PTY-based terminal. 7 color themes (dark, dracula, monokai, solarized, nord, tokyoNight, catppuccin). ANSI color support. Up to 10 per canvas.

### Browser

Embedded WebKit browser with back/forward/reload navigation and URL bar. Auto-prepends `https://` when the protocol is omitted. Up to 10 per canvas.

### File Manager

Browse directory trees. Double-click files to auto-generate widgets:
- Markdown/text files → Markdown widget
- Images (PNG/JPG/GIF/WebP) → Image widget
- Code files → Markdown widget with code block

### Frame

Labeled rectangles for visually grouping widgets. 6 preset colors (blue, green, orange, red, purple, gray). Double-click the label to edit.

### Image

Display images from local files or URLs. Auto-scales while preserving aspect ratio. Supports PNG, JPG, GIF, WebP.

### Drawing (Pen Tool)

Freehand drawing paths. Ramer-Douglas-Peucker algorithm for path simplification. Customizable color and stroke width.

---

## Keyboard Shortcuts

### Canvas Mode

| Shortcut | Action |
|----------|--------|
| `P` | Toggle pen tool |
| `Delete` | Delete selected widget |
| `Esc` | Deselect all |
| `Cmd + B` | Toggle bookmark list panel |
| `Cmd + Shift + B` | Bookmark current viewport |
| Double-click (empty area) | Add sticky note |
| Scroll wheel | Zoom |

### Tiling WM Mode

| Shortcut | Action |
|----------|--------|
| `Option + Control` (hold) | Show minimap while held |
| `Ctrl + T` | Toggle persistent minimap |
| `Ctrl + R` | Refresh window capture |
| `Esc` | Close minimap / deactivate WM |
| Scroll wheel | Zoom minimap |

---

## Menu Bar

CanvasWM lives in your menu bar with quick access to:

- **Show Canvas** – Show/hide the canvas window
- **New Sticky Note** (`N`) – Create a sticky note
- **New Markdown** (`M`) – Create a Markdown widget
- **New Browser** (`B`) – Create a browser widget
- **Canvas WM** (`Ctrl+T`) – Toggle Tiling WM mode
- **Gather Windows on Quit** – Move all windows back to the monitor on quit (toggle)
- **Quit** (`Q`)

---

## Workspaces

Switch between workspaces via the left sidebar. Each workspace independently maintains widget layout, zoom level, pan position, and bookmarks.

Data location:

```
~/Library/Application Support/CanvasWM/
├── workspaces.json                    # Workspace list
├── workspaces/{workspaceId}.json      # Canvas state per workspace
├── sticky-notes.json                  # Floating sticky notes
├── desktop-markdowns.json             # Floating Markdown widgets
└── desktop-browsers.json              # Floating browsers
```

Auto-saved with 1-second debounce, plus immediate save on app termination.

---

## External Integrations

### Window Highlight Notifications

Write an app name to `~/.canvaswm/notify` to highlight matching windows on the Tiling WM minimap for 5 seconds.

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
- Accessibility permissions (required for Tiling WM mode to move/resize windows)

---

## Architecture

```
Sources/CanvasWMLib/
├── Canvas/                # Canvas views
│   ├── InfiniteCanvasView # Pannable/zoomable infinite canvas
│   └── MinimapView        # Canvas minimap + bookmark display
├── CanvasWM/              # Tiling window manager
│   ├── CanvasWMEngine     # Bidirectional sync engine (30fps)
│   ├── CanvasWMState      # Viewport & managed window state
│   ├── CanvasWMWindowController  # Minimap toggle & lifecycle
│   └── CanvasWMOverlayView      # WM minimap UI
├── Widgets/               # Widget views
│   ├── *WidgetView.swift  # SwiftUI views for each widget
│   ├── Desktop*.swift     # Floating desktop widgets
│   ├── StickyNoteWindowController  # Floating widget management
│   └── WidgetGalleryView  # Widget add gallery
├── VirtualDesktop/        # macOS window capture & Accessibility API
├── Terminal/              # PTY session management
├── Models.swift           # All widget model definitions
├── CanvasState.swift      # Canvas state (@Observable)
├── ViewportMath.swift     # Coordinate transforms (World ↔ Screen)
├── PersistenceManager.swift  # JSON workspace persistence
└── MainView.swift         # Root SwiftUI view
```

### Coordinate System

`ViewportMath` handles all coordinate transforms:

- **World coordinates** – Position on the infinite canvas
- **Screen coordinates** – Pixel position on display

In Tiling WM mode, the viewport represents where the physical monitor sits on the canvas. Windows inside the viewport are shown on screen; windows outside are moved off-screen to (99999, 99999).

---

## License

MIT

---
---

# CanvasWM (日本語)

macOS native の**キャンバスベース・ウィンドウマネージャー**。Swift / SwiftUI 製。

無限キャンバスにウィジェットを自由配置する **Canvas Mode** と、実際の macOS ウィンドウをミニマップで空間管理する **Tiling WM Mode** の 2 つのモードを搭載しています。

---

## 目次

- [Canvas Mode](#canvas-mode)
- [Tiling WM Mode](#tiling-wm-mode)
- [ウィジェット一覧](#ウィジェット一覧)
- [キーボードショートカット](#キーボードショートカット)
- [メニューバー](#メニューバー)
- [ワークスペース](#ワークスペース)
- [外部連携](#外部連携)
- [ビルド・実行](#ビルド実行)
- [動作要件](#動作要件)
- [アーキテクチャ](#アーキテクチャ)
- [ライセンス](#ライセンス)

---

## Canvas Mode

パン・ズーム可能な無限キャンバス上にウィジェットを配置・整理するモードです。

- **パン**: 空きエリアをドラッグ
- **ズーム**: スクロールホイール (0.1x ~ 5.0x)
- **ウィジェット追加**: ツールバーの「+ Add」ボタンからギャラリーを開き、プレビューを見ながら選択
- **ペンツール**: `P` キーでフリーハンド描画モードに切り替え
- **ブックマーク**: 現在のビューポート位置を名前付きで保存し、ワンクリックで復帰
- **ミニマップ**: 右下にキャンバス全体の概要を表示。ドラッグでパン操作可能

すべてのウィジェットはドラッグ移動・リサイズ・Z オーダー変更・選択に対応しています。

---

## Tiling WM Mode

実際の macOS ウィンドウをキャプチャし、無限キャンバス上のミニマップで空間的に管理するモードです。

- **双方向同期** (30fps): ミニマップ上のウィンドウをドラッグすると実ウィンドウが移動し、逆も同様
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

## ウィジェット一覧

### Sticky Note (付箋)

テキストをすばやくメモするウィジェット。5 色のカラーテーマ (黄・緑・青・ピンク・オレンジ) とフォントサイズ変更 (12-28pt) に対応。デスクトップ上のフローティングウィンドウとしても使用可能。

### Markdown Editor

Markdown の編集・プレビューウィジェット。編集モード (等幅フォント) とプレビューモードをトグルで切り替え。H1-H3 見出し、太字/斜体、コードブロック、リストをレンダリング。

### Terminal

PTY ベースの組み込みターミナル。7 つのカラーテーマ (dark, dracula, monokai, solarized, nord, tokyoNight, catppuccin) をサポート。ANSI カラー対応。キャンバスあたり最大 10 個。

### Browser

WebKit ベースの組み込みブラウザ。戻る/進む/リロードのナビゲーションと URL バーを搭載。URL にプロトコルを省略すると https:// が自動補完。キャンバスあたり最大 10 個。

### File Manager

ディレクトリツリーをブラウズ。ファイルをダブルクリックすると種類に応じてウィジェットを自動生成:
- Markdown/テキスト → Markdown ウィジェット
- 画像 (PNG/JPG/GIF/WebP) → Image ウィジェット
- コードファイル → コードブロック付き Markdown ウィジェット

### Frame

ウィジェットを視覚的にグルーピングするラベル付き矩形。6 つのプリセットカラー (blue, green, orange, red, purple, gray) から選択。ラベルはダブルクリックで編集可能。

### Image

ローカルファイルまたは URL から画像を表示。アスペクト比を維持しながら自動スケーリング。PNG, JPG, GIF, WebP をサポート。

### Drawing (ペンツール)

フリーハンドの描画パス。Ramer-Douglas-Peucker アルゴリズムによるパス簡略化で滑らかな線を描画。色と線幅をカスタマイズ可能。

---

## キーボードショートカット

### Canvas Mode

| ショートカット | アクション |
|----------------|------------|
| `P` | ペンツール切り替え |
| `Delete` | 選択中のウィジェットを削除 |
| `Esc` | 選択解除 |
| `Cmd + B` | ブックマーク一覧パネルの表示/非表示 |
| `Cmd + Shift + B` | 現在のビューポートをブックマーク保存 |
| ダブルクリック (空きエリア) | 付箋を追加 |
| スクロールホイール | ズーム |

### Tiling WM Mode

| ショートカット | アクション |
|----------------|------------|
| `Option + Control` (押し続ける) | ミニマップを一時表示 |
| `Ctrl + T` | ミニマップの常時表示をトグル |
| `Ctrl + R` | ウィンドウキャプチャを更新 |
| `Esc` | ミニマップを閉じる / WM を無効化 |
| スクロールホイール | ミニマップをズーム |

---

## メニューバー

CanvasWM はメニューバーに常駐し、以下の操作にすばやくアクセスできます:

- **Show Canvas** - キャンバスウィンドウの表示/非表示
- **New Sticky Note** (`N`) - 付箋を作成
- **New Markdown** (`M`) - Markdown ウィジェットを作成
- **New Browser** (`B`) - ブラウザウィジェットを作成
- **Canvas WM** (`Ctrl+T`) - Tiling WM モードのトグル
- **Gather Windows on Quit** - 終了時にすべてのウィンドウをモニター内に戻す (トグル)
- **Quit** (`Q`)

---

## ワークスペース

左サイドバーからワークスペースを切り替え可能。各ワークスペースはウィジェット配置・ズーム・パン位置・ブックマークを独立して保持します。

データの保存先:

```
~/Library/Application Support/CanvasWM/
├── workspaces.json                    # ワークスペース一覧
├── workspaces/{workspaceId}.json      # 各ワークスペースのキャンバス状態
├── sticky-notes.json                  # フローティング付箋
├── desktop-markdowns.json             # フローティング Markdown
└── desktop-browsers.json              # フローティングブラウザ
```

保存はデバウンス付き自動保存 (1 秒) で行われ、アプリ終了時にも即座に保存されます。

---

## 外部連携

### ウィンドウハイライト通知

`~/.canvaswm/notify` ファイルにアプリ名を書き込むと、Tiling WM のミニマップ上で該当ウィンドウが 5 秒間ハイライトされます。

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

これにより、Claude Code が通知を発行するたびにミニマップ上のターミナルウィンドウがハイライトされ、作業完了を視覚的に確認できます。

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
- アクセシビリティ権限 (Tiling WM Mode でウィンドウの移動・リサイズに必要)

---

## アーキテクチャ

```
Sources/CanvasWMLib/
├── Canvas/                # キャンバスビュー
│   ├── InfiniteCanvasView # パン・ズーム対応の無限キャンバス
│   └── MinimapView        # キャンバスミニマップ + ブックマーク表示
├── CanvasWM/              # タイリングウィンドウマネージャー
│   ├── CanvasWMEngine     # 双方向同期エンジン (30fps)
│   ├── CanvasWMState      # ビューポート & マネージドウィンドウ状態
│   ├── CanvasWMWindowController  # ミニマップのトグル & ライフサイクル
│   └── CanvasWMOverlayView      # WM ミニマップ UI
├── Widgets/               # ウィジェットビュー群
│   ├── *WidgetView.swift  # 各ウィジェットの SwiftUI ビュー
│   ├── Desktop*.swift     # フローティングデスクトップウィジェット
│   ├── StickyNoteWindowController  # フローティングウィジェット管理
│   └── WidgetGalleryView  # ウィジェット追加ギャラリー
├── VirtualDesktop/        # macOS ウィンドウキャプチャ & Accessibility API
├── Terminal/              # PTY セッション管理
├── Models.swift           # 全ウィジェットのモデル定義
├── CanvasState.swift      # キャンバス状態 (@Observable)
├── ViewportMath.swift     # 座標変換 (World <-> Screen)
├── PersistenceManager.swift  # JSON ワークスペース永続化
└── MainView.swift         # ルート SwiftUI ビュー
```

### 座標系

`ViewportMath` がすべての座標変換を担当:

- **World 座標**: 無限キャンバス上の位置
- **Screen 座標**: ディスプレイ上のピクセル位置

Tiling WM Mode では、ビューポートは物理モニターがキャンバス上のどこに位置するかを表します。ビューポート内のウィンドウは画面に表示され、ビューポート外のウィンドウはオフスクリーン (99999, 99999) に移動されます。

---

## ライセンス

MIT
