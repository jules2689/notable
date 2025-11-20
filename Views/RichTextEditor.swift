import SwiftUI
import WebKit
import AppKit

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
        contentController.add(context.coordinator, name: "openLink")
        contentController.add(context.coordinator, name: "openLinkInWebView")

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
        
        // Store webview window data to keep them alive
        private final class WebViewWindowData: @unchecked Sendable {
            let windowController: NSWindowController
            let webView: WKWebView
            let navigationDelegate: WebViewNavigationDelegate
            
            init(windowController: NSWindowController, webView: WKWebView, navigationDelegate: WebViewNavigationDelegate) {
                self.windowController = windowController
                self.webView = webView
                self.navigationDelegate = navigationDelegate
            }
        }
        
        private var webviewWindows: [WebViewWindowData] = []

        init(text: Binding<String>) {
            _text = text
        }
        
        func openLinkInWebView(url: URL) {
            // Create a new window
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 1200, height: 800),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = url.absoluteString
            window.center()
            
            // Create container view
            let containerView = NSView(frame: window.contentView!.bounds)
            containerView.autoresizingMask = [.width, .height]
            
            // Create webview
            let webView = WKWebView(frame: containerView.bounds)
            webView.autoresizingMask = [.width, .height]
            
            // Create a separate navigation delegate to avoid retain cycles
            let navigationDelegate = WebViewNavigationDelegate()
            webView.navigationDelegate = navigationDelegate
            
            // Add webview to container
            containerView.addSubview(webView)
            
            // Set container as window content view
            window.contentView = containerView
            
            // Create window controller to manage the window lifecycle
            let windowController = NSWindowController(window: window)
            
            // Store all references together
            let windowData = WebViewWindowData(
                windowController: windowController,
                webView: webView,
                navigationDelegate: navigationDelegate
            )
            webviewWindows.append(windowData)
            
            // Clean up when window closes
            NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { [weak self] notification in
                guard let self = self else { return }
                if let window = notification.object as? NSWindow {
                    // Find and remove the window data
                    self.webviewWindows.removeAll { $0.windowController.window == window }
                }
            }
            
            // Load the URL after everything is set up
            webView.load(URLRequest(url: url))
            
            // Show window using the controller
            windowController.showWindow(nil)
        }
        
        deinit {
            // Clean up all windows on main thread
            let windowsToClose = webviewWindows
            Task { @MainActor in
                for windowData in windowsToClose {
                    windowData.webView.navigationDelegate = nil
                    windowData.windowController.close()
                }
            }
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
                
            case "openLink":
                if let body = message.body as? [String: Any],
                   let urlString = body["url"] as? String,
                   let url = URL(string: urlString) {
                    // Open URL in default system browser
                    NSWorkspace.shared.open(url)
                }
                
            case "openLinkInWebView":
                if let body = message.body as? [String: Any],
                   let urlString = body["url"] as? String,
                   let url = URL(string: urlString) {
                    // Open URL in a new webview window
                    openLinkInWebView(url: url)
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

        // WKNavigationDelegate - prevent navigation in the main editor
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
    
    // Separate navigation delegate for webview windows to avoid retain cycles
    private class WebViewNavigationDelegate: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow all navigation in webview windows
            decisionHandler(.allow)
        }
    }
}
