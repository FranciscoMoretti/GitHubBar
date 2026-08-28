import AppKit
import SwiftUI

extension ColorScheme {
    /// Menu and popover chrome is drawn by AppKit in the system appearance.
    @MainActor
    static var systemAppearance: ColorScheme {
        NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .dark : .light
    }
}
