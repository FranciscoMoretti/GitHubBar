public enum ReviewCountDisplay {
    public static func text(for reviewCount: Int) -> String? {
        switch reviewCount {
        case ...0: nil
        case 1...99: String(reviewCount)
        default: "99"
        }
    }
}
