import AppKit
import Combine
import Foundation

@MainActor
final class AvatarImageCache: ObservableObject {
    typealias Loader = @Sendable (URL) async throws -> Data

    @Published private var revision = 0
    private let images = NSCache<NSURL, NSImage>()
    private var loading: [URL: Task<Data?, Never>] = [:]
    private var generation = 0
    private let loader: Loader

    init(loader: @escaping Loader = AvatarImageCache.loadData) {
        self.loader = loader
        images.countLimit = 512
    }

    func image(for url: URL) -> NSImage? {
        _ = revision
        return images.object(forKey: url as NSURL)
    }

    func preload(_ urls: [URL]) async {
        let generation = self.generation
        let requests = Set(urls).compactMap { url -> (URL, Task<Data?, Never>)? in
            guard image(for: url) == nil else { return nil }
            if let task = loading[url] {
                return (url, task)
            }
            let loader = self.loader
            let task = Task.detached(priority: .utility) {
                try? await loader(url)
            }
            loading[url] = task
            return (url, task)
        }

        await withTaskGroup(of: (URL, Data?).self) { group in
            for (url, task) in requests {
                group.addTask {
                    (url, await task.value)
                }
            }

            for await (url, data) in group {
                guard generation == self.generation else { continue }
                loading[url] = nil
                guard image(for: url) == nil,
                      let data,
                      let image = NSImage(data: data) else { continue }
                images.setObject(image, forKey: url as NSURL)
                revision &+= 1
            }
        }
    }

    func removeAll() {
        generation &+= 1
        for task in loading.values {
            task.cancel()
        }
        loading.removeAll()
        images.removeAllObjects()
        revision &+= 1
    }

    private static func loadData(from url: URL) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let response = response as? HTTPURLResponse,
           !(200..<300).contains(response.statusCode) {
            throw AvatarImageCacheError.httpStatus(response.statusCode)
        }
        return data
    }
}

private enum AvatarImageCacheError: Error {
    case httpStatus(Int)
}
