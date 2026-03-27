import SwiftUI
import AppKit

public struct TerminalWidgetView: View {
    let terminal: TerminalState
    let isSelected: Bool
    @Bindable var canvasState: CanvasState
    @State private var ptySession = PTYSession()
    @State private var outputLines: [TerminalLine] = []
    @State private var inputBuffer: String = ""
    @FocusState private var isInputFocused: Bool

    struct TerminalLine: Identifiable {
        let id = UUID()
        let text: String
        let color: Color
    }

    private var theme: TerminalTheme {
        TerminalState.themes[terminal.themeKey] ?? TerminalState.themes["dark"]!
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header — drag handle
            HStack {
                Circle().fill(terminal.isAlive ? Color.green : Color.red).frame(width: 8, height: 8)
                Text("Terminal").font(.system(size: 11, weight: .medium)).foregroundColor(.secondary)
                Spacer()
                Button(action: { canvasState.deleteTerminal(id: terminal.id); ptySession.terminate() }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Color(hex: theme.bg)?.opacity(0.8) ?? .black.opacity(0.8))

            // Terminal output
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(outputLines) { line in
                            Text(line.text)
                                .font(.system(size: terminal.fontSize, design: .monospaced))
                                .foregroundColor(line.color)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .textSelection(.enabled)
                                .id(line.id)
                        }
                    }
                    .padding(4)
                }
                .onChange(of: outputLines.count) { _, _ in
                    if let last = outputLines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .background(Color(hex: theme.bg) ?? .black)
            .onTapGesture {
                canvasState.bringToFront(id: terminal.id)
                isInputFocused = true
            }

            // Input field
            HStack(spacing: 4) {
                Text(">").font(.system(size: terminal.fontSize, design: .monospaced))
                    .foregroundColor(Color(hex: theme.cursor) ?? .white)
                TextField("Type here...", text: $inputBuffer)
                    .textFieldStyle(.plain)
                    .font(.system(size: terminal.fontSize, design: .monospaced))
                    .foregroundColor(Color(hex: theme.fg) ?? .white)
                    .focused($isInputFocused)
                    .onSubmit {
                        ptySession.write(inputBuffer + "\n")
                        inputBuffer = ""
                    }
            }
            .padding(.horizontal, 6).padding(.vertical, 3)
            .background(Color(hex: theme.bg)?.opacity(0.9) ?? .black.opacity(0.9))
        }
        .frame(width: terminal.width * canvasState.scale, height: terminal.height * canvasState.scale)
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.2), radius: 4, x: 1, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
        .onAppear {
            startPTY()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isInputFocused = true }
        }
        .onDisappear { ptySession.terminate() }
    }

    private func startPTY() {
        let fgColor = Color(hex: theme.fg) ?? .white
        ptySession.onOutput = { text in
            let lines = text.components(separatedBy: "\n")
            for line in lines where !line.isEmpty {
                let cleaned = stripANSI(line)
                outputLines.append(TerminalLine(text: cleaned, color: fgColor))
            }
            if outputLines.count > 1000 { outputLines.removeFirst(outputLines.count - 1000) }
        }
        ptySession.onExit = { _ in canvasState.markTerminalDead(id: terminal.id) }
        ptySession.start()
    }

    private func stripANSI(_ text: String) -> String {
        text.replacingOccurrences(of: "\\x1B\\[[0-9;]*[a-zA-Z]", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\x1B\\][^\\x07]*\\x07", with: "", options: .regularExpression)
    }
}

struct TerminalWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        let state = CanvasState()
        let terminal = TerminalState(id: "preview-1", x: 0, y: 0, width: 500, height: 300,
                                      isAlive: true, themeKey: "dark", zIndex: 0)
        TerminalWidgetView(terminal: terminal, isSelected: false, canvasState: state)
            .previewDisplayName("dark theme")

        let state2 = CanvasState()
        let terminal2 = TerminalState(id: "preview-2", x: 0, y: 0, width: 500, height: 300,
                                       isAlive: false, themeKey: "dracula", zIndex: 0)
        TerminalWidgetView(terminal: terminal2, isSelected: true, canvasState: state2)
            .previewDisplayName("dracula dead")
    }
}
