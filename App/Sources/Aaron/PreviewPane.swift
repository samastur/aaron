import AaronCore
import AaronPreview
import SwiftUI
import WebKit

struct PreviewPane: View {
    @Bindable var model: DocumentWindowModel

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Picker("Renderer", selection: $model.rendererID) {
                    ForEach(model.availableRenderers, id: \.id) { renderer in
                        Text(renderer.name).tag(renderer.id)
                    }
                }
                .labelsHidden()
                .fixedSize()
                .accessibilityIdentifier("rendererPicker")
                .help("How the preview is rendered")

                Spacer()
                if model.isRenderingPreview {
                    ProgressView().controlSize(.small)
                }
                Button {
                    model.refreshPreview(immediately: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Render the preview again (⇧⌘R)")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            Divider()
            ZStack(alignment: .top) {
                PreviewWebView(html: model.previewHTML ?? "", resolver: model.assetResolver)
                    .accessibilityIdentifier("preview")
                if let error = model.previewError {
                    PreviewErrorBanner(message: error)
                }
            }
        }
    }
}

private struct PreviewErrorBanner: View {
    let message: String
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("The preview could not be rendered", systemImage: "exclamationmark.triangle.fill")
                .font(.callout.bold())
            Text(message)
                .font(.caption.monospaced())
                .lineLimit(expanded ? nil : 3)
                .textSelection(.enabled)
            Button(expanded ? "Show less" : "Show more") { expanded.toggle() }
                .buttonStyle(.link)
                .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .padding(8)
        .accessibilityIdentifier("previewError")
    }
}

/// Shows rendered HTML. The page and its assets are served through the
/// `aaron-preview:` URL scheme so root-relative theme URLs can be mapped to
/// local folders. Scroll position survives re-rendering.
struct PreviewWebView: NSViewRepresentable {
    static let scheme = "aaron-preview"
    static let pagePath = "/__aaron_preview__.html"

    let html: String
    let resolver: PreviewAssetResolver

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(context.coordinator.schemeHandler, forURLScheme: Self.scheme)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.setValue(false, forKey: "drawsBackground")
        context.coordinator.webView = webView
        #if DEBUG
        DebugHarness.previewWebView = webView
        #endif
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let coordinator = context.coordinator
        coordinator.schemeHandler.resolver = resolver
        guard coordinator.schemeHandler.html != html else { return }
        coordinator.schemeHandler.html = html
        coordinator.reload()
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let schemeHandler = PreviewSchemeHandler()
        weak var webView: WKWebView?
        private var savedScroll: (x: Double, y: Double)?
        private var generation = 0

        func reload() {
            guard let webView else { return }
            generation += 1
            let url = URL(string: "\(PreviewWebView.scheme)://preview\(PreviewWebView.pagePath)?v=\(generation)")!
            webView.evaluateJavaScript("[window.scrollX, window.scrollY]") { [weak self] result, _ in
                MainActor.assumeIsolated {
                    if let values = result as? [Double], values.count == 2 {
                        self?.savedScroll = (values[0], values[1])
                    }
                    webView.load(URLRequest(url: url))
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            guard let scroll = savedScroll else { return }
            webView.evaluateJavaScript("window.scrollTo(\(scroll.x), \(scroll.y))")
        }

        func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            guard let url = action.request.url else { return decisionHandler(.cancel) }
            if url.scheme == PreviewWebView.scheme {
                // Only our own page loads in the preview; in-page anchors are fine.
                let isPage = url.path == PreviewWebView.pagePath
                if action.navigationType == .linkActivated && !isPage {
                    return decisionHandler(.cancel)
                }
                return decisionHandler(.allow)
            }
            if action.navigationType == .linkActivated, ["http", "https", "mailto"].contains(url.scheme ?? "") {
                NSWorkspace.shared.open(url)
            }
            // Subresources (fonts, scripts) from the web are allowed; navigations are not.
            decisionHandler(action.targetFrame?.isMainFrame == false ? .allow : .cancel)
        }
    }
}

/// Serves the preview page from memory and other paths from disk.
@MainActor
final class PreviewSchemeHandler: NSObject, WKURLSchemeHandler {
    var html = ""
    var resolver = PreviewAssetResolver(mappings: [], documentDirectory: nil)

    func webView(_ webView: WKWebView, start task: any WKURLSchemeTask) {
        guard let url = task.request.url else { return }
        let data: Data
        let mimeType: String
        if url.path == PreviewWebView.pagePath {
            data = Data(html.utf8)
            mimeType = "text/html"
        } else if let file = resolver.fileURL(forPath: url.path), let contents = try? Data(contentsOf: file) {
            data = contents
            mimeType = PreviewAssetResolver.mimeType(for: file)
        } else {
            task.didReceive(HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!)
            task.didFinish()
            return
        }
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": mimeType + (mimeType.hasPrefix("text/") ? "; charset=utf-8" : "")])!
        task.didReceive(response)
        task.didReceive(data)
        task.didFinish()
    }

    func webView(_ webView: WKWebView, stop task: any WKURLSchemeTask) {}
}
