import AppKit
import GitHubBarCore

enum StatusIconRenderer {
    private static let iconSize = NSSize(width: 18, height: 18)

    static func image(reviewCount: Int) -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { bounds in
            drawPullRequestMark(in: bounds)
            if let countText = ReviewCountDisplay.text(for: reviewCount) {
                drawCarvedCount(text: countText, in: bounds)
            }
            return true
        }
        image.isTemplate = true
        image.size = iconSize
        return image
    }

    private static func drawPullRequestMark(in bounds: NSRect) {
        NSColor.black.setStroke()

        let path = NSBezierPath()
        path.lineWidth = 1.5
        path.lineCapStyle = .round
        path.lineJoinStyle = .round

        path.move(to: NSPoint(x: 4.1, y: 4.65))
        path.line(to: NSPoint(x: 4.1, y: 13.35))

        path.move(to: NSPoint(x: 8, y: 12.7))
        path.line(to: NSPoint(x: 11, y: 12.7))
        path.curve(
            to: NSPoint(x: 13.95, y: 9.9),
            controlPoint1: NSPoint(x: 12.65, y: 12.7),
            controlPoint2: NSPoint(x: 13.95, y: 11.55)
        )
        path.line(to: NSPoint(x: 13.95, y: 4.65))

        path.move(to: NSPoint(x: 8, y: 12.7))
        path.line(to: NSPoint(x: 10.15, y: 14.8))
        path.move(to: NSPoint(x: 8, y: 12.7))
        path.line(to: NSPoint(x: 10.15, y: 10.6))
        path.stroke()

        drawNode(center: NSPoint(x: 4.1, y: 3.4))
        drawNode(center: NSPoint(x: 4.1, y: 14.6))
        drawNode(center: NSPoint(x: 13.95, y: 3.4))
    }

    private static func drawNode(center: NSPoint) {
        let node = NSBezierPath(ovalIn: NSRect(x: center.x - 1.25, y: center.y - 1.25, width: 2.5, height: 2.5))
        node.lineWidth = 1.35
        node.stroke()
    }

    private static func drawCarvedCount(text: String, in bounds: NSRect) {
        let fontSize: CGFloat = text.count == 1 ? 8.9 : 8
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: NSColor.black,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let size = string.size()
        let origin = NSPoint(
            x: bounds.maxX - size.width - 0.15,
            y: -0.15
        )

        let carveOrigin = NSPoint(
            x: origin.x - 1.35,
            y: bounds.minY - 3.5
        )
        let carveTop: CGFloat = 9.2
        let carveRect = NSRect(
            x: carveOrigin.x,
            y: carveOrigin.y,
            width: bounds.maxX + 3.5 - carveOrigin.x,
            height: carveTop - carveOrigin.y
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        NSColor.black.setFill()
        NSBezierPath(
            roundedRect: carveRect,
            xRadius: 2.6,
            yRadius: 2.6
        ).fill()
        NSGraphicsContext.restoreGraphicsState()

        string.draw(at: origin)
    }
}
