import Foundation

public protocol GitHubCLIExecutableLocating: Sendable {
    func locate() -> URL?
}

public struct GitHubCLIExecutableLocator: GitHubCLIExecutableLocating {
    private let searchPaths: [String]
    private let environmentPath: String

    public init(
        searchPaths: [String] = [
            "/opt/homebrew/bin/gh",
            "/usr/local/bin/gh",
            "/usr/bin/gh",
        ],
        environmentPath: String = ProcessInfo.processInfo.environment["PATH"] ?? ""
    ) {
        self.searchPaths = searchPaths
        self.environmentPath = environmentPath
    }

    public func locate() -> URL? {
        let pathCandidates = environmentPath
            .split(separator: ":")
            .map { URL(fileURLWithPath: String($0)).appendingPathComponent("gh").path }

        for path in searchPaths + pathCandidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
