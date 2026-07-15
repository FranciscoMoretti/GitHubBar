import AppKit
import GitHubBarCore
import SwiftUI

struct PullRequestRow: View {
    let pullRequest: PullRequestPresentation
    let showsRepository: Bool

    var body: some View {
        Button {
            NSWorkspace.shared.open(pullRequest.url)
        } label: {
            HStack(alignment: .center, spacing: 7) {
                pullRequestStatus
                VStack(alignment: .leading, spacing: 3) {
                    Text(pullRequest.title)
                        .font(.system(size: 11.5, weight: .medium))
                        .lineLimit(1)
                    HStack(spacing: 7) {
                        Text(metadataLabel)
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 3)
                        if !pullRequest.reviewers.isEmpty {
                            ReviewerRosterView(reviewers: pullRequest.reviewers)
                        }
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button("Copy Link") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(pullRequest.url.absoluteString, forType: .string)
            }
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private var pullRequestStatus: some View {
        ZStack(alignment: .bottomTrailing) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Circle()
                .fill(pullRequest.isDraft ? Color.clear : Color.green)
                .stroke(pullRequest.isDraft ? Color.secondary : Color.clear, lineWidth: 1)
                .frame(width: 6, height: 6)
                .background(Color(nsColor: .windowBackgroundColor), in: Circle())
                .offset(x: 1, y: 1)
        }
        .frame(width: 20, height: 20)
        .accessibilityLabel(pullRequest.isDraft ? "Draft pull request" : "Open pull request")
    }

    private var metadataLabel: String {
        let numberAndTime = "#\(pullRequest.number) · \(pullRequest.updatedAt.formatted(.relative(presentation: .numeric)))"
        return showsRepository
            ? "\(pullRequest.repositoryNameWithOwner) · \(numberAndTime)"
            : numberAndTime
    }

    private var accessibilityLabel: String {
        let status = pullRequest.isDraft ? "Draft pull request" : "Open pull request"
        let reviewerNames = pullRequest.reviewers.map(\.displayName).joined(separator: ", ")
        let reviewers = reviewerNames.isEmpty ? "No reviewers" : "Reviewers: \(reviewerNames)"
        return "\(status), \(pullRequest.repositoryNameWithOwner) number \(pullRequest.number), \(pullRequest.title). \(reviewers)."
    }
}

private struct ReviewerRosterView: View {
    let reviewers: [ReviewerPresentation]

    var body: some View {
        HStack(spacing: -5) {
            ForEach(Array(reviewers.prefix(4))) { reviewer in
                ReviewerAvatar(reviewer: reviewer)
            }
            if reviewers.count > 4 {
                Text("+\(reviewers.count - 4)")
                    .font(.system(size: 7, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .background(.regularMaterial, in: Circle())
                    .overlay { Circle().stroke(.white.opacity(0.15), lineWidth: 1) }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Reviewers: \(reviewers.map(\.displayName).joined(separator: ", "))")
    }
}

private struct ReviewerAvatar: View {
    let reviewer: ReviewerPresentation

    var body: some View {
        Group {
            if let avatarURL = reviewer.avatarURL {
                AsyncImage(url: avatarURL) { phase in
                    if case let .success(image) = phase {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 18, height: 18)
        .clipShape(reviewer.kind == .team ? AnyShape(RoundedRectangle(cornerRadius: 5)) : AnyShape(Circle()))
        .overlay {
            if reviewer.kind == .team {
                RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.55), lineWidth: 1)
            } else {
                Circle().stroke(.black.opacity(0.55), lineWidth: 1)
            }
        }
        .help(reviewer.displayName)
    }

    private var fallback: some View {
        Text(initials)
            .font(.system(size: 6.5, weight: .bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.regularMaterial)
    }

    private var initials: String {
        reviewer.displayName
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .prefix(2)
            .compactMap(\.first)
            .map(String.init)
            .joined()
            .uppercased()
    }
}
