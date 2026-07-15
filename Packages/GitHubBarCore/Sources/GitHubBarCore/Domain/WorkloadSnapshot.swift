import Foundation

public struct WorkloadSnapshot: Codable, Equatable, Sendable {
    public enum Completeness: String, Codable, Equatable, Sendable {
        case complete
        case partial
    }

    public let schemaVersion: Int
    public let hostname: String
    public let accountLogin: String
    public let capturedAt: Date
    public let completeness: Completeness
    public let repositoryScope: RepositoryScope
    public let availableRepositories: [RepositoryChoice]
    public let waitingForReview: [PullRequestPresentation]
    public let authoredPullRequests: [PullRequestPresentation]

    public init(
        schemaVersion: Int = 1,
        hostname: String,
        accountLogin: String,
        capturedAt: Date,
        completeness: Completeness,
        repositoryScope: RepositoryScope,
        availableRepositories: [RepositoryChoice],
        waitingForReview: [PullRequestPresentation],
        authoredPullRequests: [PullRequestPresentation]
    ) {
        self.schemaVersion = schemaVersion
        self.hostname = hostname
        self.accountLogin = accountLogin
        self.capturedAt = capturedAt
        self.completeness = completeness
        self.repositoryScope = repositoryScope
        self.availableRepositories = availableRepositories
        self.waitingForReview = waitingForReview
        self.authoredPullRequests = authoredPullRequests
    }
}
