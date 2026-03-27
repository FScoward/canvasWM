import SwiftUI
import WebKit

/// Floating browser with address bar
struct DesktopBrowserView: View {
    @Binding var browser: DesktopBrowser
    let onDelete: () -> Void
    let onChanged: () -> Void
    @State private var urlText: String = ""

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            WebViewWrapper(urlString: browser.url)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { urlText = browser.url }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            Image(systemName: "globe")
                .foregroundColor(.secondary)
                .font(.system(size: 12))
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

/// NSViewRepresentable wrapper for WKWebView
struct WebViewWrapper: NSViewRepresentable {
    let urlString: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsMagnification = true
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
}
