public enum ReviewCountBadge {
    public static func text(for reviewCount: Int) -> String? {
        switch reviewCount {
        case ...0: nil
        case 1...9: String(reviewCount)
        default: "9+"
        }
    }
}
