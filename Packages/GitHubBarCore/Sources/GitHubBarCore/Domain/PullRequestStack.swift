import Foundation

public struct PullRequestStackMembership: Codable, Equatable, Sendable {
    public let id: String
    public let number: Int
    public let size: Int
    public let position: Int

    public init(id: String, number: Int, size: Int, position: Int) {
        self.id = id
        self.number = number
        self.size = size
        self.position = position
    }
}

public struct PullRequestStack: Codable, Equatable, Identifiable, Sendable {
    public let id: String
    public let number: Int
    public let size: Int
    public let pullRequests: [PullRequestPresentation]

    public init(
        id: String,
        number: Int,
        size: Int? = nil,
        pullRequests: [PullRequestPresentation]
    ) {
        self.id = id
        self.number = number
        self.size = max(size ?? pullRequests.count, pullRequests.count)
        self.pullRequests = pullRequests
    }

    public var root: PullRequestPresentation? {
        pullRequests.first { $0.stackMembership?.position == 1 }
    }

    public var navigationURL: URL? {
        (root ?? pullRequests.first)?.url
    }

    public func members(withIDs pullRequestIDs: Set<String>) -> [PullRequestPresentation] {
        pullRequests.filter { pullRequestIDs.contains($0.id) }
    }

    private enum CodingKeys: String, CodingKey {
        case id, number, size, pullRequests
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let pullRequests = try container.decode(
            [PullRequestPresentation].self,
            forKey: .pullRequests
        )
        self.init(
            id: try container.decode(String.self, forKey: .id),
            number: try container.decode(Int.self, forKey: .number),
            size: try container.decodeIfPresent(Int.self, forKey: .size),
            pullRequests: pullRequests
        )
    }
}

public enum PullRequestStackResolver {
    public static func stacks(in pullRequests: [PullRequestPresentation]) -> [PullRequestStack] {
        let grouped = Dictionary(
            grouping: pullRequests.compactMap { pullRequest -> (StackKey, PullRequestPresentation)? in
                guard let membership = pullRequest.stackMembership else { return nil }
                return (
                    StackKey(repositoryID: pullRequest.repositoryID, stackID: membership.id),
                    pullRequest
                )
            },
            by: \.0
        )

        return grouped.values.compactMap { entries -> PullRequestStack? in
            let members = entries.map(\.1).sorted {
                guard let lhs = $0.stackMembership, let rhs = $1.stackMembership else {
                    return pullRequestOrder($0, $1)
                }
                if lhs.position != rhs.position { return lhs.position < rhs.position }
                return pullRequestOrder($0, $1)
            }
            guard members.count > 1, let membership = members.first?.stackMembership else {
                return nil
            }
            return PullRequestStack(
                id: membership.id,
                number: membership.number,
                size: members.compactMap(\.stackMembership?.size).max(),
                pullRequests: members
            )
        }
        .sorted {
            pullRequestOrder(
                $0.root ?? $0.pullRequests.first,
                $1.root ?? $1.pullRequests.first
            )
        }
    }

    private static func pullRequestOrder(
        _ lhs: PullRequestPresentation?,
        _ rhs: PullRequestPresentation?
    ) -> Bool {
        guard let lhs, let rhs else { return lhs != nil }
        if lhs.updatedAt != rhs.updatedAt { return lhs.updatedAt < rhs.updatedAt }
        return lhs.number < rhs.number
    }

    private struct StackKey: Hashable {
        let repositoryID: String
        let stackID: String
    }
}
