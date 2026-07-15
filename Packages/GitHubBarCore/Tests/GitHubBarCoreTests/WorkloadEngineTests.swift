import XCTest
@testable import GitHubBarCore

final class WorkloadEngineTests: XCTestCase {
    func testReviewCountBadgeCapsVisualTextWithoutCappingAccessibilityCount() {
        XCTAssertNil(ReviewCountBadge.text(for: 0))
        XCTAssertEqual(ReviewCountBadge.text(for: 4), "4")
        XCTAssertEqual(ReviewCountBadge.text(for: 57), "9+")
    }

    func testSubscriberImmediatelyReceivesTruthfulEmptyPresentation() async throws {
        let engine = WorkloadEngine(initialState: .empty)
        let stream = await engine.states()
        var iterator = stream.makeAsyncIterator()

        let state = try XCTUnwrap(await iterator.next())

        XCTAssertEqual(state, .empty)
        XCTAssertTrue(state.waitingForReview.isEmpty)
        XCTAssertTrue(state.authoredPullRequests.isEmpty)
        XCTAssertEqual(state.reviewCount, 0)
        XCTAssertEqual(state.reviewCountAccessibilityLabel, "No pull requests waiting for your review")
    }

    func testChangingRepositoryScopePublishesNewPresentation() async throws {
        let engine = WorkloadEngine(initialState: .empty)
        let stream = await engine.states()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await engine.send(.selectRepositoryScope(.selected(["openai/codex"])))
        let state = try XCTUnwrap(await iterator.next())

        XCTAssertEqual(state.repositoryScope, .selected(["openai/codex"]))
    }

    func testConfirmingMonitoredAccountPersistsOnlyItsLogin() async throws {
        let settingsStore = InMemorySettingsStore()
        let engine = WorkloadEngine(
            accountConnection: TestAccountConnection(),
            settingsStore: settingsStore
        )
        let stream = await engine.states()
        var iterator = stream.makeAsyncIterator()
        _ = await iterator.next()

        await engine.send(.launch)
        _ = await iterator.next()
        let selectionState = try XCTUnwrap(await iterator.next())
        guard case .selectionRequired = selectionState.accountConnection else {
            return XCTFail("Expected account selection")
        }

        await engine.send(.confirmAccount("FranciscoMoretti"))
        _ = await iterator.next()
        let connectedState = try XCTUnwrap(await iterator.next())
        guard case let .connected(login, _) = connectedState.accountConnection else {
            return XCTFail("Expected connected account")
        }

        XCTAssertEqual(login, "FranciscoMoretti")
        XCTAssertEqual(await settingsStore.load().selectedLogin, "FranciscoMoretti")
    }
}

private struct TestAccountConnection: AccountConnection {
    func inspect(selectedLogin: String?) async -> AccountConnectionResult {
        guard let selectedLogin else {
            return .selectionRequired([
                AccountCandidate(login: "FranciscoMoretti", hostname: "github.com"),
                AccountCandidate(login: "francisco-acme", hostname: "github.com"),
            ])
        }
        return .connected(
            ResolvedAccount(
                login: selectedLogin,
                hostname: "github.com",
                scopes: ["read:org", "repo"],
                accessCoverage: AccessCoverage(isComplete: true),
                accessToken: GitHubAccessToken("test-token")
            )
        )
    }
}
