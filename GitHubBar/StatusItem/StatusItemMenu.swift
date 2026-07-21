import AppKit
import GitHubBarCore
import SwiftUI

@MainActor
extension StatusItemController: NSMenuDelegate {
    func configureStatusMenu() {
        statusMenu.autoenablesItems = false
        statusMenu.delegate = self
        statusItem.menu = statusMenu
        populateStatusMenu()
    }

    func rebuildStatusMenu() {
        guard !isStatusMenuOpen else { return }
        populateStatusMenu()
    }

    public func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        populateStatusMenu()
    }

    public func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        isStatusMenuOpen = true
        installStatusMenuKeyMonitor()
        appModel.send(.setWorkloadSurfaceOpen(true))
    }

    public func menuDidClose(_ menu: NSMenu) {
        guard menu === statusMenu else { return }
        isStatusMenuOpen = false
        removeStatusMenuKeyMonitor()
        highlightedStatusMenuItem = nil
        appModel.send(.setWorkloadSurfaceOpen(false))
        rebuildStatusMenu()
    }

    public func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        (highlightedStatusMenuItem?.view as? StatusMenuHighlighting)?.setHighlighted(false)
        highlightedStatusMenuItem = nil
        guard let item, item.isEnabled, let view = item.view as? StatusMenuHighlighting else { return }
        highlightedStatusMenuItem = item
        view.setHighlighted(true)
    }

    private func populateStatusMenu() {
        statusMenu.removeAllItems()
        statusMenu.addItem(headerItem())
        statusMenu.addItem(repositoryFilterItem())

        if appModel.state.repositoryScope == .pinned,
           appModel.state.pinnedRepositories.isEmpty {
            addNoPinnedRepositoriesState()
            addActions()
            return
        }

        let stacksByPullRequestID = pullRequestStacksByMemberID()

        addSection(
            .needsYourReview,
            pullRequests: appModel.state.needsYourReview,
            stacksByPullRequestID: stacksByPullRequestID
        )
        for authoredSection in AuthoredPullRequestSection.allCases {
            addSection(
                .authored(authoredSection),
                pullRequests: appModel.state.authoredPullRequests.filter {
                    $0.authoredSection == authoredSection
                },
                stacksByPullRequestID: stacksByPullRequestID
            )
        }
        addSection(
            .legacyMyPRs,
            pullRequests: appModel.state.authoredPullRequests.filter {
                $0.authoredSection == nil
            },
            stacksByPullRequestID: stacksByPullRequestID,
            showsWhenEmpty: false
        )

        addActions()
    }

    private func addNoPinnedRepositoriesState() {
        statusMenu.addItem(.separator())

        let empty = NSMenuItem(
            title: "No pinned repositories",
            action: nil,
            keyEquivalent: ""
        )
        empty.isEnabled = false
        setSubtitle("Choose the repositories you care about on this Mac.", on: empty)
        statusMenu.addItem(empty)

        let manage = NSMenuItem(
            title: "Choose repositories in Settings…",
            action: #selector(openSettings),
            keyEquivalent: ""
        )
        manage.target = self
        statusMenu.addItem(manage)
    }

    private func addSection(
        _ section: StatusMenuSection,
        pullRequests: [PullRequestPresentation],
        stacksByPullRequestID: [String: PullRequestStack],
        showsWhenEmpty: Bool = true
    ) {
        guard showsWhenEmpty || !pullRequests.isEmpty else { return }
        statusMenu.addItem(.separator())

        let header = NSMenuItem(
            title: "\(section.title)  \(pullRequests.count)",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        statusMenu.addItem(header)

        let entries = sectionEntries(
            pullRequests: pullRequests,
            stacksByPullRequestID: stacksByPullRequestID
        )
        entries.prefix(Self.pullRequestLimit).forEach { entry in
            statusMenu.addItem(
                pullRequestItem(
                    entry.pullRequest,
                    stackRowContext: entry.stackRowContext
                )
            )
        }
        if entries.count > Self.pullRequestLimit {
            statusMenu.addItem(seeAllItem(for: section))
        }
    }

    private func pullRequestStacksByMemberID() -> [String: PullRequestStack] {
        var pullRequestsByID: [String: PullRequestPresentation] = [:]
        for pullRequest in appModel.state.needsYourReview + appModel.state.authoredPullRequests {
            pullRequestsByID[pullRequest.id] = pullRequest
        }
        var stacksByMemberID: [String: PullRequestStack] = [:]
        for stack in PullRequestStackResolver.stacks(in: Array(pullRequestsByID.values)) {
            for pullRequest in stack.pullRequests {
                stacksByMemberID[pullRequest.id] = stack
            }
        }
        return stacksByMemberID
    }

    private func sectionEntries(
        pullRequests: [PullRequestPresentation],
        stacksByPullRequestID: [String: PullRequestStack]
    ) -> [StatusMenuPullRequestEntry] {
        let sectionPullRequestIDs = Set(pullRequests.map(\.id))
        var representedStackIDs: Set<String> = []
        var entries: [StatusMenuPullRequestEntry] = []

        for pullRequest in pullRequests {
            guard let stack = stacksByPullRequestID[pullRequest.id] else {
                entries.append(
                    StatusMenuPullRequestEntry(
                        pullRequest: pullRequest,
                        stackRowContext: nil
                    )
                )
                continue
            }
            guard representedStackIDs.insert(stack.id).inserted else { continue }
            let sectionMembers = stack.members(withIDs: sectionPullRequestIDs)
            let representative = sectionMembers.first ?? pullRequest
            entries.append(
                StatusMenuPullRequestEntry(
                    pullRequest: representative,
                    stackRowContext: StatusMenuStackRowContext(
                        stack: stack,
                        sectionMemberCount: sectionMembers.count
                    )
                )
            )
        }
        return entries
    }

    private func headerItem() -> NSMenuItem {
        let item = NSMenuItem(title: "GitHubBar", action: nil, keyEquivalent: "")
        item.isEnabled = false
        setSubtitle("\(accountLabel) · \(updatedLabel)", on: item)
        return item
    }

    private func repositoryFilterItem() -> NSMenuItem {
        let item = NSMenuItem()
        let view = StatusMenuRepositoryFilter(
            selection: appModel.state.repositoryScope,
            pinnedCount: appModel.state.pinnedRepositoryIDs.count,
            onSelect: { [weak self] scope in
                self?.selectRepositoryScope(scope)
            },
            onManage: { [weak self] in
                self?.statusMenu.cancelTracking()
                self?.actions.openSettings()
            }
        )
        .frame(width: Self.menuWidth, height: 38)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: Self.menuWidth, height: 38)
        item.view = hosting
        item.isEnabled = true
        return item
    }

    private func pullRequestItem(
        _ pullRequest: PullRequestPresentation,
        stackRowContext: StatusMenuStackRowContext? = nil,
        stackMemberSection: StatusMenuSection? = nil,
        width: CGFloat = StatusItemController.menuWidth,
        keepsMenuOpenAfterOpening: Bool = false
    ) -> NSMenuItem {
        let highlightState = StatusMenuHighlightState()
        let row = StatusMenuPullRequestRow(
            pullRequest: pullRequest,
            highlightState: highlightState,
            stackMembershipCount: stackRowContext.map { context in
                StatusMenuStackMembershipCount(
                    sectionCount: context.sectionMemberCount,
                    totalCount: context.stack.pullRequests.count
                )
            },
            stackMemberSection: stackMemberSection,
            showsDisclosure: stackRowContext != nil
        )
        .environmentObject(avatarImageCache)
        .padding(.horizontal, 11)
        .frame(width: width, height: Self.pullRequestRowHeight)
        let onClick: (() -> Void)? = stackRowContext == nil ? { [weak self] in
            self?.open(
                pullRequest.url,
                keepsMenuOpen: keepsMenuOpenAfterOpening
            )
        } : nil
        let hosting = StatusMenuRowHostingView(
            rootView: row,
            highlightState: highlightState,
            accessibilityLabel: accessibilityLabel(
                for: pullRequest,
                stackRowContext: stackRowContext,
                stackMemberSection: stackMemberSection
            ),
            onClick: onClick
        )
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: width,
            height: Self.pullRequestRowHeight
        )

        let item = NSMenuItem(
            title: "#\(pullRequest.number): \(pullRequest.title)",
            action: nil,
            keyEquivalent: ""
        )
        item.setAccessibilityLabel(
            accessibilityLabel(
                for: pullRequest,
                stackRowContext: stackRowContext,
                stackMemberSection: stackMemberSection
            )
        )
        item.view = hosting
        item.isEnabled = true
        item.toolTip = pullRequestTooltip(for: pullRequest, stack: stackRowContext?.stack)
        if let stackRowContext {
            item.submenu = stackSubmenu(for: stackRowContext.stack)
        } else {
            item.target = self
            item.action = #selector(openURL(_:))
            item.representedObject = StatusMenuURLTarget(
                url: pullRequest.url,
                keepsMenuOpen: keepsMenuOpenAfterOpening
            )
        }
        return item
    }

    private func stackSubmenu(for stack: PullRequestStack) -> NSMenu {
        let submenu = NSMenu()
        submenu.autoenablesItems = false
        submenu.delegate = self

        let header = NSMenuItem(
            title: "Stack · \(stack.pullRequests.count) pull requests",
            action: nil,
            keyEquivalent: ""
        )
        header.isEnabled = false
        submenu.addItem(header)
        for pullRequest in stack.pullRequests {
            submenu.addItem(
                pullRequestItem(
                    pullRequest,
                    stackMemberSection: stackMemberSection(for: pullRequest),
                    width: Self.stackSubmenuWidth,
                    keepsMenuOpenAfterOpening: true
                )
            )
        }
        return submenu
    }

    private func seeAllItem(for section: StatusMenuSection) -> NSMenuItem {
        let item = NSMenuItem(
            title: "See all ↗",
            action: #selector(openURL(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.representedObject = pullRequestSearchURL(for: section) as NSURL
        return item
    }

    private func pullRequestSearchURL(for section: StatusMenuSection) -> URL {
        let login = monitoredAccountLogin ?? "@me"
        var qualifiers = ["is:open", "is:pr"] + section.searchQualifiers.map {
            $0.replacingOccurrences(of: "@me", with: login)
        }
        if appModel.state.repositoryScope == .pinned,
           appModel.state.pinnedRepositoryIDs.count == 1,
           let repositoryID = appModel.state.pinnedRepositoryIDs.first,
           let repository = appModel.state.availableRepositories.first(where: { $0.id == repositoryID }) {
            qualifiers.append("repo:\(repository.nameWithOwner)")
        }
        var components = URLComponents(string: "https://github.com/pulls")!
        components.queryItems = [
            URLQueryItem(name: "q", value: qualifiers.joined(separator: " ")),
        ]
        return components.url!
    }

    private func addActions() {
        statusMenu.addItem(.separator())
        statusMenuActions.forEach { statusMenu.addItem(actionItem($0)) }
        guard let registeredShortcut else { return }
        statusMenu.addItem(.separator())
        statusMenu.addItem(shortcutHintItem(for: registeredShortcut))
    }

    private var statusMenuActions: [StatusMenuActionDescriptor] {
        [
            StatusMenuActionDescriptor(
                title: "Refresh",
                systemImage: "arrow.clockwise",
                shortcut: StatusMenuKeyboardShortcut(keyEquivalent: "r"),
                selector: #selector(refresh)
            ),
            StatusMenuActionDescriptor(
                title: "Settings…",
                systemImage: "gearshape",
                shortcut: StatusMenuKeyboardShortcut(keyEquivalent: ","),
                selector: #selector(openSettings)
            ),
            StatusMenuActionDescriptor(
                title: "About GitHubBar",
                systemImage: "info.circle",
                shortcut: nil,
                selector: #selector(openAbout)
            ),
            StatusMenuActionDescriptor(
                title: "Quit",
                systemImage: "rectangle.portrait.and.arrow.right",
                shortcut: StatusMenuKeyboardShortcut(keyEquivalent: "q"),
                selector: #selector(quit)
            ),
        ]
    }

    private func actionItem(_ action: StatusMenuActionDescriptor) -> NSMenuItem {
        let highlightState = StatusMenuHighlightState()
        let row = StatusMenuActionRow(
            title: action.title,
            systemImage: action.systemImage,
            shortcut: action.shortcut?.displayString,
            highlightState: highlightState
        )
        .padding(.horizontal, 11)
        .frame(width: Self.menuWidth, height: Self.pullRequestRowHeight)
        let hosting = StatusMenuRowHostingView(
            rootView: row,
            highlightState: highlightState,
            accessibilityLabel: action.shortcut.map {
                "\(action.title), \($0.displayString)"
            } ?? action.title
        ) { [weak self] in
            guard let self else { return }
            self.statusMenu.cancelTracking()
            NSApp.sendAction(action.selector, to: self, from: nil)
        }
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: Self.menuWidth,
            height: Self.pullRequestRowHeight
        )

        let item = NSMenuItem(
            title: action.title,
            action: action.selector,
            keyEquivalent: ""
        )
        item.target = self
        item.view = hosting
        return item
    }

    private func shortcutHintItem(for shortcut: GitHubBarShortcut) -> NSMenuItem {
        let item = NSMenuItem()
        let view = StatusMenuShortcutHintRow(
            title: "Shortcut to open GitHubBar",
            shortcut: shortcut.displayString
        )
        .frame(width: Self.menuWidth, height: Self.pullRequestRowHeight)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(
            x: 0,
            y: 0,
            width: Self.menuWidth,
            height: Self.pullRequestRowHeight
        )
        item.view = hosting
        item.isEnabled = false
        item.setAccessibilityLabel("Shortcut to open GitHubBar, \(shortcut.displayString)")
        return item
    }

    private func installStatusMenuKeyMonitor() {
        guard statusMenuKeyMonitor == nil else { return }
        statusMenuKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
            [weak self] event in
            guard let self, self.isStatusMenuOpen else { return event }
            let modifiers = event.modifierFlags.intersection([
                .command,
                .option,
                .control,
                .shift,
            ])
            guard let action = self.statusMenuActions.first(where: {
                $0.shortcut?.matches(event, modifiers: modifiers) == true
            }) else { return event }
            self.statusMenu.cancelTracking()
            NSApp.sendAction(action.selector, to: self, from: nil)
            return nil
        }
    }

    private func removeStatusMenuKeyMonitor() {
        guard let statusMenuKeyMonitor else { return }
        NSEvent.removeMonitor(statusMenuKeyMonitor)
        self.statusMenuKeyMonitor = nil
    }

    private func setSubtitle(_ subtitle: String, on item: NSMenuItem) {
        if #available(macOS 14.4, *) {
            item.subtitle = subtitle
        } else {
            item.toolTip = subtitle
        }
    }

    private func accessibilityLabel(
        for pullRequest: PullRequestPresentation,
        stackRowContext: StatusMenuStackRowContext?,
        stackMemberSection: StatusMenuSection? = nil
    ) -> String {
        let author = pullRequest.author.map { "Author: \($0.displayName). " } ?? ""
        let reviewerNames = pullRequest.reviewers.map(\.displayName).joined(separator: ", ")
        let reviewers = reviewerNames.isEmpty ? "No reviewers" : "Reviewers: \(reviewerNames)"
        let state = pullRequest.isDraft ? "Draft pull request. " : "Open pull request. "
        let stackLabel = stackRowContext.map { context in
            "Stack with \(context.sectionMemberCount) in this section and " +
                "\(context.stack.pullRequests.count) total. "
        } ?? ""
        let section = stackMemberSection.map {
            "\($0.stackMemberDisplay.accessibilityLabel). "
        } ?? ""
        return "\(pullRequest.repositoryNameWithOwner) number \(pullRequest.number), " +
            "\(pullRequest.title). \(state)\(stackLabel)\(section)\(author)\(reviewers)."
    }

    private func stackMemberSection(
        for pullRequest: PullRequestPresentation
    ) -> StatusMenuSection {
        if appModel.state.needsYourReview.contains(where: { $0.id == pullRequest.id }) {
            return .needsYourReview
        }
        if let authoredSection = pullRequest.authoredSection {
            return .authored(authoredSection)
        }
        return .legacyMyPRs
    }

    private func pullRequestTooltip(
        for pullRequest: PullRequestPresentation,
        stack: PullRequestStack?
    ) -> String {
        let pullRequestLabel = "\(pullRequest.repositoryNameWithOwner) · #\(pullRequest.number): \(pullRequest.title)"
        guard let stack else { return pullRequestLabel }
        return "\(pullRequestLabel) · \(stack.pullRequests.count) PR stack"
    }

    private func open(_ url: URL, keepsMenuOpen: Bool = false) {
        guard keepsMenuOpen else {
            statusMenu.cancelTracking()
            NSWorkspace.shared.open(url)
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        NSWorkspace.shared.open(url, configuration: configuration) { _, _ in }
    }

    private var accountLabel: String {
        if let login = monitoredAccountLogin {
            return "@\(login)"
        }
        return "GitHub CLI"
    }

    private var monitoredAccountLogin: String? {
        if case let .connected(login, _) = appModel.state.accountConnection {
            return login
        }
        return nil
    }

    private var updatedLabel: String {
        if appModel.state.isRefreshing { return "Refreshing…" }
        guard let lastUpdatedAt = appModel.state.lastUpdatedAt else { return "Ready" }
        return "Updated \(lastUpdatedAt.formatted(.relative(presentation: .named)))"
    }

    private func selectRepositoryScope(_ scope: RepositoryScope) {
        guard scope != appModel.state.repositoryScope else { return }
        pendingRepositoryScope = scope
        appModel.send(.selectRepositoryScope(scope))
    }

    @objc private func openURL(_ sender: NSMenuItem) {
        if let target = sender.representedObject as? StatusMenuURLTarget {
            open(target.url, keepsMenuOpen: target.keepsMenuOpen)
        } else if let url = sender.representedObject as? URL {
            open(url)
        }
    }

    @objc private func refresh() {
        appModel.send(.manualRefresh)
    }

    @objc private func openSettings() {
        actions.openSettings()
    }

    @objc private func openAbout() {
        actions.openAbout()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private static let menuWidth: CGFloat = 560
    private static let stackSubmenuWidth: CGFloat = 440
    private static let pullRequestRowHeight: CGFloat = 25
    private static let pullRequestLimit = 5
}

extension StatusItemController {
    func updateStatusMenu(for state: AppPresentationState) {
        guard let pendingRepositoryScope,
              pendingRepositoryScope == state.repositoryScope,
              isStatusMenuOpen else {
            rebuildStatusMenu()
            return
        }
        self.pendingRepositoryScope = nil
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isStatusMenuOpen else { return }
            self.populateStatusMenu()
        }
    }
}

