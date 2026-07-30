import Foundation
import GitHubBarCore

enum PullRequestStackChecks {
    static func run() -> [String] {
        var failures: [String] = []
        let root = pullRequest(
            id: "PR-2872",
            number: 2872,
            stackID: "STACK-350",
            stackNumber: 350,
            stackSize: 3,
            stackPosition: 1,
            updatedAt: 1
        )
        let middle = pullRequest(
            id: "PR-2873",
            number: 2873,
            stackID: "STACK-350",
            stackNumber: 350,
            stackSize: 3,
            stackPosition: 2,
            updatedAt: 2
        )
        let top = pullRequest(
            id: "PR-2874",
            number: 2874,
            stackID: "STACK-350",
            stackNumber: 350,
            stackSize: 3,
            stackPosition: 3,
            updatedAt: 3
        )
        let unrelated = pullRequest(
            id: "PR-2860",
            number: 2860,
            updatedAt: 4
        )

        let stacks = PullRequestStackResolver.stacks(in: [top, unrelated, root, middle])
        check(stacks.count == 1, "GitHub Stack membership resolves one Pull request stack", failures: &failures)
        check(
            stacks.first?.pullRequests.map(\.number) == [2872, 2873, 2874],
            "GitHub Stack positions order members from Stack root to top",
            failures: &failures
        )
        check(
            stacks.first?.number == 350,
            "GitHub Stack number is retained for navigation context",
            failures: &failures
        )
        check(
            stacks.first?.size == 3,
            "GitHub Stack reports the authoritative member count",
            failures: &failures
        )
        check(
            stacks.first?.navigationURL == root.url,
            "GitHub Stack navigation opens its root pull request",
            failures: &failures
        )
        check(
            stacks.first?.members(withIDs: [top.id, root.id]).map(\.number) == [2872, 2874],
            "Section members retain Stack root-to-top order",
            failures: &failures
        )

        let partiallyHydratedStack = PullRequestStack(
            id: "STACK-350",
            number: 350,
            size: 3,
            pullRequests: [middle, top]
        )
        check(
            partiallyHydratedStack.root == nil,
            "A partially hydrated Stack does not relabel another member as the Stack root",
            failures: &failures
        )
        check(
            partiallyHydratedStack.navigationURL == middle.url,
            "A partially hydrated Stack can navigate through an available member",
            failures: &failures
        )

        let unstackedRoot = pullRequest(id: "UNSTACKED-1", number: 1, updatedAt: 4)
        let unstackedChild = pullRequest(id: "UNSTACKED-2", number: 2, updatedAt: 5)
        check(
            PullRequestStackResolver.stacks(in: [unstackedRoot, unstackedChild]).isEmpty,
            "Pull requests without GitHub Stack membership remain unstacked",
            failures: &failures
        )
        return failures
    }

    private static func pullRequest(
        id: String,
        repositoryID: String = "REPO-1",
        repositoryName: String = "alaro-ai/alaro",
        number: Int,
        stackID: String? = nil,
        stackNumber: Int? = nil,
        stackSize: Int? = nil,
        stackPosition: Int? = nil,
        updatedAt: TimeInterval
    ) -> PullRequestPresentation {
        PullRequestPresentation(
            id: id,
            repositoryID: repositoryID,
            repositoryNameWithOwner: repositoryName,
            number: number,
            title: "PR \(number)",
            url: URL(string: "https://github.com/\(repositoryName)/pull/\(number)")!,
            isDraft: false,
            stackMembership: stackID.flatMap { stackID in
                guard let stackNumber, let stackSize, let stackPosition else { return nil }
                return PullRequestStackMembership(
                    id: stackID,
                    number: stackNumber,
                    size: stackSize,
                    position: stackPosition
                )
            },
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            reviewers: []
        )
    }

    private static func check(_ condition: Bool, _ message: String, failures: inout [String]) {
        if !condition { failures.append("FAILED: \(message)") }
    }
}
