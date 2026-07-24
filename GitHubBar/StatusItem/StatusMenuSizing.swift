import Foundation

enum StatusMenuSizing {
    static let mainMenuWidth: CGFloat = 560
    private static let minimumStackSubmenuWidth: CGFloat = 440
    private static let preferredStackSubmenuWidth: CGFloat = 560
    private static let maximumStackSubmenuWidth: CGFloat = 680
    private static let horizontalScreenMargin: CGFloat = 64

    static func stackSubmenuWidth(visibleScreenWidth: CGFloat?) -> CGFloat {
        guard let visibleScreenWidth else {
            return preferredStackSubmenuWidth
        }
        let availableWidth = visibleScreenWidth - mainMenuWidth - horizontalScreenMargin
        return min(
            maximumStackSubmenuWidth,
            max(minimumStackSubmenuWidth, availableWidth)
        )
    }
}
