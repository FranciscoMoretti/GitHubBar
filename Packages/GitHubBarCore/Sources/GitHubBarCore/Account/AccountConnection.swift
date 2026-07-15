import Foundation

public protocol AccountConnection: Sendable {
    func inspect(selectedLogin: String?) async -> AccountConnectionResult
}

public enum AccountConnectionResult: Sendable {
    case cliMissing
    case authenticationRequired
    case selectionRequired([AccountCandidate])
    case connected(ResolvedAccount)
    case failed(AccountConnectionFailure)
}

public enum AccountConnectionFailure: String, Sendable {
    case invalidStatusResponse
    case credentialUnavailable
    case viewerVerificationFailed
    case viewerMismatch
    case unavailable
}

public struct ResolvedAccount: Sendable {
    public let login: String
    public let hostname: String
    public let scopes: Set<String>
    public let accessCoverage: AccessCoverage
    let accessToken: GitHubAccessToken

    public init(
        login: String,
        hostname: String,
        scopes: Set<String>,
        accessCoverage: AccessCoverage,
        accessToken: GitHubAccessToken
    ) {
        self.login = login
        self.hostname = hostname
        self.scopes = scopes
        self.accessCoverage = accessCoverage
        self.accessToken = accessToken
    }
}

public struct GitHubAccessToken: CustomDebugStringConvertible, CustomStringConvertible, Sendable {
    let rawValue: String

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { "<redacted>" }
    public var debugDescription: String { "<redacted>" }
}

public struct UnavailableAccountConnection: AccountConnection {
    public init() {}

    public func inspect(selectedLogin: String?) async -> AccountConnectionResult {
        .failed(.unavailable)
    }
}
