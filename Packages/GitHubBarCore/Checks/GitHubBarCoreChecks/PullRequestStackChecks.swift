import Foundation
import GitHubBarCore

enum PullRequestStackChecks {
    static func run() -> [String] {
        var failures: [String] = []
        let root = pullRequest(
            id: "PR-2872",
            number: 2872,
            base: "main",
            head: "skills-1",
            updatedAt: 1
        )
        let middle = pullRequest(
            id: "PR-2873",
            number: 2873,
            base: "skills-1",
            head: "skills-2",
            updatedAt: 2
        )
        let top = pullRequest(
            id: "PR-2874",
            number: 2874,
            base: "skills-2",
            head: "skills-3",
            updatedAt: 3
        )
        let unrelated = pullRequest(
            id: "PR-2860",
            number: 2860,
            base: "main",
            head: "north-star",
            updatedAt: 4
        )

        let stacks = PullRequestStackResolver.stacks(in: [top, unrelated, root, middle])
        check(stacks.count == 1, "A linear branch chain resolves to one Pull request stack", failures: &failures)
        check(
            stacks.first?.pullRequests.map(\.number) == [2872, 2873, 2874],
            "Pull request stack members are ordered from Stack root to top",
            failures: &failures
        )
        check(
            stacks.first?.githubPullRequestListURL?.absoluteString ==
                "https://github.com/alaro-ai/alaro/pulls?q=is:pr%20(2872%20OR%202873%20OR%202874)",
            "A Pull request stack exposes an exact GitHub PR-list URL",
            failures: &failures
        )

        let otherRepositoryChild = pullRequest(
            id: "OTHER-1",
            repositoryID: "REPO-2",
            repositoryName: "example/other",
            number: 1,
            base: "skills-1",
            head: "other-child",
            updatedAt: 5
        )
        check(
            PullRequestStackResolver.stacks(in: [root, otherRepositoryChild]).isEmpty,
            "Matching branch names in different repositories do not create a Pull request stack",
            failures: &failures
        )

        let sibling = pullRequest(
            id: "PR-2875",
            number: 2875,
            base: "skills-1",
            head: "alternate-skills-2",
            updatedAt: 6
        )
        check(
            PullRequestStackResolver.stacks(in: [root, middle, sibling]).isEmpty,
            "A branched dependency graph is not presented as a linear Pull request stack",
            failures: &failures
        )
        return failures
    }

    private static func pullRequest(
        id: String,
        repositoryID: String = "REPO-1",
        repositoryName: String = "alaro-ai/alaro",
        number: Int,
        base: String,
        head: String,
        updatedAt: TimeInterval
    ) -> PullRequestPresentation {
        PullRequestPresentation(
            id: id,
            repositoryID: repositoryID,
            repositoryNameWithOwner: repositoryName,
            baseRefName: base,
            headRefName: head,
            headRepositoryID: repositoryID,
            number: number,
            title: "PR \(number)",
            url: URL(string: "https://github.com/\(repositoryName)/pull/\(number)")!,
            isDraft: false,
            updatedAt: Date(timeIntervalSince1970: updatedAt),
            reviewers: []
        )
    }

    private static func check(_ condition: Bool, _ message: String, failures: inout [String]) {
        if !condition { failures.append("FAILED: \(message)") }
    }
}
