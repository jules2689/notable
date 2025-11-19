import SwiftUI
import WebKit

/// A view that renders markdown content as HTML using WebKit
struct MarkdownView: NSViewRepresentable {
    let markdown: String

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        guard let html = MarkdownRenderer.toHTML(markdown) else {
            return
        }

        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <style>
                \(MarkdownRenderer.customCSS())
            </style>
        </head>
        <body>
            \(html)
        </body>
        </html>
        """

        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
}

extension MarkdownRenderer {
    /// Public CSS accessor for MarkdownView
    static func customCSS() -> String {
        """
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: #1d1d1f;
            padding: 20px;
        }

        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
        }

        h1 { font-size: 2em; border-bottom: 1px solid #e5e5e5; padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid #e5e5e5; padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: #6e6e73; }

        p {
            margin-top: 0;
            margin-bottom: 16px;
        }

        a {
            color: #007aff;
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        code {
            background-color: rgba(175, 184, 193, 0.2);
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 85%;
            border-radius: 6px;
            font-family: 'SF Mono', Monaco, Menlo, Consolas, monospace;
        }

        pre {
            background-color: #f6f8fa;
            padding: 16px;
            overflow: auto;
            font-size: 85%;
            line-height: 1.45;
            border-radius: 6px;
        }

        pre code {
            background-color: transparent;
            padding: 0;
            margin: 0;
            border-radius: 0;
        }

        blockquote {
            padding: 0 1em;
            color: #6e6e73;
            border-left: 0.25em solid #d0d0d0;
            margin: 0 0 16px 0;
        }

        ul, ol {
            padding-left: 2em;
            margin-top: 0;
            margin-bottom: 16px;
        }

        li {
            margin-top: 0.25em;
        }

        table {
            border-collapse: collapse;
            width: 100%;
            margin-bottom: 16px;
        }

        table th, table td {
            padding: 6px 13px;
            border: 1px solid #d0d0d0;
        }

        table th {
            font-weight: 600;
            background-color: #f6f8fa;
        }

        table tr:nth-child(2n) {
            background-color: #f6f8fa;
        }

        hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background-color: #e5e5e5;
            border: 0;
        }

        img {
            max-width: 100%;
            height: auto;
        }

        input[type="checkbox"] {
            margin-right: 0.5em;
        }

        /* Task list support */
        .task-list-item {
            list-style-type: none;
        }

        .task-list-item input {
            margin: 0 0.5em 0.25em -1.6em;
            vertical-align: middle;
        }
        """
    }
}

#Preview {
    MarkdownView(markdown: """
    # Sample Markdown

    This is a **bold** and *italic* text example.

    ## Code Example

    ```swift
    func hello() {
        print("Hello, World!")
    }
    ```

    ## List
    - Item 1
    - Item 2
    - Item 3

    ## Table

    | Column 1 | Column 2 |
    |----------|----------|
    | Data 1   | Data 2   |
    """)
    .frame(width: 600, height: 400)
}
