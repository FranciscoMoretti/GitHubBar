import AppKit
import GitHubBarCore
import SwiftUI

struct AccountConnectionView: View {
    let accountConnection: AccountConnectionPresentation
    let send: (WorkloadCommand) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 24)
            content
                .padding(.horizontal, 30)
            Spacer(minLength: 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var content: some View {
        switch accountConnection {
        case .notChecked, .checking:
            ProgressView()
                .controlSize(.small)
                .padding(.bottom, 13)
            Text("Checking GitHub CLI")
                .connectionTitle()
            Text("GitHubBar is looking for connected GitHub.com accounts on this Mac.")
                .connectionDetail()
        case let .connectionRequired(problem):
            requiredContent(problem)
        case let .selectionRequired(candidates):
            Image(systemName: "person.2")
                .connectionIcon()
            Text("Choose the account to monitor")
                .connectionTitle()
            Text("GitHubBar found multiple connected GitHub.com accounts. Choose one for this Mac.")
                .connectionDetail()
            VStack(spacing: 6) {
                ForEach(candidates) { candidate in
                    Button {
                        send(.confirmAccount(candidate.login))
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "person.crop.circle")
                                .foregroundStyle(.secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("@\(candidate.login)")
                                    .font(.system(size: 10, weight: .semibold))
                                Text(candidate.hostname)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.tertiary)
                        }
                        .padding(9)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 7))
                    .overlay { RoundedRectangle(cornerRadius: 7).stroke(.white.opacity(0.1)) }
                    .accessibilityLabel("Monitor @\(candidate.login) on \(candidate.hostname)")
                }
            }
            .padding(.top, 14)
            Text("GitHubBar will not change GitHub CLI’s active account.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
                .padding(.top, 10)
        case .connected:
            EmptyView()
        }
    }

    @ViewBuilder
    private func requiredContent(_ problem: AccountConnectionProblem) -> some View {
        Image(systemName: problem == .cliMissing ? "terminal" : "person.crop.circle.badge.exclamationmark")
            .connectionIcon()
        Text(requiredTitle(problem))
            .connectionTitle()
        Text(requiredDetail(problem))
            .connectionDetail()

        if let command = recoveryCommand(problem) {
            Text(command)
                .font(.system(size: 9.5, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(9)
                .background(.black.opacity(0.2), in: RoundedRectangle(cornerRadius: 6))
                .overlay { RoundedRectangle(cornerRadius: 6).stroke(.white.opacity(0.1)) }
                .padding(.top, 14)
                .accessibilityLabel("Recovery command: \(command)")
        }

        HStack(spacing: 7) {
            if problem == .cliMissing || problem == .connectionRequired {
                Button("Setup guide") { openSetupGuide(problem) }
            }
            Button("Check again") { send(.recheckAccountConnection) }
                .buttonStyle(.borderedProminent)
        }
        .controlSize(.small)
        .padding(.top, 13)
    }

    private func requiredTitle(_ problem: AccountConnectionProblem) -> String {
        switch problem {
        case .cliMissing: "Install GitHub CLI"
        case .connectionRequired: "Connect GitHub CLI"
        case .incompleteAccess: "Review GitHub access"
        case .unavailable: "GitHub CLI could not be verified"
        }
    }

    private func requiredDetail(_ problem: AccountConnectionProblem) -> String {
        switch problem {
        case .cliMissing:
            "GitHubBar uses an existing GitHub CLI session, but gh was not found on this Mac."
        case .connectionRequired:
            "GitHub CLI is installed, but no usable GitHub.com account connection is available."
        case .incompleteAccess:
            "The account connection does not currently cover all repositories needed by GitHubBar."
        case .unavailable:
            "The selected account could not be verified. Your credential was not stored by GitHubBar."
        }
    }

    private func recoveryCommand(_ problem: AccountConnectionProblem) -> String? {
        switch problem {
        case .cliMissing: "brew install gh"
        case .connectionRequired: "gh auth login --hostname github.com"
        case .incompleteAccess, .unavailable: nil
        }
    }

    private func openSetupGuide(_ problem: AccountConnectionProblem) {
        let urlString = problem == .cliMissing
            ? "https://cli.github.com/"
            : "https://cli.github.com/manual/gh_auth_login"
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}

private extension View {
    func connectionIcon() -> some View {
        font(.system(size: 20))
            .foregroundStyle(.secondary)
            .frame(width: 38, height: 38)
            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 10))
            .overlay { RoundedRectangle(cornerRadius: 10).stroke(.white.opacity(0.14)) }
            .padding(.bottom, 13)
    }

    func connectionTitle() -> some View {
        font(.system(size: 13, weight: .semibold))
    }

    func connectionDetail() -> some View {
        font(.system(size: 10))
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .padding(.top, 7)
    }
}
