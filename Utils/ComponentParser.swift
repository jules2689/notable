import Foundation

/// Parses custom component syntax from markdown text
/// Syntax: {% component_type args %}
struct ComponentParser {

    /// Parse all components from markdown text
    /// - Parameter markdown: The markdown text containing component syntax
    /// - Returns: Array of parsed components with their locations
    static func parse(_ markdown: String) -> [ParsedComponent] {
        var components: [ParsedComponent] = []

        // Regex pattern to match {% component_type args %}
        let pattern = #"\{%\s*(\w+)\s+([^%}]+)\s*%\}"#

        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return components
        }

        let nsRange = NSRange(markdown.startIndex..., in: markdown)
        let matches = regex.matches(in: markdown, options: [], range: nsRange)

        for match in matches {
            guard match.numberOfRanges == 3,
                  let componentTypeRange = Range(match.range(at: 1), in: markdown),
                  let argsRange = Range(match.range(at: 2), in: markdown),
                  let fullRange = Range(match.range(at: 0), in: markdown) else {
                continue
            }

            let componentType = String(markdown[componentTypeRange]).lowercased()
            let args = String(markdown[argsRange]).trimmingCharacters(in: .whitespacesAndNewlines)
            let originalText = String(markdown[fullRange])

            if let component = parseComponent(type: componentType, args: args) {
                let parsedComponent = ParsedComponent(
                    component: component,
                    range: fullRange,
                    originalText: originalText
                )
                components.append(parsedComponent)
            }
        }

        return components
    }

    /// Parse a single component based on type and arguments
    private static func parseComponent(type: String, args: String) -> Component? {
        switch type {
        case "callout":
            return parseCallout(args: args)
        case "iframe":
            return parseIframe(args: args)
        case "map":
            return parseMap(args: args)
        default:
            return nil
        }
    }

    /// Parse callout component: {% callout type | content %}
    private static func parseCallout(args: String) -> Component? {
        let parts = args.split(separator: "|", maxSplits: 1)

        guard parts.count == 2 else {
            // Default to info if no type specified
            return .callout(type: .info, content: args)
        }

        let typeString = parts[0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let content = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)

        let type = Component.CalloutType(rawValue: typeString) ?? .info

        return .callout(type: type, content: content)
    }

    /// Parse iframe component: {% iframe url %}
    private static func parseIframe(args: String) -> Component? {
        let url = args.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !url.isEmpty else {
            return nil
        }

        return .iframe(url: url)
    }

    /// Parse map component: {% map location %}
    private static func parseMap(args: String) -> Component? {
        let location = args.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !location.isEmpty else {
            return nil
        }

        return .map(location: location)
    }

    /// Replace components in markdown with HTML
    /// - Parameters:
    ///   - markdown: Original markdown text
    ///   - darkMode: Whether to render in dark mode
    /// - Returns: Markdown with components replaced by HTML
    static func replaceComponents(in markdown: String, darkMode: Bool) -> String {
        let components = parse(markdown)

        // Sort by range in reverse order so we can replace without invalidating indices
        let sortedComponents = components.sorted { $0.range.lowerBound > $1.range.lowerBound }

        var result = markdown

        for parsed in sortedComponents {
            let html = parsed.component.toHTML(darkMode: darkMode)
            result.replaceSubrange(parsed.range, with: html)
        }

        return result
    }

    /// Get component template for slash command insertion
    static func template(for componentType: String, args: [String] = []) -> String {
        switch componentType.lowercased() {
        case "callout":
            let type = args.first ?? "info"
            return "{% callout \(type) | Your message here %}"
        case "iframe":
            return "{% iframe https://example.com %}"
        case "map":
            return "{% map Address or location %}"
        default:
            return ""
        }
    }
}
