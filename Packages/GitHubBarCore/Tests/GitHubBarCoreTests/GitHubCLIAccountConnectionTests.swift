import Foundation
import XCTest
@testable import GitHubBarCore

final class GitHubCLIAccountConnectionTests: XCTestCase {
    func testMultipleUsableAccountsRequireExplicitSelection() async throws {
        let connection = GitHubCLIAccountConnection(
            executableLocator: TestExecutableLocator(url: URL(fileURLWithPath: "/test/gh")),
            commandRunner: TestAccountCommandRunner()
        )

        let result = await connection.inspect(selectedLogin: nil)

        guard case let .selectionRequired(candidates) = result else {
            return XCTFail("Expected account selection")
        }
        XCTAssertEqual(candidates.map(\.login), ["FranciscoMoretti", "francisco-acme"])
    }

    func testSelectedAccountCredentialIsVerifiedAndRedacted() async throws {
        let connection = GitHubCLIAccountConnection(
            executableLocator: TestExecutableLocator(url: URL(fileURLWithPath: "/test/gh")),
            commandRunner: TestAccountCommandRunner()
        )

        let result = await connection.inspect(selectedLogin: "francisco-acme")

        guard case let .connected(account) = result else {
            return XCTFail("Expected connected account")
        }
        XCTAssertEqual(account.login, "francisco-acme")
        XCTAssertEqual(account.scopes, ["read:org", "repo"])
        XCTAssertTrue(account.accessCoverage.isComplete)
        XCTAssertFalse(String(reflecting: result).contains("secret-test-token"))
    }

    func testMissingExecutableRequiresAccountConnection() async {
        let connection = GitHubCLIAccountConnection(
            executableLocator: TestExecutableLocator(url: nil),
            commandRunner: TestAccountCommandRunner()
        )

        let result = await connection.inspect(selectedLogin: nil)

        guard case .cliMissing = result else {
            return XCTFail("Expected missing CLI result")
        }
    }

    func testNoUsableAccountRequiresConnection() async {
        let connection = GitHubCLIAccountConnection(
            executableLocator: TestExecutableLocator(url: URL(fileURLWithPath: "/test/gh")),
            commandRunner: TestAccountCommandRunner(accountState: "failure")
        )

        let result = await connection.inspect(selectedLogin: nil)

        guard case .connectionRequired = result else {
            return XCTFail("Expected account connection requirement")
        }
    }

    func testMissingRequiredScopeReportsIncompleteAccessCoverage() async {
        let connection = GitHubCLIAccountConnection(
            executableLocator: TestExecutableLocator(url: URL(fileURLWithPath: "/test/gh")),
            commandRunner: TestAccountCommandRunner(scopes: "repo")
        )

        let result = await connection.inspect(selectedLogin: "francisco-acme")

        guard case let .connected(account) = result else {
            return XCTFail("Expected connected account with incomplete access coverage")
        }
        XCTAssertFalse(account.accessCoverage.isComplete)
        XCTAssertEqual(account.accessCoverage.summary, "Missing scopes: read:org")
    }
}

private struct TestExecutableLocator: GitHubCLIExecutableLocating {
    let url: URL?
    func locate() -> URL? { url }
}

private actor TestAccountCommandRunner: CommandRunning {
    private let accountState: String
    private let scopes: String

    init(accountState: String = "success", scopes: String = "read:org, repo") {
        self.accountState = accountState
        self.scopes = scopes
    }

    func run(executableURL: URL, arguments: [String], environment: [String: String]) async -> CommandResult {
        if arguments.starts(with: ["auth", "status"]) {
            return CommandResult(
                exitCode: 0,
                standardOutput: #"{"hosts":{"github.com":[{"state":"#(accountState)","active":true,"host":"github.com","login":"FranciscoMoretti","tokenSource":"keyring","scopes":"#(scopes)","gitProtocol":"https"},{"state":"#(accountState)","active":false,"host":"github.com","login":"francisco-acme","tokenSource":"keyring","scopes":"#(scopes)","gitProtocol":"https"}]}}"#,
                standardError: ""
            )
        }
        if arguments.starts(with: ["auth", "token"]) {
            return CommandResult(exitCode: 0, standardOutput: "secret-test-token\n", standardError: "")
        }
        if arguments.starts(with: ["api", "user"]) {
            XCTAssertEqual(environment["GH_TOKEN"], "secret-test-token")
            return CommandResult(exitCode: 0, standardOutput: "francisco-acme\n", standardError: "")
        }
        return CommandResult(exitCode: 1, standardOutput: "", standardError: "Unexpected command")
    }
}
