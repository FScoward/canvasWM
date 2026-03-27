import SwiftUI
import WebKit

public struct BrowserWidgetView: View {
    let browser: BrowserState
    let isSelected: Bool
    @Bindable var canvasState: CanvasState
    @State private var urlInput: String = ""
    @State private var webViewStore = WebViewStore()

    public var body: some View {
        VStack(spacing: 0) {
            // Header with URL bar
            HStack(spacing: 4) {
                Button(action: { webViewStore.webView?.goBack() }) {
                    Image(systemName: "chevron.left").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .disabled(!(webViewStore.canGoBack))

                Button(action: { webViewStore.webView?.goForward() }) {
                    Image(systemName: "chevron.right").font(.system(size: 10))
                }
                .buttonStyle(.plain)
                .disabled(!(webViewStore.canGoForward))

                Button(action: { webViewStore.webView?.reload() }) {
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
            WebViewRepresentable(url: browser.url, store: webViewStore)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: browser.width * canvasState.scale, height: browser.height * canvasState.scale)
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 1, y: 2)
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2))
        .onTapGesture { canvasState.bringToFront(id: browser.id) }
        .onAppear { urlInput = browser.url }
        .onChange(of: webViewStore.currentURL) { _, newURL in
            if let newURL, !newURL.isEmpty { urlInput = newURL }
        }
    }
}

@Observable
class WebViewStore {
    var webView: WKWebView?
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var currentURL: String?
}

struct WebViewRepresentable: NSViewRepresentable {
    let url: String
    let store: WebViewStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        store.webView = webView
        if let url = URL(string: url) { webView.load(URLRequest(url: url)) }
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if let url = URL(string: url), webView.url?.absoluteString != url.absoluteString {
            webView.load(URLRequest(url: url))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let store: WebViewStore

        init(store: WebViewStore) {
            self.store = store
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            store.canGoBack = webView.canGoBack
            store.canGoForward = webView.canGoForward
            store.currentURL = webView.url?.absoluteString
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            store.canGoBack = webView.canGoBack
            store.canGoForward = webView.canGoForward
            store.currentURL = webView.url?.absoluteString
        }
    }
}

struct BrowserWidgetView_Previews: PreviewProvider {
    static var previews: some View {
        let state = CanvasState()
        let browser = BrowserState(id: "preview-1", x: 0, y: 0, width: 600, height: 400,
                                    url: "https://www.example.com", zIndex: 0)
        BrowserWidgetView(browser: browser, isSelected: false, canvasState: state)
            .previewDisplayName("example.com")

        let state2 = CanvasState()
        let browser2 = BrowserState(id: "preview-2", x: 0, y: 0, width: 600, height: 400,
                                     url: "https://www.google.com", zIndex: 0)
        BrowserWidgetView(browser: browser2, isSelected: true, canvasState: state2)
            .previewDisplayName("google selected")
    }
}
