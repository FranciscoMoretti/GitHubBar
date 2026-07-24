import Foundation

@main
struct StatusMenuSizingCheck {
    static func main() {
        expectWidth(560, forVisibleScreenWidth: nil)
        expectWidth(440, forVisibleScreenWidth: 1_024)
        expectWidth(560, forVisibleScreenWidth: 1_184)
        expectWidth(656, forVisibleScreenWidth: 1_280)
        expectWidth(680, forVisibleScreenWidth: 1_512)
        print("Status menu sizing check passed")
    }

    private static func expectWidth(
        _ expectedWidth: CGFloat,
        forVisibleScreenWidth visibleScreenWidth: CGFloat?
    ) {
        let actualWidth = StatusMenuSizing.stackSubmenuWidth(
            visibleScreenWidth: visibleScreenWidth
        )
        guard actualWidth == expectedWidth else {
            fatalError(
                "Expected stack submenu width \(expectedWidth), got \(actualWidth)"
            )
        }
    }
}