private enum StatusMenuSection {
    case needsYourReview
    case authored(AuthoredPullRequestSection)
    case legacyMyPRs

    var title: String {
        metadata.title
    }

    var searchQualifiers: [String] {
        metadata.searchQualifiers
    }

    var stackMemberDisplay: StatusMenuStackMemberSectionDisplay {
        metadata.stackMemberDisplay
    }

    private var metadata: StatusMenuSectionMetadata {
        switch self {
        case .needsYourReview:
            StatusMenuSectionMetadata(
                title: "Needs your review",
                searchQualifiers: ["review-requested:@me", "-is:draft"],
                stackMemberDisplay: StatusMenuStackMemberSectionDisplay(
                    title: "Review",
                    accessibilityLabel: "Review-request status: Needs your review",
                    color: .accentColor
                )
            )
        case .authored(.returnedToYou):
            StatusMenuSectionMetadata(
                title: "Returned to you",
                searchQualifiers: ["author:@me", "review:changes_requested", "-is:draft"],
                stackMemberDisplay: StatusMenuStackMemberSectionDisplay(
                    title: "Returned",
                    accessibilityLabel: "Authored workflow section: Returned to you",
                    color: .orange
                )
            )
        case .authored(.needsReviewers):
            StatusMenuSectionMetadata(
                title: "Needs reviewers",
                searchQualifiers: ["author:@me", "review:none", "-is:draft"],
                stackMemberDisplay: StatusMenuStackMemberSectionDisplay(
                    title: "Needs reviewers",
                    accessibilityLabel: "Authored workflow section: Needs reviewers",
                    color: .secondary
                )
            )
        case .authored(.waitingForReviewers):
            StatusMenuSectionMetadata(
                title: "Waiting for reviewers",
                searchQualifiers: ["author:@me", "review:required", "-is:draft"],
                stackMemberDisplay: StatusMenuStackMemberSectionDisplay(
                    title: "Waiting",
                    accessibilityLabel: "Authored workflow section: Waiting for reviewers",
                    color: .secondary
                )
            )
        case .authored(.approved):
            StatusMenuSectionMetadata(
                title: "Approved",
                searchQualifiers: ["author:@me", "review:approved", "-is:draft"],
                stackMemberDisplay: StatusMenuStackMemberSectionDisplay(
                    title: "Approved",
                    accessibilityLabel: "Authored workflow section: Approved",
                    color: .green
                )
            )
        case .authored(.drafts):
            StatusMenuSectionMetadata(
                title: "Drafts",
                searchQualifiers: ["author:@me", "is:draft"],
                stackMemberDisplay: StatusMenuStackMemberSectionDisplay(
                    title: "Draft",
                    accessibilityLabel: "Authored workflow section: Drafts",
                    color: .secondary
                )
            )
        case .legacyMyPRs:
            StatusMenuSectionMetadata(
                title: "My PRs",
                searchQualifiers: ["author:@me"],
                stackMemberDisplay: StatusMenuStackMemberSectionDisplay(
                    title: "My PR",
                    accessibilityLabel: "Authored pull request without a known Authored workflow section",
                    color: .secondary
                )
            )
        }
    }
}

