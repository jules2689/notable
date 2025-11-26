import SwiftUI
import AppKit

/// A SwiftUI wrapper for the tooltip NSView
struct TooltipNSViewRepresentable: NSViewRepresentable {
    let text: String
    let delay: TimeInterval
    
    func makeNSView(context: Context) -> TooltipNSView {
        TooltipNSView(text: text, delay: delay)
    }
    
    func updateNSView(_ nsView: TooltipNSView, context: Context) {
        // Update if needed
    }
}

/// A custom tooltip modifier that shows tooltips with a shorter delay than the default
struct QuickTooltip: ViewModifier {
    let text: String
    let delay: TimeInterval
    
    init(_ text: String, delay: TimeInterval = 0.3) {
        self.text = text
        self.delay = delay
    }
    
    func body(content: Content) -> some View {
        content.background(
            TooltipNSViewRepresentable(text: text, delay: delay)
        )
    }
}

/// An NSView that provides tooltips with custom delay using AppKit's native tooltip system
@MainActor
class TooltipNSView: NSView {
    let tooltipText: String
    let delay: TimeInterval
    var tooltipTimer: Timer?
    var trackingArea: NSTrackingArea?
    var tooltipWindow: NSWindow?
    
    init(text: String, delay: TimeInterval) {
        self.tooltipText = text
        self.delay = delay
        super.init(frame: .zero)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        updateTrackingAreas()
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        
        if let trackingArea = trackingArea {
            removeTrackingArea(trackingArea)
        }
        
        // Use the full bounds of the view for tracking
        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.activeInKeyWindow, .mouseEnteredAndExited, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        
        if let trackingArea = trackingArea {
            addTrackingArea(trackingArea)
        }
    }
    
    override func layout() {
        super.layout()
        // Update tracking areas when layout changes
        updateTrackingAreas()
    }
    
    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        
        // Cancel any existing timer
        tooltipTimer?.invalidate()
        
