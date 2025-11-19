import SwiftUI
import WebKit

/// A rich text editor using contenteditable HTML with markdown support
struct RichTextEditor: NSViewRepresentable {
    @Binding var text: String
    var onTextChange: (String) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let contentController = WKUserContentController()

        // Register message handlers
        contentController.add(context.coordinator, name: "ready")
        contentController.add(context.coordinator, name: "textChange")

        config.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator

        // Load the HTML file
        if let htmlPath = Bundle.main.path(forResource: "RichEditor", ofType: "html"),
           let htmlString = try? String(contentsOfFile: htmlPath, encoding: .utf8) {
            webView.loadHTMLString(htmlString, baseURL: Bundle.main.resourceURL)
        }

        context.coordinator.webView = webView
        context.coordinator.initialText = text

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onTextChange = onTextChange

        // Only update if text changed externally (e.g., switching notes)
        if context.coordinator.shouldUpdateContent(newText: text) {
            context.coordinator.lastSetText = text
            let escapedText = text
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "`", with: "\\`")
                .replacingOccurrences(of: "$", with: "\\$")
            let jsCode = "window.setContent(`" + escapedText + "`);"
            webView.evaluateJavaScript(jsCode)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    class Coordinator: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
        @Binding var text: String
        var webView: WKWebView?
        var onTextChange: ((String) -> Void)?
        var isReady = false
        var initialText: String = ""
        var lastSetText: String = ""
        var lastReceivedText: String = ""

        init(text: Binding<String>) {
            _text = text
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "ready":
                isReady = true
                // Set initial content once editor is ready
                if !initialText.isEmpty {
                    let escapedText = initialText
                        .replacingOccurrences(of: "\\", with: "\\\\")
                        .replacingOccurrences(of: "`", with: "\\`")
                        .replacingOccurrences(of: "$", with: "\\$")
                    let jsCode = "window.setContent(`" + escapedText + "`);"
                    webView?.evaluateJavaScript(jsCode)
                    lastSetText = initialText
                }

            case "textChange":
                if let body = message.body as? [String: Any],
                   let markdown = body["markdown"] as? String {
                    lastReceivedText = markdown
                    text = markdown
                    onTextChange?(markdown)
                }

            default:
                break
            }
        }

        func shouldUpdateContent(newText: String) -> Bool {
            // Only update if the text is different from what we last received
            // This prevents infinite loops when typing
            return newText != lastReceivedText && newText != lastSetText
        }

        // WKNavigationDelegate - prevent navigation
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow initial load
            if navigationAction.navigationType == .other {
                decisionHandler(.allow)
            } else {
                // Block all other navigation (like clicking links)
                decisionHandler(.cancel)
            }
        }
    }
}
