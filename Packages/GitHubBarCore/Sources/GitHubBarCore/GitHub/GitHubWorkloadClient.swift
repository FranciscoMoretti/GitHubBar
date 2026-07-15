import Foundation

public protocol GitHubWorkloadClient: Sendable {
    func reconcile(
        account: ResolvedAccount,
        repositoryScope: RepositoryScope,
        previousSnapshot: WorkloadSnapshot?
    ) async -> WorkloadReconciliationResult
}

public enum WorkloadReconciliationResult: Sendable {
    case complete(WorkloadSnapshot, ReconciliationMetadata)
    case partial(WorkloadSnapshot, ReconciliationMetadata)
    case failed(WorkloadFailure, ReconciliationMetadata)
}

public enum WorkloadFailure: String, Sendable {
    case discovery
    case hydration
    case invalidResponse
    case rateLimited
    case unavailable
}

public struct ReconciliationMetadata: Equatable, Sendable {
    public let queryCost: Int
    public let remainingPoints: Int?
    public let resetAt: Date?
    public let warnings: [String]

    public init(queryCost: Int, remainingPoints: Int?, resetAt: Date?, warnings: [String]) {
        self.queryCost = queryCost
        self.remainingPoints = remainingPoints
        self.resetAt = resetAt
        self.warnings = warnings
    }

    public static let empty = ReconciliationMetadata(
        queryCost: 0,
        remainingPoints: nil,
        resetAt: nil,
        warnings: []
    )
}

public struct UnavailableGitHubWorkloadClient: GitHubWorkloadClient {
    public init() {}

    public func reconcile(
        account: ResolvedAccount,
        repositoryScope: RepositoryScope,
        previousSnapshot: WorkloadSnapshot?
    ) async -> WorkloadReconciliationResult {
        .failed(.unavailable, .empty)
    }
}