private struct StatusMenuSectionMetadata {
    let title: String
    let searchQualifiers: [String]
    let stackMemberDisplay: StatusMenuStackMemberSectionDisplay
}

private struct StatusMenuPullRequestEntry {
    let pullRequest: PullRequestPresentation
    let stackRowContext: StatusMenuStackRowContext?
}

private struct StatusMenuStackRowContext {
    let stack: PullRequestStack
    let sectionMemberCount: Int
}

private struct StatusMenuStackMembershipCount {
    let sectionCount: Int
    let totalCount: Int
}

private struct StatusMenuStackMemberSectionDisplay {
    let title: String
    let accessibilityLabel: String
    let color: Color
}

private struct StatusMenuActionDescriptor {
    let title: String
    let systemImage: String
    let shortcut: StatusMenuKeyboardShortcut?
    let selector: Selector
}

private struct StatusMenuKeyboardShortcut {
    let keyEquivalent: String
    let modifiers: NSEvent.ModifierFlags

    init(
        keyEquivalent: String,
        modifiers: NSEvent.ModifierFlags = .command
    ) {
        self.keyEquivalent = keyEquivalent
        self.modifiers = modifiers
    }

    var displayString: String {
        modifiers.shortcutDisplayString(for: keyEquivalent)
    }

    func matches(_ event: NSEvent, modifiers eventModifiers: NSEvent.ModifierFlags) -> Bool {
        eventModifiers == modifiers &&
            event.charactersIgnoringModifiers?.lowercased() == keyEquivalent.lowercased()
    }
}

