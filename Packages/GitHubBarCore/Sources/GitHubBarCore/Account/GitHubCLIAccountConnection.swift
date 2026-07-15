import Foundation

public struct GitHubCLIAccountConnection: AccountConnection {
    private static let hostname = "github.com"
    private static let requiredScopes: Set<String> = ["repo", "read:org"]

    private let executableLocator: any GitHubCLIExecutableLocating
    private let commandRunner: any CommandRunning

    public init(
        executableLocator: any GitHubCLIExecutableLocating = GitHubCLIExecutableLocator(),
        commandRunner: any CommandRunning = ProcessCommandRunner()
    ) {
        self.executableLocator = executableLocator
        self.commandRunner = commandRunner
    }

    public func inspect(selectedLogin: String?) async -> AccountConnectionResult {
        guard let executableURL = executableLocator.locate() else {
            return .cliMissing
        }

        let status = await commandRunner.run(
            executableURL: executableURL,
            arguments: ["auth", "status", "--json", "hosts"],
            environment: [:]
        )
        guard status.exitCode == 0,
              let response = try? JSONDecoder().decode(AuthStatusResponse.self, from: Data(status.standardOutput.utf8)) else {
            return status.exitCode == 0 ? .failed(.invalidStatusResponse) : .authenticationRequired
        }

        let usableAccounts = response.hosts[Self.hostname, default: []]
            .filter { $0.state == "success" }

        guard !usableAccounts.isEmpty else {
            return .authenticationRequired
        }

        let candidates = usableAccounts.map {
            AccountCandidate(login: $0.login, hostname: $0.host)
        }

        let selected: AuthStatusAccount
        if let selectedLogin {
            guard let matchingAccount = usableAccounts.first(where: { $0.login.caseInsensitiveCompare(selectedLogin) == .orderedSame }) else {
                return .selectionRequired(candidates)
            }
            selected = matchingAccount
        } else if usableAccounts.count == 1, let onlyAccount = usableAccounts.first {
            selected = onlyAccount
        } else {
            return .selectionRequired(candidates)
        }

        return await resolve(selected, executableURL: executableURL)
    }

    private func resolve(_ selected: AuthStatusAccount, executableURL: URL) async -> AccountConnectionResult {
        let credential = await commandRunner.run(
            executableURL: executableURL,
            arguments: ["auth", "token", "--hostname", selected.host, "--user", selected.login],
            environment: [:]
        )
        let token = credential.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard credential.exitCode == 0, !token.isEmpty else {
            return .failed(.credentialUnavailable)
        }

        let verification = await commandRunner.run(
            executableURL: executableURL,
            arguments: ["api", "user", "--hostname", selected.host, "--jq", ".login"],
            environment: ["GH_TOKEN": token]
        )
        guard verification.exitCode == 0 else {
            return .failed(.viewerVerificationFailed)
        }

        let verifiedLogin = verification.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard verifiedLogin.caseInsensitiveCompare(selected.login) == .orderedSame else {
            return .failed(.viewerMismatch)
        }

        let scopes = Set(
            selected.scopes
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
        let missingScopes = Self.requiredScopes.subtracting(scopes).sorted()
        let accessCoverage = AccessCoverage(
            isComplete: missingScopes.isEmpty,
            summary: missingScopes.isEmpty ? nil : "Missing scopes: \(missingScopes.joined(separator: ", "))"
        )

        return .connected(
            ResolvedAccount(
                login: verifiedLogin,
                hostname: selected.host,
                scopes: scopes,
                accessCoverage: accessCoverage,
                accessToken: AccountAccessToken(value: token)
            )
        )
    }
}

private struct AuthStatusResponse: Decodable {
    let hosts: [String: [AuthStatusAccount]]
}

private struct AuthStatusAccount: Decodable {
    let state: String
    let active: Bool
    let host: String
    let login: String
    let tokenSource: String
    let scopes: String
    let gitProtocol: String
}
