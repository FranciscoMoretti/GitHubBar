import Foundation
import GitHubBarCore

enum RepositoryScopeChecks {
    static func run() async -> [String] {
        var failures: [String] = []
        let workloadClient = RacingWorkloadClient()
        let settingsStore = InMemorySettingsStore(
            settings: AppSettings(selectedLogin: "FranciscoMoretti")
        )
        let engine = WorkloadEngine(
            accountConnection: ScopeAccountConnection(),
            workloadClient: workloadClient,
            settingsStore: settingsStore
        )
        let stream = await engine.states()
        let recorder = ScopeStateRecorder()
        let recording = Task {
            for await state in stream {
                await recorder.append(state)
            }
        }
        let starts = await workloadClient.starts()
        var startIterator = starts.makeAsyncIterator()

        let launch = Task { await engine.send(.launch) }
        _ = await startIterator.next()
        await engine.send(.selectRepositoryScope(.selected(["REPO-1"])))
        await launch.value
        try? await Task.sleep(for: .milliseconds(20))
        recording.cancel()

        let finalState = await recorder.values.last
        check(finalState?.repositoryScope == .selected(["REPO-1"]), "Latest Repository scope remains selected", failures: &failures)
        check(finalState?.authoredPullRequests.map(\.id) == ["SCOPED"], "Stale prior-scope reconciliation cannot overwrite new scope", failures: &failures)
        check(await settingsStore.load().repositoryScope == .selected(["REPO-1"]), "Repository scope persists", failures: &failures)
        return failures
    }

    private static func check(_ condition: Bool, _ message: String, failures: inout [String]) {
        if !condition { failures.append("FAILED: \(message)") }
    }
}

private struct ScopeAccountConnection: AccountConnection {
    func inspect(selectedLogin: String?) async -> AccountConnectionResult {
        .connected(
            ResolvedAccount(
                login: "FranciscoMoretti",
                hostname: "github.com",
                scopes: ["read:org", "repo"],
                accessCoverage: AccessCoverage(isComplete: true),
                accessToken: GitHubAccessToken("test-token")
            )
        )
    }
}

private actor RacingWorkloadClient: GitHubWorkloadClient {
    private let startedStream: AsyncStream<RepositoryScope>
    private let startedContinuation: AsyncStream<RepositoryScope>.Continuation

    init() {
        (startedStream, startedContinuation) = AsyncStream.makeStream(of: RepositoryScope.self)
    }

    func starts() -> AsyncStream<RepositoryScope> { startedStream }

    func reconcile(
        account: ResolvedAccount,
        repositoryScope: RepositoryScope,
        previousSnapshot: WorkloadSnapshot?
    ) async -> WorkloadReconciliationResult {
        startedContinuation.yield(repositoryScope)
        switch repositoryScope {
        case .all:
            try? await Task.sleep(for: .milliseconds(80))
            return .complete(snapshot(id: "STALE", scope: .all), .empty)
        case .selected:
            try? await Task.sleep(for: .milliseconds(5))
            return .complete(snapshot(id: "SCOPED", scope: repositoryScope), .empty)
        }
    }

    private func snapshot(id: String, scope: RepositoryScope) -> WorkloadSnapshot {
        WorkloadSnapshot(
            hostname: "github.com",
            accountLogin: "FranciscoMoretti",
            capturedAt: Date(),
            completeness: .complete,
            repositoryScope: scope,
            availableRepositories: [RepositoryChoice(id: "REPO-1", nameWithOwner: "alaro-ai/alaro")],
            waitingForReview: [],
            authoredPullRequests: [
                PullRequestPresentation(
                    id: id,
                    repositoryID: "REPO-1",
                    repositoryNameWithOwner: "alaro-ai/alaro",
                    number: 1,
                    title: id,
                    url: URL(string: "https://github.com/alaro-ai/alaro/pull/1")!,
                    isDraft: false,
                    updatedAt: Date(),
                    reviewers: []
                ),
            ]
        )
    }
}

private actor ScopeStateRecorder {
    private(set) var values: [AppPresentationState] = []
    func append(_ state: AppPresentationState) { values.append(state) }
}