private final class StatusMenuURLTarget: NSObject {
    let url: URL
    let keepsMenuOpen: Bool

    init(url: URL, keepsMenuOpen: Bool) {
        self.url = url
        self.keepsMenuOpen = keepsMenuOpen
    }
}

@MainActor
private protocol StatusMenuHighlighting: AnyObject {
    func setHighlighted(_ highlighted: Bool)
}

@MainActor
private final class StatusMenuHighlightState: ObservableObject {
    @Published var isHighlighted = false
}

@MainActor
private final class StatusMenuRowHostingView<Content: View>: NSHostingView<Content>, StatusMenuHighlighting {
    private let highlightState: StatusMenuHighlightState
    private let rowAccessibilityLabel: String
    private let onClick: (() -> Void)?

    init(
        rootView: Content,
        highlightState: StatusMenuHighlightState,
        accessibilityLabel: String,
        onClick: (() -> Void)?
    ) {
        self.highlightState = highlightState
        rowAccessibilityLabel = accessibilityLabel
        self.onClick = onClick
        super.init(rootView: rootView)
    }

    required init(rootView: Content) {
        highlightState = StatusMenuHighlightState()
        rowAccessibilityLabel = "Pull request"
        onClick = nil
        super.init(rootView: rootView)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        bounds.contains(point) ? self : nil
    }

