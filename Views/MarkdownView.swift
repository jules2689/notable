import SwiftUI
import WebKit
import AppKit

/// A view that renders markdown content as HTML using WebKit
struct MarkdownView: NSViewRepresentable {
    let markdown: String
    @Environment(\.colorScheme) var colorScheme

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: configuration)

        // Make background transparent
        webView.setValue(false, forKey: "drawsBackground")

        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        // Handle empty markdown
        let markdownToRender = markdown.isEmpty ? "_No content yet..._" : markdown

        let isDarkMode = colorScheme == .dark
        let highlightTheme = isDarkMode ? "github-dark" : "github"

        // Process custom components before rendering markdown
        let processedMarkdown = ComponentParser.replaceComponents(in: markdownToRender, darkMode: isDarkMode)

        // Escape the markdown for JavaScript
        let escapedMarkdown = processedMarkdown
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "`", with: "\\`")
            .replacingOccurrences(of: "$", with: "\\$")

        let styledHTML = """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1">
            <meta name="color-scheme" content="light dark">
            <link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/styles/\(highlightTheme).min.css">
            <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css"
                integrity="sha256-p4NxAoJBhIIN+hmNHrzRCf9tD/miZyoHS5obTRR9BMY="
                crossorigin=""/>
            <script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"
                integrity="sha256-20nQCchB9co0qIjJZRGuk2/Z9VM+kNiyxNV1lvTlZBo="
                crossorigin=""></script>
            <style>
                \(MarkdownRenderer.customCSS(isDarkMode: isDarkMode))
            </style>
        </head>
        <body>
            <div id="content"></div>
            <script src="https://cdn.jsdelivr.net/npm/marked@11.1.1/marked.min.js"></script>
            <script src="https://cdnjs.cloudflare.com/ajax/libs/highlight.js/11.9.0/highlight.min.js"></script>
            <script>
                // Configure marked for GFM
                marked.setOptions({
                    gfm: true,
                    breaks: false,
                    pedantic: false,
                    smartLists: true,
                    smartypants: false,  // Disable smart quotes
                    headerIds: false,
                    mangle: false,
                    highlight: function(code, lang) {
                        if (lang && hljs.getLanguage(lang)) {
                            try {
                                return hljs.highlight(code, { language: lang }).value;
                            } catch (e) {}
                        }
                        return hljs.highlightAuto(code).value;
                    }
                });

                // Allow HTML passthrough (marked.js preserves HTML by default)
                marked.use({
                    renderer: {
                        html(html) {
                            return html;  // Pass HTML through unchanged
                        }
                    }
                });

                // Render markdown
                const markdown = `\(escapedMarkdown)`;
                document.getElementById('content').innerHTML = marked.parse(markdown);

                // Apply syntax highlighting to all code blocks
                document.querySelectorAll('pre code').forEach((block) => {
                    hljs.highlightElement(block);
                });

                // Execute any inline scripts that were added by components
                // This is necessary because innerHTML doesn't execute script tags
                setTimeout(() => {
                    document.querySelectorAll('script[data-component-script]').forEach((oldScript) => {
                        const newScript = document.createElement('script');
                        newScript.textContent = oldScript.textContent;
                        oldScript.parentNode.replaceChild(newScript, oldScript);
                    });
                }, 100);
            </script>
        </body>
        </html>
        """

        webView.loadHTMLString(styledHTML, baseURL: nil)
    }
}

