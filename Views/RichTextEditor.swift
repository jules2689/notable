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

        // Enable Web Inspector for debugging
        #if DEBUG
        if #available(macOS 13.3, *) {
            webView.isInspectable = true
        }
        #endif

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

        // Update initialText if it's empty and we now have content (handles first boot case)
        if context.coordinator.initialText.isEmpty && !text.isEmpty {
            context.coordinator.initialText = text
        }

        // Only update if text changed externally (e.g., switching notes)
        if context.coordinator.shouldUpdateContent(newText: text) {
            // Only set content if the editor is ready
            guard context.coordinator.isReady else {
                // Store the text to set once ready
                context.coordinator.pendingText = text
                // Also update initialText in case ready hasn't fired yet
                if context.coordinator.initialText.isEmpty {
                    context.coordinator.initialText = text
                }
                return
            }
            
            print("🔄 RichTextEditor: Setting content (\(text.count) chars)")
            if text.contains("|") {
                print("📊 Loading note with table")
                if let tableStart = text.range(of: "|") {
                    let start = tableStart.lowerBound
                    let end = text.index(start, offsetBy: min(200, text.distance(from: start, to: text.endIndex)))
                    print("Table markdown: \(text[start..<end])")
                }
            }
            context.coordinator.lastSetText = text

            // Use JSON encoding for safe string escaping
            guard let escapedText = context.coordinator.escapeForJavaScript(text) else {
                print("❌ Error encoding text to JSON")
                return
            }
            
            let jsCode = "window.setContent(\"\(escapedText)\");"

            print("📤 Executing setContent with \(text.count) chars")

            webView.evaluateJavaScript(jsCode) { result, error in
                if let error = error {
                    print("❌ Error setting content: \(error.localizedDescription)")
                    print("❌error: \(error)")
                } else {
                    print("✅ Content set successfully")
                }
            }
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
        var pendingText: String? = nil

        init(text: Binding<String>) {
            _text = text
        }
        
        /// Safely escape a string for use in JavaScript by using JSON encoding
        func escapeForJavaScript(_ text: String) -> String? {
            // Use JSONSerialization to properly escape the string
            // We encode it as an array with one element, then extract the escaped string value
            guard let jsonData = try? JSONSerialization.data(withJSONObject: [text], options: []),
                  let jsonString = String(data: jsonData, encoding: .utf8) else {
                return nil
            }
            
            // JSON will be: ["escaped string"]
            // We need to extract the escaped string content (without the array brackets and outer quotes)
            let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("[\"") && trimmed.hasSuffix("\"]"),
                  trimmed.count > 4 else {
                return nil
            }
            
            // Extract the content between [" and "] - this gives us the JSON-escaped string
            // For example: ["test \"quote\""] -> "test \"quote\""
            // We want just: test \"quote\" (the escaped content without the outer quotes)
            let startIndex = trimmed.index(trimmed.startIndex, offsetBy: 2) // Skip ["
            let endIndex = trimmed.index(trimmed.endIndex, offsetBy: -2)     // Skip "]
            let escapedContent = String(trimmed[startIndex..<endIndex])
            
            return escapedContent
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            switch message.name {
            case "ready":
                isReady = true
                
                // Determine which text to set (pending text takes priority, then current binding value, then initial text)
                // This handles the case where the binding was updated after makeNSView but before ready fired
                let currentText = _text.wrappedValue
                let textToSet = pendingText ?? (currentText.isEmpty ? initialText : currentText)
                pendingText = nil
                
                // Set content once editor is ready
                if !textToSet.isEmpty {
                    print("🔄 RichTextEditor: Setting initial content on ready (\(textToSet.count) chars)")
                    // Use JSON encoding for safe string escaping
                    if let escapedText = escapeForJavaScript(textToSet) {
                        let jsCode = "window.setContent(\"\(escapedText)\");"
                        webView?.evaluateJavaScript(jsCode) { result, error in
                            if let error = error {
                                print("❌ Error setting initial content: \(error.localizedDescription)")
                            } else {
                                print("✅ Initial content set successfully")
                            }
                        }
                        lastSetText = textToSet
                        // Update initialText if it was empty
                        if initialText.isEmpty {
                            initialText = textToSet
                        }
                    } else {
                        print("❌ Error encoding initial text to JSON")
                    }
                } else {
                    print("⚠️ RichTextEditor: Ready but no content to set")
                }

            case "textChange":
                if let body = message.body as? [String: Any],
                   let markdown = body["markdown"] as? String {
                    print("📝 RichTextEditor: Received markdown update (\(markdown.count) chars)")
                    if markdown.contains("|") {
                        print("📊 Contains table syntax")
                        // Print first 200 chars of table
                        if let tableStart = markdown.range(of: "|") {
                            let start = tableStart.lowerBound
                            let end = markdown.index(start, offsetBy: min(200, markdown.distance(from: start, to: markdown.endIndex)))
                            print("Table preview: \(markdown[start..<end])")
                        }
                    }
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
        @MainActor
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
