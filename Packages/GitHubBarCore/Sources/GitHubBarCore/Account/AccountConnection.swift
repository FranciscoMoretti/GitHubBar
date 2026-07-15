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
    let accessToken: AccountAccessToken

    init(
        login: String,
        hostname: String,
        scopes: Set<String>,
        accessCoverage: AccessCoverage,
        accessToken: AccountAccessToken
    ) {
        self.login = login
        self.hostname = hostname
        self.scopes = scopes
        self.accessCoverage = accessCoverage
        self.accessToken = accessToken
    }
}

struct AccountAccessToken: CustomDebugStringConvertible, CustomStringConvertible, Sendable {
    let value: String

    var description: String { "<redacted>" }
    var debugDescription: String { "<redacted>" }
}

public struct UnavailableAccountConnection: AccountConnection {
    public init() {}

    public func inspect(selectedLogin: String?) async -> AccountConnectionResult {
        .failed(.unavailable)
    }
}
