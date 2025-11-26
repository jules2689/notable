import SwiftUI
import WebKit
import AppKit

/// View that displays an animated GIF icon using WebView with disabled context menu
struct AnimatedIconView: NSViewRepresentable {
    let iconURL: URL
    let size: CGFloat
    
    func makeNSView(context: Context) -> PassThroughContainerView {
        let config = WKWebViewConfiguration()
        let webView = NoContextMenuWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.allowsMagnification = false
        webView.allowsBackForwardNavigationGestures = false
        
        // Disable context menu
        webView.setValue(false, forKey: "allowsLinkPreview")
        
        // Set up navigation delegate
        webView.navigationDelegate = context.coordinator
        
        // Load the GIF file - use file:// URL directly
        let fileURL = URL(fileURLWithPath: iconURL.path)
        if let html = generateGIFHTML(iconURL: fileURL, size: size) {
            webView.loadHTMLString(html, baseURL: fileURL.deletingLastPathComponent())
        }
        
        context.coordinator.webView = webView
        context.coordinator.iconURL = iconURL
        
        // Wrap in a container that passes through events
        let container = PassThroughContainerView()
        container.addSubview(webView)
        webView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: container.topAnchor),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])
        
        return container
    }
    
    func updateNSView(_ nsView: PassThroughContainerView, context: Context) {
        // Reload if URL changed
        if let webView = context.coordinator.webView, context.coordinator.iconURL != iconURL {
            let fileURL = URL(fileURLWithPath: iconURL.path)
            if let html = generateGIFHTML(iconURL: fileURL, size: size) {
                webView.loadHTMLString(html, baseURL: fileURL.deletingLastPathComponent())
            }
            context.coordinator.iconURL = iconURL
        }
    }
    
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    private func generateGIFHTML(iconURL: URL, size: CGFloat) -> String? {
        // Read the GIF file and convert to data URL for reliable loading
        guard let gifData = try? Data(contentsOf: iconURL) else {
            // Fallback to file URL if data reading fails
            let fileURLString = iconURL.absoluteString
            let escapedURL = fileURLString
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\"", with: "&quot;")
            
            return generateHTMLWithImageSrc(escapedURL, size: size)
        }
        
        // Use data URL for the GIF - this ensures it loads and animates
        let base64 = gifData.base64EncodedString(options: .lineLength64Characters)
        let dataURL = "data:image/gif;base64,\(base64)"
        return generateHTMLWithImageSrc(dataURL, size: size)
    }
    
    private func generateHTMLWithImageSrc(_ imageSrc: String, size: CGFloat) -> String {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta name="viewport" content="width=\(Int(size)), height=\(Int(size))">
            <style>
                * {
                    margin: 0;
                    padding: 0;
                    box-sizing: border-box;
                    -webkit-user-select: none;
                    user-select: none;
                }
                html, body {
                    width: \(Int(size))px;
                    height: \(Int(size))px;
                    overflow: hidden;
                    display: flex;
                    align-items: center;
                    justify-content: center;
                    background: transparent;
                }
                img {
                    max-width: \(Int(size))px;
                    max-height: \(Int(size))px;
                    width: auto;
                    height: auto;
                    object-fit: contain;
                    image-rendering: -webkit-optimize-contrast;
                }
            </style>
            <script>
                document.addEventListener('contextmenu', function(e) {
                    e.preventDefault();
                    return false;
                });
                document.addEventListener('selectstart', function(e) {
                    e.preventDefault();
                    return false;
                });
            </script>
        </head>
        <body>
            <img src="\(imageSrc)" alt="Icon">
        </body>
        </html>
        """
        return html
    }
    
    class Coordinator: NSObject, WKNavigationDelegate {
        var webView: WKWebView?
        var iconURL: URL?
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow navigation for loading the GIF
            decisionHandler(.allow)
        }
    }
    
    // Custom WebView subclass to disable context menu and make non-interactive
    class NoContextMenuWebView: WKWebView {
        override func rightMouseDown(with event: NSEvent) {
            // Suppress right-click context menu - don't call super
        }
        
        override func menu(for event: NSEvent) -> NSMenu? {
            // Return nil to disable context menu
            return nil
        }
        
        override func hitTest(_ point: NSPoint) -> NSView? {
            // Don't capture mouse events
            return nil
        }
        
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return false
        }
        
        override var acceptsFirstResponder: Bool {
            return false
        }
        
        override var mouseDownCanMoveWindow: Bool {
            return false
        }
        
        override func mouseDown(with event: NSEvent) {
            // Don't handle - pass through
        }
        
        override func mouseUp(with event: NSEvent) {
            // Don't handle - pass through
        }
    }
    
    // Container view that passes through all mouse events
    class PassThroughContainerView: NSView {
        override func hitTest(_ point: NSPoint) -> NSView? {
            // Don't capture mouse events - let them pass through to the button
            return nil
        }
        
        override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
            return false
        }
        
        override var acceptsFirstResponder: Bool {
            return false
        }
        
        override var mouseDownCanMoveWindow: Bool {
            return false
        }
        
        override func mouseDown(with event: NSEvent) {
            // Don't handle mouse events - pass through
        }
        
        override func mouseUp(with event: NSEvent) {
            // Don't handle mouse events - pass through
        }
        
        override func rightMouseDown(with event: NSEvent) {
            // Don't handle mouse events - pass through
        }
    }
}

