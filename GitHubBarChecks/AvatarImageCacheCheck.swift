import AppKit
import Foundation

@main
struct AvatarImageCacheCheck {
    static func main() async {
        let imageData = Data(
            base64Encoded: "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        )!
        let url = URL(string: "https://avatars.example/person.png")!
        let cache = await MainActor.run {
            AvatarImageCache(loader: { requestedURL in
                guard requestedURL == url else { throw CheckError.unexpectedURL }
                return imageData
            })
        }

        await cache.preload([url])
        let imageIsSynchronouslyAvailable = await MainActor.run {
            cache.image(for: url) != nil
        }
        guard imageIsSynchronouslyAvailable else {
            fatalError("Prefetched avatars must be synchronously available before menu tracking")
        }

        await MainActor.run {
            cache.removeAll()
        }
        let imageWasCleared = await MainActor.run {
            cache.image(for: url) == nil
        }
        guard imageWasCleared else {
            fatalError("Changing accounts must clear cached avatar metadata")
        }
        print("Avatar image cache check passed")
    }

    private enum CheckError: Error {
        case unexpectedURL
    }
}
