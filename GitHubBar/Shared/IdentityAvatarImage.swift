import SwiftUI

struct IdentityAvatarImage: View {
    let displayName: String?
    let avatarURL: URL?
    @EnvironmentObject private var cache: AvatarImageCache

    var body: some View {
        Group {
            if let avatarURL, let image = cache.image(for: avatarURL) {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .onAppear {
            if let avatarURL {
                Task {
                    await cache.preload([avatarURL])
                }
            }
        }
    }

    private var fallback: some View {
        Group {
            if let initials, !initials.isEmpty {
                Text(initials)
                    .font(.system(size: 6, weight: .bold))
            } else {
                Image(systemName: "person.fill")
                    .font(.system(size: 7, weight: .medium))
            }
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }

    private var initials: String? {
        guard let displayName else { return nil }
        return displayName
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
