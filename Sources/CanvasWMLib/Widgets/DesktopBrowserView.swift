import SwiftUI
import WebKit

/// Floating browser with address bar
struct DesktopBrowserView: View {
    @Binding var browser: DesktopBrowser
    let onDelete: () -> Void
    let onChanged: () -> Void
    @State private var urlText: String = ""
    @State private var webViewStore = DesktopWebViewStore()

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            WebViewWrapper(urlString: browser.url, store: webViewStore)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { urlText = browser.url }
        .onChange(of: webViewStore.currentURL) { _, newURL in
            if let newURL, !newURL.isEmpty { urlText = newURL }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Button(action: { webViewStore.webView?.goBack() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(webViewStore.canGoBack ? .primary : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!webViewStore.canGoBack)

            Button(action: { webViewStore.webView?.goForward() }) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(webViewStore.canGoForward ? .primary : .secondary.opacity(0.4))
            }
            .buttonStyle(.plain)
            .disabled(!webViewStore.canGoForward)

            Button(action: { webViewStore.webView?.reload() }) {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
            }
            .buttonStyle(.plain)

            TextField("URL", text: $urlText)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 11))
                .onSubmit {
                    var url = urlText
                    if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
                        url = "https://" + url
                    }
                    browser.url = url
                    urlText = url
                    onChanged()
                }
            Button(action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
    }
}

@Observable
class DesktopWebViewStore {
    var webView: WKWebView?
    var canGoBack: Bool = false
    var canGoForward: Bool = false
    var currentURL: String?
}

/// NSViewRepresentable wrapper for WKWebView
struct WebViewWrapper: NSViewRepresentable {
    let urlString: String
    let store: DesktopWebViewStore

    func makeCoordinator() -> Coordinator {
        Coordinator(store: store)
    }

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsMagnification = true
        webView.navigationDelegate = context.coordinator
        store.webView = webView
        loadURL(in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let currentURL = webView.url?.absoluteString ?? ""
        if currentURL != urlString {
            loadURL(in: webView)
        }
    }

    private func loadURL(in webView: WKWebView) {
        guard let url = URL(string: urlString) else { return }
        webView.load(URLRequest(url: url))
    }

    class Coordinator: NSObject, WKNavigationDelegate {
        let store: DesktopWebViewStore

        init(store: DesktopWebViewStore) {
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