    override func mouseUp(with event: NSEvent) {
        guard event.type == .leftMouseUp, let onClick else {
            super.mouseUp(with: event)
            return
        }
        onClick()
    }

    override func accessibilityRole() -> NSAccessibility.Role? {
        onClick == nil ? nil : .button
    }

    override func accessibilityLabel() -> String? {
        onClick == nil ? nil : rowAccessibilityLabel
    }

    override func isAccessibilityElement() -> Bool {
        onClick != nil
    }

    override func accessibilityPerformPress() -> Bool {
        guard let onClick else { return false }
        onClick()
        return true
    }

    func setHighlighted(_ highlighted: Bool) {
        highlightState.isHighlighted = highlighted
    }
}

private struct StatusMenuPullRequestRow: View {
    let pullRequest: PullRequestPresentation
    @ObservedObject var highlightState: StatusMenuHighlightState
    let stackMembershipCount: StatusMenuStackMembershipCount?
    let stackMemberSection: StatusMenuSection?
    let showsDisclosure: Bool

    var body: some View {
        HStack(spacing: 7) {
            StatusMenuAuthorAvatar(author: pullRequest.author)
            Text("#\(String(pullRequest.number)): \(pullRequest.title)")
                .font(.system(size: 12))
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)
            Spacer(minLength: 4)
            if let stackMemberSection {
                let display = stackMemberSection.stackMemberDisplay
                Text(display.title)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(
                        highlightState.isHighlighted ? Color.white.opacity(0.9) : display.color
                    )
                    .lineLimit(1)
            }
            if let stackMembershipCount {
                Text("\(stackMembershipCount.sectionCount)/\(stackMembershipCount.totalCount)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(highlightState.isHighlighted ? Color.white : Color.accentColor)
                    .padding(.horizontal, 5)
                    .frame(height: 17)
                    .background(
                        (highlightState.isHighlighted ? Color.white.opacity(0.2) : Color.accentColor.opacity(0.15)),
                        in: Capsule()
                    )
                    .overlay {
                        Capsule()
                            .stroke(
                                highlightState.isHighlighted ? Color.white.opacity(0.3) : Color.accentColor.opacity(0.35),
                                lineWidth: 0.5
                            )
                    }
            }
            if !pullRequest.reviewers.isEmpty {
                ReviewerRosterView(reviewers: pullRequest.reviewers)
            }
            if showsDisclosure {
                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(highlightState.isHighlighted ? Color.white : Color.secondary)
            }
        }
        .padding(.horizontal, 7)
        .foregroundStyle(highlightState.isHighlighted ? Color.white : Color.primary)
        .background {
            if highlightState.isHighlighted {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .environment(\.colorScheme, .dark)
    }
}

private struct StatusMenuActionRow: View {
    let title: String
    let systemImage: String
    let shortcut: String?
    @ObservedObject var highlightState: StatusMenuHighlightState

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 11))
                .frame(width: 14)
                .foregroundStyle(highlightState.isHighlighted ? Color.white : Color.secondary)
            Text(title)
                .font(.system(size: 12))
            Spacer(minLength: 8)
            if let shortcut {
                Text(shortcut)
                    .font(.system(size: 11))
                    .foregroundStyle(highlightState.isHighlighted ? Color.white.opacity(0.8) : Color.secondary)
            }
        }
        .padding(.horizontal, 7)
        .foregroundStyle(highlightState.isHighlighted ? Color.white : Color.primary)
        .background {
            if highlightState.isHighlighted {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
        .environment(\.colorScheme, .dark)
    }
}