        // Schedule tooltip to show after the specified delay
        tooltipTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.showTooltip()
            }
        }
    }
    
    override func mouseExited(with event: NSEvent) {
        super.mouseExited(with: event)
        
        // Cancel tooltip
        tooltipTimer?.invalidate()
        tooltipTimer = nil
        hideTooltip()
    }
    
    private func showTooltip() {
        guard let window = self.window else { return }
        
        // Create tooltip view
        let tooltipView = NSTextField(labelWithString: tooltipText)
        tooltipView.font = .systemFont(ofSize: 11)
        tooltipView.textColor = .white
        tooltipView.backgroundColor = .clear
        tooltipView.isBordered = false
        tooltipView.isBezeled = false
        tooltipView.drawsBackground = false
        tooltipView.maximumNumberOfLines = 0
        tooltipView.lineBreakMode = .byWordWrapping
        
        // Calculate size
        let maxWidth: CGFloat = 300
        let textSize = tooltipView.sizeThatFits(NSSize(width: maxWidth, height: CGFloat.greatestFiniteMagnitude))
        
        // Add padding
        let padding: CGFloat = 8
        let containerSize = NSSize(width: textSize.width + padding * 2, height: textSize.height + padding * 2)
        
        // Create container view with background (brighter gray, slightly transparent)
        let containerView = NSView(frame: NSRect(origin: .zero, size: containerSize))
        containerView.wantsLayer = true
        // Use brighter gray with transparency
        containerView.layer?.backgroundColor = NSColor(white: 0.4, alpha: 0.85).cgColor
        containerView.layer?.cornerRadius = 4
        // Add subtle outline/border
        containerView.layer?.borderWidth = 1.0
        containerView.layer?.borderColor = NSColor(white: 0.3, alpha: 0.6).cgColor
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.3
        containerView.layer?.shadowOffset = NSSize(width: 0, height: 2)
        containerView.layer?.shadowRadius = 4
        
        // Position text view with padding
        tooltipView.frame = NSRect(
            origin: NSPoint(x: padding, y: padding),
            size: textSize
        )
        containerView.addSubview(tooltipView)
        
        // Create tooltip window
        let tooltipWindow = NSWindow(
            contentRect: NSRect(origin: .zero, size: containerSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        tooltipWindow.backgroundColor = .clear
        tooltipWindow.isOpaque = false
        tooltipWindow.level = .floating
        tooltipWindow.ignoresMouseEvents = true
        tooltipWindow.contentView = containerView
        
        // Get current mouse location in window coordinates
        let mouseLocation = window.mouseLocationOutsideOfEventStream
        
        // Convert mouse location to screen coordinates
        let mouseScreenPoint = window.convertPoint(toScreen: mouseLocation)
        
        let spacing: CGFloat = 8 // Space between cursor and tooltip
        var screenPoint = mouseScreenPoint
        
        if let screen = window.screen {
            let screenFrame = screen.visibleFrame
            
            // Try to position below cursor first
            let spaceBelow = mouseScreenPoint.y - screenFrame.minY
            let spaceAbove = screenFrame.maxY - mouseScreenPoint.y
            
            if spaceBelow >= containerSize.height + spacing {
                // Enough space below - position below cursor
                screenPoint.y = mouseScreenPoint.y - containerSize.height - spacing
                // Center horizontally on cursor
                screenPoint.x = mouseScreenPoint.x - containerSize.width / 2
            } else if spaceAbove >= containerSize.height + spacing {
                // Not enough space below, but enough above - position above cursor
                screenPoint.y = mouseScreenPoint.y + spacing
                // Center horizontally on cursor
                screenPoint.x = mouseScreenPoint.x - containerSize.width / 2
            } else {
                // Not enough space above or below - position to the side
                let spaceOnRight = screenFrame.maxX - mouseScreenPoint.x - spacing
                let spaceOnLeft = mouseScreenPoint.x - screenFrame.minX - spacing
                
                // Position to the right if there's enough space, otherwise to the left
                if spaceOnRight >= containerSize.width {
                    // Position to the right of cursor
                    screenPoint.x = mouseScreenPoint.x + spacing
                } else if spaceOnLeft >= containerSize.width {
                    // Position to the left of cursor
                    screenPoint.x = mouseScreenPoint.x - containerSize.width - spacing
                } else {
                    // Not enough space on either side, use whichever has more space
                    if spaceOnRight > spaceOnLeft {
                        screenPoint.x = mouseScreenPoint.x + spacing
                    } else {
                        screenPoint.x = mouseScreenPoint.x - containerSize.width - spacing
                    }
                }
                
                // Vertically center tooltip on cursor when on the side
                screenPoint.y = mouseScreenPoint.y - containerSize.height / 2
            }
            
            // Ensure tooltip stays on screen (clamp to screen bounds)
            screenPoint.x = max(screenFrame.minX, min(screenPoint.x, screenFrame.maxX - containerSize.width))
            screenPoint.y = max(screenFrame.minY, min(screenPoint.y, screenFrame.maxY - containerSize.height))
        } else {
            // Fallback: position below cursor if no screen info
            screenPoint.y = mouseScreenPoint.y - containerSize.height - spacing
            screenPoint.x = mouseScreenPoint.x - containerSize.width / 2
        }
        
        tooltipWindow.setFrameOrigin(screenPoint)
        tooltipWindow.orderFront(nil)
        self.tooltipWindow = tooltipWindow
    }
    
    private func hideTooltip() {
        tooltipWindow?.orderOut(nil)
        tooltipWindow = nil
    }
    
    nonisolated deinit {
        // NSView deinit is always called on main thread
        // Since NSView deinit is always on main thread, we can assume main actor isolation
        if Thread.isMainThread {
            MainActor.assumeIsolated {
                // Invalidate timer
                self.tooltipTimer?.invalidate()
                
                // Cleanup tracking area and window
                if let area = self.trackingArea {
                    self.removeTrackingArea(area)
                }
                self.tooltipWindow?.orderOut(nil)
            }
        }
    }
}

extension View {
    /// Adds a tooltip with a shorter delay (default 0.3 seconds) using AppKit's native tooltip system
    func quickTooltip(_ text: String, delay: TimeInterval = 0.3) -> some View {
        modifier(QuickTooltip(text, delay: delay))
    }
}

