import Foundation

/// Represents a custom component that can be embedded in markdown
enum Component: Equatable {
    case callout(type: CalloutType, content: String)
    case iframe(url: String)
    case map(location: String)

    /// The type of callout box to display
    enum CalloutType: String, CaseIterable {
        case info
        case warning
        case error
        case success

        var icon: String {
            switch self {
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .success: return "✅"
            }
        }

        var color: String {
            switch self {
            case .info: return "#3b82f6"      // blue
            case .warning: return "#f59e0b"   // amber
            case .error: return "#ef4444"     // red
            case .success: return "#10b981"   // green
            }
        }
    }

    /// Renders the component as HTML
    func toHTML(darkMode: Bool) -> String {
        switch self {
        case .callout(let type, let content):
            return renderCallout(type: type, content: content, darkMode: darkMode)
        case .iframe(let url):
            return renderIframe(url: url)
        case .map(let location):
            return renderMap(location: location)
        }
    }

    private func renderCallout(type: CalloutType, content: String, darkMode: Bool) -> String {
        let backgroundColor = darkMode ? "rgba(\(hexToRGB(type.color)), 0.2)" : "rgba(\(hexToRGB(type.color)), 0.1)"
        let borderColor = type.color
        let textColor = darkMode ? "#ffffff" : "#1f2937"

        return """
        <div class="component-callout callout-\(type.rawValue)" style="
            background-color: \(backgroundColor);
            border-left: 4px solid \(borderColor);
            padding: 16px;
            margin: 16px 0;
            border-radius: 8px;
            display: flex;
            align-items: flex-start;
            gap: 12px;
        ">
            <div class="callout-icon" style="
                font-size: 20px;
                line-height: 1;
                flex-shrink: 0;
            ">\(type.icon)</div>
            <div class="callout-content" style="
                flex: 1;
                color: \(textColor);
                line-height: 1.6;
            ">\(content)</div>
        </div>
        """
    }

    private func renderIframe(url: String) -> String {
        // Sanitize URL and add security attributes
        let sanitizedURL = url.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        <div class="component-iframe" style="
            margin: 16px 0;
            border-radius: 8px;
            overflow: hidden;
            border: 1px solid #e5e7eb;
            background: #f9fafb;
        ">
            <iframe src="\(sanitizedURL)"
                style="
                    width: 100%;
                    height: 400px;
                    border: none;
                    display: block;
                "
                sandbox="allow-scripts allow-same-origin allow-forms"
                loading="lazy">
            </iframe>
        </div>
        """
    }

    private func renderMap(location: String) -> String {
        // Leaflet map with Nominatim geocoding
        let encodedLocation = location.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? location

        // Generate a unique ID for this map component
        let mapId = "map-\(UUID().uuidString)"

        return """
        <div class="component-map" style="
            margin: 16px 0;
            border-radius: 8px;
            overflow: hidden;
            border: 1px solid #e5e7eb;
            background: #f9fafb;
        ">
            <div style="
                padding: 8px 12px;
                background: #f3f4f6;
                border-bottom: 1px solid #e5e7eb;
                font-size: 12px;
                color: #6b7280;
            ">
                📍 \(location)
            </div>
            <div id="\(mapId)" style="
                width: 100%;
                height: 300px;
                background: #f9fafb;
            ">
            </div>
            <div style="
                padding: 4px 8px;
                background: #f9fafb;
                text-align: right;
                font-size: 10px;
            ">
                <a href="https://www.openstreetmap.org/search?query=\(encodedLocation)"
                   target="_blank"
                   style="color: #6b7280; text-decoration: none;">
                    View on OpenStreetMap →
                </a>
            </div>
        </div>
        <script data-component-script="true">
        (function() {
            const mapId = '\(mapId)';
            const query = '\(encodedLocation)';

            // Wait for Leaflet to be available
            if (typeof L === 'undefined') {
                console.error('Leaflet not loaded');
                document.getElementById(mapId).innerHTML = '<div style="color: #ef4444; display: flex; align-items: center; justify-content: center; height: 100%;">Error: Map library not loaded</div>';
                return;
            }

            // Fetch coordinates from Nominatim
            fetch(`https://nominatim.openstreetmap.org/search?q=${query}&format=json&limit=1`)
                .then(response => response.json())
                .then(data => {
                    if (data && data.length > 0) {
                        const result = data[0];
                        const lat = parseFloat(result.lat);
                        const lon = parseFloat(result.lon);

                        // Initialize the map
                        const map = L.map(mapId).setView([lat, lon], 13);

                        // Add OpenStreetMap tile layer
                        L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
                            attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors',
                            maxZoom: 19
                        }).addTo(map);

                        // Add marker
                        L.marker([lat, lon]).addTo(map)
                            .bindPopup('\(location)')
                            .openPopup();
                    } else {
                        document.getElementById(mapId).innerHTML = '<div style="color: #ef4444; display: flex; align-items: center; justify-content: center; height: 100%;">Location not found</div>';
                    }
                })
                .catch(error => {
                    console.error('Error geocoding location:', error);
                    document.getElementById(mapId).innerHTML = '<div style="color: #ef4444; display: flex; align-items: center; justify-content: center; height: 100%;">Error loading map</div>';
                });
        })();
        </script>
        """
    }

    private func hexToRGB(_ hex: String) -> String {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Int((int >> 16) & 0xFF)
        let g = Int((int >> 8) & 0xFF)
        let b = Int(int & 0xFF)
        return "\(r), \(g), \(b)"
    }
}

/// Parsed component with its original source location
struct ParsedComponent {
    let component: Component
    let range: Range<String.Index>
    let originalText: String
}