extension MarkdownRenderer {
    /// Public CSS accessor for MarkdownView with theme support
    static func customCSS(isDarkMode: Bool = false) -> String {
        let textColor = isDarkMode ? "#e8e8e8" : "#1d1d1f"
        let secondaryTextColor = isDarkMode ? "#a0a0a0" : "#6e6e73"
        let borderColor = isDarkMode ? "#3a3a3a" : "#e5e5e5"
        let codeBackground = isDarkMode ? "rgba(255, 255, 255, 0.1)" : "rgba(175, 184, 193, 0.2)"
        let preBackground = isDarkMode ? "#2a2a2a" : "#f6f8fa"
        let tableHeaderBackground = isDarkMode ? "#2a2a2a" : "#f6f8fa"
        let tableRowBackground = isDarkMode ? "#252525" : "#f6f8fa"
        let linkColor = isDarkMode ? "#4a9eff" : "#007aff"

        return """
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
            font-size: 14px;
            line-height: 1.6;
            color: \(textColor);
            padding: 20px;
            background: transparent;
        }

        h1, h2, h3, h4, h5, h6 {
            margin-top: 24px;
            margin-bottom: 16px;
            font-weight: 600;
            line-height: 1.25;
            color: \(textColor);
        }

        h1 { font-size: 2em; border-bottom: 1px solid \(borderColor); padding-bottom: 0.3em; }
        h2 { font-size: 1.5em; border-bottom: 1px solid \(borderColor); padding-bottom: 0.3em; }
        h3 { font-size: 1.25em; }
        h4 { font-size: 1em; }
        h5 { font-size: 0.875em; }
        h6 { font-size: 0.85em; color: \(secondaryTextColor); }

        p {
            margin-top: 0;
            margin-bottom: 16px;
            color: \(textColor);
        }

        a {
            color: \(linkColor);
            text-decoration: none;
        }

        a:hover {
            text-decoration: underline;
        }

        code {
            background-color: \(codeBackground);
            padding: 0.2em 0.4em;
            margin: 0;
            font-size: 85%;
            border-radius: 6px;
            font-family: 'SF Mono', Monaco, Menlo, Consolas, monospace;
            color: \(textColor);
        }

        pre {
            background-color: \(preBackground) !important;
            padding: 16px;
            overflow: auto;
            font-size: 85%;
            line-height: 1.45;
            border-radius: 6px;
            margin: 16px 0;
        }

        pre code {
            background-color: transparent !important;
            padding: 0;
            margin: 0;
            border-radius: 0;
            font-size: inherit;
        }

        pre code.hljs {
            background-color: transparent !important;
        }

        blockquote {
            padding: 0 1em;
            color: \(secondaryTextColor);
            border-left: 0.25em solid \(borderColor);
            margin: 0 0 16px 0;
        }

        ul, ol {
            padding-left: 2em;
            margin-top: 0;
            margin-bottom: 16px;
        }

        li {
            margin-top: 0.25em;
            color: \(textColor);
        }

        table {
            border-collapse: collapse;
            width: 100%;
            margin: 16px 0;
            display: table;
        }

        table th, table td {
            padding: 8px 12px;
            border: 1px solid \(borderColor);
            color: \(textColor);
            text-align: left;
        }

        table th {
            font-weight: 600;
            background-color: \(tableHeaderBackground);
        }

        table tbody tr:nth-child(2n) {
            background-color: \(tableRowBackground);
        }

        table tbody tr:hover {
            background-color: \(isDarkMode ? "#333" : "#f0f0f0");
        }

        hr {
            height: 0.25em;
            padding: 0;
            margin: 24px 0;
            background-color: \(borderColor);
            border: 0;
        }

        img {
            max-width: 100%;
            height: auto;
        }

        input[type="checkbox"] {
            margin: 0 0.5em 0 0;
            vertical-align: middle;
        }

        /* Task list support */
        ul.contains-task-list {
            list-style: none;
            padding-left: 1.5em;
        }

        .task-list-item {
            list-style-type: none;
            position: relative;
        }

        .task-list-item input[type="checkbox"] {
            margin: 0 0.5em 0.25em -1.5em;
            vertical-align: middle;
            cursor: pointer;
        }

        .task-list-item input[type="checkbox"]:disabled {
            cursor: default;
        }

        strong {
            color: \(textColor);
        }

        em {
            color: \(textColor);
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
