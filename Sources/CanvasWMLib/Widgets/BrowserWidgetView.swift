import SwiftUI
import WebKit

public struct BrowserWidgetView: View {
    let browser: BrowserState
    let isSelected: Bool
    @Bindable var canvasState: CanvasState
    @State private var urlInput: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header with URL bar
            HStack(spacing: 4) {
                Button(action: { /* goBack handled via coordinator */ }) {
                    Image(systemName: "chevron.left").font(.system(size: 10))
                }.buttonStyle(.plain)
                Button(action: { /* goForward */ }) {
                    Image(systemName: "chevron.right").font(.system(size: 10))
                }.buttonStyle(.plain)
                Button(action: { /* reload */ }) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 10))
                }.buttonStyle(.plain)

                TextField("URL", text: $urlInput)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))
                    .onSubmit {
                        var url = urlInput
                        if !url.hasPrefix("http://") && !url.hasPrefix("https://") { url = "https://" + url }
                        canvasState.updateBrowserUrl(id: browser.id, url: url)
                    }

                Button(action: { canvasState.deleteBrowser(id: browser.id) }) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                }.buttonStyle(.plain)
            }
            .padding(.horizontal, 6).padding(.vertical, 4)
            .background(.bar)

            // WebView
            WebViewRepresentable(url: browser.url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: browser.width * canvasState.scale, height: browser.height * canvasState.scale)
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 1, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
        .onTapGesture { canvasState.bringToFront(id: browser.id) }
        .onAppear { urlInput = browser.url }
    }
}

struct WebViewRepresentable: NSViewRepresentable {
    let url: String

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        if let url = URL(string: url) { webView.load(URLRequest(url: url)) }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: url), webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }
}
