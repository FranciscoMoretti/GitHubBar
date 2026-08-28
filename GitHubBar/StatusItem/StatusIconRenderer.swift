import AppKit
import GitHubBarCore

@MainActor
enum StatusIconRenderer {
    private static let iconSize = NSSize(width: 18, height: 18)
    private static let githubMark: NSImage = {
        guard let image = NSImage(data: Data(githubMarkSVG.utf8)) else {
            preconditionFailure("The embedded GitHub mark must be a valid SVG")
        }
        return image
    }()

    private static let githubMarkSVG = """
    <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 16 16"><path d="M6.766 11.328c-2.063-.25-3.516-1.734-3.516-3.656 0-.781.281-1.625.75-2.188-.203-.515-.172-1.609.063-2.062.625-.078 1.468.25 1.968.703.594-.187 1.219-.281 1.985-.281.765 0 1.39.094 1.953.265.484-.437 1.344-.765 1.969-.687.218.422.25 1.515.046 2.047.5.593.766 1.39.766 2.203 0 1.922-1.453 3.375-3.547 3.64.531.344.89 1.094.89 1.954v1.625c0 .468.391.734.86.547C13.781 14.359 16 11.53 16 8.03 16 3.61 12.406 0 7.984 0 3.563 0 0 3.61 0 8.031a7.88 7.88 0 0 0 5.172 7.422c.422.156.828-.125.828-.547v-1.25c-.219.094-.5.156-.75.156-1.031 0-1.64-.562-2.078-1.609-.172-.422-.36-.672-.719-.719-.187-.015-.25-.093-.25-.187 0-.188.313-.328.625-.328.453 0 .844.281 1.25.86.313.452.64.655 1.031.655s.641-.14 1-.5c.266-.265.47-.5.657-.656"/></svg>
    """

    static func image(reviewCount: Int) -> NSImage {
        let image = NSImage(size: iconSize, flipped: false) { bounds in
            let countText = ReviewCountDisplay.text(for: reviewCount)
            drawGitHubMark(in: bounds, badged: countText != nil)
            if let countText {
                drawBadge(text: countText, in: bounds)
            }
            return true
        }
        image.isTemplate = true
        image.size = iconSize
        return image
    }

    private static func drawGitHubMark(in bounds: NSRect, badged: Bool) {
        // Shrink toward the bottom-left so the badge has a corner to sit in.
        let rect = badged
            ? NSRect(x: bounds.minX, y: bounds.minY, width: 14, height: 14)
            : bounds.insetBy(dx: 1, dy: 1)
        githubMark.draw(
            in: rect,
            from: .zero,
            operation: .sourceOver,
            fraction: 1,
            respectFlipped: false,
            hints: [.interpolation: NSImageInterpolation.high]
        )
    }

    /// Filled badge with the count knocked out of it. Template rendering paints
    /// the badge in the menu bar's tint and leaves the digits transparent.
    private static func drawBadge(text: String, in bounds: NSRect) {
        let fontSize: CGFloat = text.count == 1 ? 8 : 7
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: fontSize, weight: .black),
            .foregroundColor: NSColor.black,
        ]
        let string = NSAttributedString(string: text, attributes: attributes)
        let textSize = string.size()

        let height: CGFloat = 10
        let width = max(height, textSize.width + 5)
        let badge = NSRect(
            x: bounds.maxX - width,
            y: bounds.maxY - height,
            width: width,
            height: height
        )

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        NSColor.black.setFill()
        NSBezierPath(
            roundedRect: badge.insetBy(dx: -1.1, dy: -1.1),
            xRadius: height,
            yRadius: height
        ).fill()
        NSGraphicsContext.restoreGraphicsState()

        NSColor.black.setFill()
        NSBezierPath(
            roundedRect: badge,
            xRadius: height / 2,
            yRadius: height / 2
        ).fill()

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current?.compositingOperation = .clear
        string.draw(
            at: NSPoint(
                x: badge.midX - textSize.width / 2,
                y: badge.midY - textSize.height / 2
            )
        )
        NSGraphicsContext.restoreGraphicsState()
    }
}