private struct StatusMenuShortcutHintRow: View {
    let title: String
    let shortcut: String

    var body: some View {
        HStack {
            Text(title)
            Spacer()
            Text(shortcut)
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 18)
        .environment(\.colorScheme, .dark)
    }
}

private struct StatusMenuAuthorAvatar: View {
    let author: PullRequestAuthorPresentation?

    var body: some View {
        IdentityAvatarImage(
            displayName: author?.displayName,
            avatarURL: author?.avatarURL
        )
        .frame(width: 16, height: 16)
        .clipShape(Circle())
        .overlay { Circle().stroke(.black.opacity(0.45), lineWidth: 1) }
        .help(author.map { "Author: \($0.displayName)" } ?? "Author unavailable")
        .accessibilityHidden(true)
    }
}

private struct StatusMenuRepositoryFilter: View {
    let selection: RepositoryScope
    let pinnedCount: Int
    let onSelect: (RepositoryScope) -> Void
    let onManage: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 2) {
                filterButton("All", filter: .all)
                filterButton("Pinned \(pinnedCount)", filter: .pinned)
            }
            .padding(3)
            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))

            Spacer()

            Button(action: onManage) {
                Label("Manage pins", systemImage: "slider.horizontal.3")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help("Manage pinned repositories in Settings")
        }
        .padding(.horizontal, 11)
        .environment(\.colorScheme, .dark)
    }

    private func filterButton(_ title: String, filter: RepositoryScope) -> some View {
        Button {
            onSelect(filter)
        } label: {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(selection == filter ? Color.primary : Color.secondary)
                .frame(minWidth: 78)
                .padding(.vertical, 5)
                .background {
                    if selection == filter {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(nsColor: .selectedControlColor).opacity(0.75))
                    }
                }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
