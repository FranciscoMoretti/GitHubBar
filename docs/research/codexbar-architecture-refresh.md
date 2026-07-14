# CodexBar architecture and refresh mechanics for GitHubBar

## Scope and source baseline

This note answers one question: **which parts of CodexBar should GitHubBar copy, adapt, or deliberately leave behind?** It is a source audit, not an implementation plan and not an audit of GitHub's API.

The audit inspected `steipete/CodexBar` at commit [`b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8`](https://github.com/steipete/CodexBar/tree/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8) (2026-07-13). All upstream links below are pinned to that commit. The primary sources were the repository's Swift source, tests, package manifest, first-party architecture/refresh documentation, packaging script, and license.

## Answer

GitHubBar should reuse CodexBar's **shape**, not its implementation wholesale:

- Copy the native agent-app shell: `LSUIElement`, `NSStatusItem`, a SwiftUI settings scene, an injected app delegate/controller seam, Swift Observation, and Swift 6 strict concurrency.
- Adapt the refresh contract almost directly: cached-first startup, manual/fixed/adaptive modes, a pure adaptive policy, one cancelable timer, one single-flight refresh, interaction that can advance but never postpone an adaptive tick, and stale data retained on failure.
- Replace CodexBar's `NSMenu` presentation with the already-chosen custom SwiftUI popover. GitHubBar needs a scrollable `LazyVStack`, collapsible queues, and hundreds of rows; CodexBar's hybrid `NSMenu`/`NSHostingView` machinery is the wrong foundation for that surface.
- Keep GitHubBar's first architecture small: an app/UI target plus a core target. Do not import CodexBar's provider registry, CLI, widgets, replay tools, account coordinators, dashboard scraping, charts, or multi-status-item system.

### Copy/adapt/leave-behind matrix

| Area | Decision for GitHubBar | Why |
|---|---|---|
| App lifecycle | **Adapt closely** | CodexBar cleanly creates state in `App.init`, passes explicit dependencies to `AppDelegate`, creates the status controller after launch, and exposes a native Settings scene. |
| Status item | **Adapt closely** | `NSStatusItem` gives native menu-bar placement, accessibility, visibility, and an anchor for GitHubBar's popover. |
| Content presentation | **Do not copy** | CodexBar uses persistent `NSMenu` instances with embedded SwiftUI views and extensive rebuild, measurement, highlight, and menu-tracking logic. GitHubBar needs a normal scrollable SwiftUI view hierarchy. |
| Observable state | **Copy the actor/observation boundary; split the store** | `@MainActor @Observable` is a good UI-state boundary, but CodexBar's `UsageStore` has become a broad feature hub. GitHubBar should keep network, cache, scheduling, and presentation derivation behind protocols/types rather than one growing store. |
| Settings | **Adapt closely, at smaller scale** | Injected `UserDefaults`, an explicit defaults-state value, and setters that persist and publish a background-work revision are simple and well tested. Credentials stay outside defaults. |
| Fixed/adaptive refresh | **Adapt closely** | The policy is deterministic, bounded, privacy-preserving, cancellation-aware, and independent of fetch details. |
| Refresh-on-open | **Adapt the mechanism, not CodexBar's default policy** | Open cached content synchronously, debounce asynchronous work, coalesce with an in-flight refresh, and do not reset the periodic clock. GitHubBar's accepted product decision is to refresh on each sustained popover open; CodexBar normally refreshes only missing/failed visible data unless an opt-in is enabled. |
| Stale/error behavior | **Adapt the retain-last-success rule; make state more explicit** | CodexBar preserves prior snapshots for transient failures, but often represents staleness as an error string. GitHubBar will also have partial/paginated results and needs a typed freshness state. |
| Persistence | **Adapt the file-store pattern** | Versioned payloads, account-identity validation, atomic writes, `0600`, and best-effort failure are appropriate for a local PR cache. Skip widget/app-group persistence. |
| Tests | **Copy the seams and test categories** | Pure policy tables, fake sleep/clock boundaries, injected defaults, controller factories, fetch overrides, and explicit menu-open contracts are strong patterns. Avoid reproducing CodexBar's large `NSMenu` regression surface. |

## Recommended GitHubBar architecture

### 1. Minimal target boundary

CodexBar targets macOS 14, enables Swift strict concurrency, and separates a cross-platform/core library from the macOS executable; it also isolates the pure adaptive decision table in a dependency-free target ([`Package.swift:21-26`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Package.swift#L21-L26), [`Package.swift:64-105`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Package.swift#L64-L105), [`Package.swift:143-197`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Package.swift#L143-L197)). GitHubBar should use the same broad boundary with fewer products:

```text
GitHubBarCore
  PR domain models and next-move classifier
  GitHubFetching protocol and transport-neutral request/results
  cache payload/store protocol
  pure refresh policy and refresh-plan decisions

GitHubBar
  app lifecycle and NSStatusItem/NSPopover controller
  PullRequestStore (@MainActor @Observable)
  SettingsStore (@MainActor @Observable)
  SwiftUI popover and Settings UI
  concrete GitHub client, Keychain adapter, file cache

GitHubBarCoreTests / GitHubBarTests
```

There is no current MVP reason to create CodexBar-equivalent CLI, widget, replay executable, helper process, or provider plugin targets.

### 2. App shell and menu-bar surface

CodexBar's `@main` app constructs `SettingsStore` and `UsageStore`, injects them into its delegate, and supplies them to a native SwiftUI Settings scene ([`CodexbarApp.swift:9-104`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/CodexbarApp.swift#L9-L104)). Its delegate defers status-controller creation until `applicationDidFinishLaunching`, owns termination cleanup, and makes controller construction replaceable through a factory ([`CodexbarApp.swift:338-421`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/CodexbarApp.swift#L338-L421), [`CodexbarApp.swift:496-539`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/CodexbarApp.swift#L496-L539)). The packaged app sets `LSUIElement` so it has no Dock icon ([`package_app.sh:256-270`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Scripts/package_app.sh#L256-L270)).

GitHubBar should preserve that lifecycle but change the controller's presentation:

1. `GitHubBarApp` constructs `SettingsStore`, `PullRequestStore`, and concrete adapters once.
2. `AppDelegate` creates one `StatusItemController` after application launch.
3. `StatusItemController` creates one variable-width `NSStatusItem`, sets an accessibility identifier/title, and makes its button toggle a custom `NSPopover` anchored to the button.
4. The popover hosts a regular SwiftUI `PullRequestPopoverView` with `ScrollView`/`LazyVStack`, collapsible sections, keyboard navigation, and row quick actions.
5. A SwiftUI `Settings` scene remains the only ordinary window.

The status-item creation itself is reusable: CodexBar assigns a stable autosave name and configures crisp image scaling and accessibility ([`StatusItemController.swift:302-325`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController.swift#L302-L325)). Its controller protocol/factory is also worth copying as a testing seam ([`StatusItemController.swift:8-18`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController.swift#L8-L18), [`StatusItemController.swift:87-120`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController.swift#L87-L120)).

Do **not** carry over `statusItem.menu = NSMenu`. CodexBar creates persistent menus and attaches them directly to status items ([`StatusItemController.swift:832-870`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController.swift#L832-L870)). Embedding interactive SwiftUI cards then requires custom intrinsic-height measurement, hosting-view reuse, hit forwarding, and menu highlight coordination ([`StatusItemController+MenuPresentation.swift:86-180`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController%2BMenuPresentation.swift#L86-L180), [`StatusItemController+MenuCardItems.swift:26-177`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController%2BMenuCardItems.swift#L26-L177)). That complexity buys native-menu behavior but works against a long, virtualized PR list.

### 3. Observable state and side-effect seams

CodexBar keeps UI state in a `@MainActor @Observable` store and marks service dependencies and task handles with `@ObservationIgnored` ([`UsageStore.swift:122-192`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L122-L192), [`UsageStore.swift:257-356`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L257-L356)). It starts background work only after its injected dependencies and optional persisted snapshots are initialized ([`UsageStore.swift:358-445`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L358-L445)).

Use the same ownership rule for `PullRequestStore`, but keep it narrow:

```swift
@MainActor @Observable
final class PullRequestStore {
    private(set) var snapshot: PullRequestSnapshot?
    private(set) var refreshState: RefreshState
    private(set) var lastSuccessfulRefreshAt: Date?

    @ObservationIgnored let client: any GitHubFetching
    @ObservationIgnored let cache: any PullRequestCache
    @ObservationIgnored let scheduler: RefreshScheduler
}
```

The concrete GitHub client performs network/decode work off the main actor and returns immutable `Sendable` values. The store alone publishes UI state on the main actor. A generation/account key must guard publication so a result started under an old token or identity cannot overwrite state after authentication changes. CodexBar uses per-request generations and settings revisions for exactly this stale-publication problem ([`ProviderRefreshCoordinator.swift:23-54`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/ProviderRefreshCoordinator.swift#L23-L54), [`UsageStore+Refresh.swift:114-170`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore%2BRefresh.swift#L114-L170)).

GitHubBar has one service/account in MVP, so it should use one single-flight refresh task rather than CodexBar's provider-keyed coordinator. Timer, popover-open, startup, and manual callers should join that task. A new refresh may replace the old task only when the authentication/scope generation changes; older results must be rejected even if cancellation arrives late.

### 4. Settings and credentials

CodexBar's useful settings pattern is:

- `@MainActor @Observable SettingsStore` with injectable `UserDefaults` ([`SettingsStore.swift:175-240`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/SettingsStore.swift#L175-L240));
- one explicit value holding loaded defaults ([`SettingsStoreState.swift:3-68`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/SettingsStoreState.swift#L3-L68));
- a stable raw-value enum for refresh choices, where manual/adaptive deliberately have no fixed seconds ([`SettingsStore.swift:6-46`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/SettingsStore.swift#L6-L46));
- defaults loaded with an explicit 5-minute fallback and refresh-on-open disabled by default ([`SettingsStore.swift:399-408`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/SettingsStore.swift#L399-L408)); and
- setters that synchronously persist and bump a background-work revision when scheduling inputs change ([`SettingsStore+Defaults.swift:8-29`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/SettingsStore%2BDefaults.swift#L8-L29)).

Adapt that for refresh frequency, launch at login, notifications, organization/repository mutes, display density, and recently-completed retention. Store the GitHub credential in Keychain, never `UserDefaults`. Large or frequently changing local triage data (snoozes and per-PR local state) belongs beside the application cache, not in an ever-growing defaults dictionary.

Do not copy CodexBar's JSON provider configuration, provider-detection migrations, app-group bridging, or many per-provider secret stores. They solve a multi-provider/CLI/widget product, not GitHubBar's single authenticated identity.

## Refresh contract to carry forward

### The CodexBar mechanism

CodexBar exposes manual, 1-, 2-, 5-, 15-, and 30-minute fixed modes plus adaptive mode ([`SettingsStore.swift:6-32`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/SettingsStore.swift#L6-L32)). On startup it launches one immediate refresh and then starts the timer ([`UsageStore.swift:427-445`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L427-L445)). Changing relevant settings restarts the timer and refreshes through the same store path ([`UsageStore.swift:59-79`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L59-L79)).

`startTimer` owns exactly one cancelable task. Manual mode owns no timer. Fixed mode is anchored to scheduled tick time and skips missed ticks rather than overlapping catch-up work. Adaptive mode recomputes after each tick from live inputs ([`UsageStore.swift:760-805`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L760-L805), [`UsageStore+AdaptiveRefresh.swift:37-79`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore%2BAdaptiveRefresh.swift#L37-L79)). The store's refresh guard prevents a timer tick from overlapping an active batch ([`UsageStore.swift:603-643`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L603-L643)).

The adaptive policy is a pure function. First match wins:

| Input | Next delay | Reason |
|---|---:|---|
| Low Power Mode or serious/critical thermal pressure | 30 min | `constrained` |
| Popover/menu opened no more than 5 min ago | 2 min | `recentInteraction` |
| Opened more than 5 min and no more than 1 h ago | 5 min | `warm` |
| Opened more than 1 h but less than 4 h ago | 15 min | `idle` |
| Never opened or opened at least 4 h ago | 30 min | `longIdle` |

The thresholds and delays live in one dependency-free core, including deliberate handling of future/clock-adjusted timestamps ([`AdaptiveRefreshPolicyCore.swift:31-86`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/AdaptiveRefreshCore/AdaptiveRefreshPolicyCore.swift#L31-L86)). A small macOS adapter maps `.serious`/`.critical` thermal state to the core's constrained input ([`AdaptiveRefreshPolicy.swift:4-34`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/AdaptiveRefreshPolicy.swift#L4-L34)). The last-open signal is in memory only; an interaction can cancel/restart an adaptive sleep only when the new candidate is earlier, never to postpone an earlier tick ([`UsageStore.swift:288-292`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L288-L292), [`UsageStore.swift:1649-1665`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L1649-L1665)). Logs contain only reason and delay, not identity or response data ([`UsageStore+AdaptiveRefresh.swift:81-101`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore%2BAdaptiveRefresh.swift#L81-L101)).

### GitHubBar's adapted behavior

Use that policy table and scheduling contract initially, with `lastPopoverOpenAt` replacing `lastMenuOpenAt`. Keep 5 minutes as the default and Adaptive opt-in until real GitHubBar measurements justify another default.

The full lifecycle should be:

1. **Launch:** hydrate the last successful snapshot synchronously or before first presentation; publish it immediately; start one asynchronous network refresh; start the selected recurring schedule.
2. **Popover open:** display the current snapshot immediately. Record `lastPopoverOpenAt`. If Adaptive has a later pending tick, advance it to the recent-interaction deadline. Independently schedule the accepted refresh-on-open request after a short debounce while the popover remains open. This request does not reset the recurring timer.
3. **Manual refresh:** request the same refresh operation immediately with a user-initiated reason. If work is already in flight, join it rather than issue a duplicate request. Keep row geometry/content visible and show a persistent spinner/last-updated state.
4. **Fixed tick:** refresh on scheduled-time cadence; skip missed ticks after sleep/wake or a slow request.
5. **Adaptive tick:** compute a fresh delay after each completed/skipped tick, sleep, then use the same single-flight refresh path.
6. **Setting/auth change:** cancel and replace the pending timer. Increment the publication generation. Authentication/scope changes invalidate in-flight publication and cached identity before starting new work.

CodexBar's menu-open path is valuable for mechanism: it records interaction without synchronous fetch, renders current content, waits 1.2 seconds, verifies that the menu is still open, computes a pure refresh plan, and coalesces with in-flight provider work ([`StatusItemController+Menu.swift:66-153`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController%2BMenu.swift#L66-L153), [`StatusItemController+Menu.swift:1130-1201`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController%2BMenu.swift#L1130-L1201)). GitHubBar should use the same cached-first/debounced/single-flight mechanics, but its plan should refresh the one GitHub scope on every sustained open because that product decision is already accepted. Whether the debounce remains 1.2 seconds should be validated in the prototype; its contract matters more than its exact value.

Do not introduce scheduler-level exponential failure backoff merely because adaptive mode exists. CodexBar deliberately keeps timing policy independent from provider failures; GitHubBar's GitHub API investigation should separately define rate-limit reset handling, authentication failures, transport retry, and partial-page retry.

## Stale, partial, and error state

CodexBar keeps snapshots and errors separately. A provider is considered stale when it has an error, so the prior snapshot can remain visible while the icon/menu indicates failure ([`UsageStore.swift:458-463`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L458-L463), [`UsageStore.swift:535-549`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L535-L549)). On success it atomically replaces the snapshot and clears the error ([`UsageStore+Refresh.swift:478-546`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore%2BRefresh.swift#L478-L546)). Its generic failure gate suppresses the first transient failure when prior data exists, and failure application preserves prior data for selected transport errors ([`UsageStoreSupport.swift:82-100`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStoreSupport.swift#L82-L100), [`UsageStore+Refresh.swift:930-1014`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore%2BRefresh.swift#L930-L1014)).

GitHubBar should make this richer and typed because a high-volume GitHub result can be complete, old, or partially complete:

```swift
enum RefreshState: Equatable, Sendable {
    case empty
    case refreshing(previous: SnapshotMetadata?)
    case fresh(SnapshotMetadata)
    case stale(SnapshotMetadata, RefreshFailure)
    case partial(SnapshotMetadata, [PartialFailure])
    case failed(RefreshFailure) // only when no usable snapshot exists
}
```

Rules:

- Never erase the last successful PR rows because a refresh failed.
- Always show the timestamp of the data currently rendered.
- A first transient transport failure may avoid an attention-grabbing menu-bar error, but the open popover should still say that refresh failed and cached data is being shown.
- Authentication/revocation and account mismatch fail closed and surface immediately; they must not continue presenting another identity's cache as current.
- Partial page/repository failures retain successful data and name the incomplete scope. They are not equivalent to a total failure.
- The menu-bar actionable count is derived from the rendered snapshot. When stale, keep the count but visually mark the icon/state as stale; never turn a failure into a reassuring zero.

This retains CodexBar's graceful degradation without coupling GitHubBar to `errors: [Provider: String]` or provider-specific failure branches.

## Persistence to carry forward

CodexBar's general-purpose usage state is mostly in memory, but its file-backed account snapshot store demonstrates the cache properties GitHubBar needs: a store protocol, a versioned Codable payload, identity checks before hydration, atomic writes, owner-only permissions, and best-effort failure that cannot break refresh ([`CodexAccountUsageSnapshotStore.swift:4-21`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/CodexAccountUsageSnapshotStore.swift#L4-L21), [`CodexAccountUsageSnapshotStore.swift:52-111`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/CodexAccountUsageSnapshotStore.swift#L52-L111)). Its widget writer also serializes writes behind the previous task and moves filesystem work off the main actor ([`UsageStore+WidgetSnapshot.swift:7-25`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore%2BWidgetSnapshot.swift#L7-L25)).

GitHubBar should use three deliberately separate persistence classes:

| Data | Storage | Contract |
|---|---|---|
| GitHub credential | Keychain | Never placed in logs, defaults, or the PR cache. |
| Small preferences | `UserDefaults` through injected `SettingsStore` | Stable raw keys/defaults and synchronous setter persistence. |
| Last successful PR snapshot + local snooze/mute metadata | Application Support file/database | Versioned, keyed to GitHub host and authenticated account ID, atomic/transactional, `0600`, best effort, and written off-main. |

Hydrate only a cache whose host/account identity matches the current credential. Persist the last successful/partial snapshot, its fetch timestamp, and enough source metadata to explain freshness. Do not persist `lastPopoverOpenAt`; like CodexBar's interaction signal, it should reset on launch. Do not copy app-group/widget snapshot machinery until a widget is actually in scope.

The exact JSON-versus-SQLite choice should remain with the later data/scale investigation. The architectural contract above is independent of that choice.

## Test strategy to copy

CodexBar's best tests target pure seams and observable contracts:

- The core adaptive policy uses table-driven boundary cases for future timestamps, exactly 5 minutes/1 hour/4 hours, low-power precedence, constrained thermal state, and global 2–30-minute bounds ([`AdaptiveRefreshPolicyCoreTests.swift:21-99`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Tests/AdaptiveReplayKitTests/AdaptiveRefreshPolicyCoreTests.swift#L21-L99)).
- The macOS adapter is tested separately from the core policy ([`AdaptiveRefreshPolicyTests.swift:20-60`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Tests/CodexBarTests/AdaptiveRefreshPolicyTests.swift#L20-L60)).
- Timer tests verify no-history startup, interaction without synchronous refresh, single-flight behavior, manual/fixed/adaptive modes, cadence anchoring, and cancellation on settings changes ([`AdaptiveRefreshTimerTests.swift:11-118`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Tests/CodexBarTests/AdaptiveRefreshTimerTests.swift#L11-L118), [`AdaptiveRefreshTimerTests.swift:133-220`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Tests/CodexBarTests/AdaptiveRefreshTimerTests.swift#L133-L220)).
- A pure `MenuOpenRefreshPlan` separates selection policy from AppKit scheduling ([`MenuOpenRefreshPlan.swift:3-40`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/MenuOpenRefreshPlan.swift#L3-L40)).
- Menu-open integration tests prove that fresh cached data appears without an unnecessary request and missing data refreshes asynchronously in the background ([`StatusMenuInstantOpenTests.swift:8-58`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Tests/CodexBarTests/StatusMenuInstantOpenTests.swift#L8-L58), [`StatusMenuInstantOpenTests.swift:221-284`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Tests/CodexBarTests/StatusMenuInstantOpenTests.swift#L221-L284)).
- The app delegate's status-controller factory allows lifecycle testing without touching the real system status bar ([`AppDelegateTests.swift:7-73`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Tests/CodexBarTests/AppDelegateTests.swift#L7-L73)).
- Menu data is first reduced to a descriptor that can be asserted without visual rendering ([`MenuDescriptor.swift:4-96`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/MenuDescriptor.swift#L4-L96)).

For GitHubBar, translate these into:

1. Pure next-move and queue-order tests using fixture PRs.
2. Table-driven adaptive-policy tests, unchanged except for `lastPopoverOpenAt` naming.
3. Scheduler tests with injected clock/sleep functions; no real minute-scale sleeps.
4. Single-flight tests covering startup + timer + popover-open + manual collisions.
5. Generation tests proving a response from an old account/token cannot publish.
6. Cache tests for schema version, account mismatch, corrupt files, atomic replacement, and last-success retention.
7. Settings tests with isolated `UserDefaults` suites and no real Keychain.
8. Popover integration tests proving cached-first render, open debounce/cancellation, stale/partial banners, reviewer roster rendering, and quick links.
9. A performance regression test/benchmark for deriving and rendering at least 500 active PR row models; the view should use lazy containers.
10. No live GitHub, browser, notification-center authorization, or Keychain access in unit tests.

Use a small, immutable `PullRequestRowModel`/section descriptor as the equivalent of `MenuDescriptor`. Do not copy the descriptor's provider/action enums; copy the idea that business-to-presentation mapping should be testable without AppKit.

## Complexity and coupling to leave behind

The audited snapshot contains 46 `StatusItemController*.swift` files, 32 `UsageStore*.swift` files, and 10 `SettingsStore*.swift` files. Those files serve CodexBar's mature multi-provider product; they are evidence against starting GitHubBar as a fork.

Specific coupling risks:

- **Provider identity is pervasive.** `UsageStore` state is keyed by `UsageProvider`, and menu descriptors iterate provider registries ([`UsageStore.swift:154-192`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/UsageStore.swift#L154-L192), [`MenuDescriptor.swift:84-153`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/MenuDescriptor.swift#L84-L153)). Reusing these types would force PRs into a quota-provider model.
- **The status controller is an `NSMenu` state machine.** It owns persistent menus, tracking sessions, multiple rebuild queues, cached hosting views, viewport restoration, provider switchers, and delayed/deferred refresh work ([`StatusItemController.swift:122-213`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController.swift#L122-L213)). A popover deletes most of this problem space.
- **Open-menu refresh includes prompt-safety behavior for dashboard scraping.** It defers potentially interactive work until all menus close ([`StatusItemController+MenuInteractionRefresh.swift:98-173`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/StatusItemController%2BMenuInteractionRefresh.swift#L98-L173)). GitHubBar should keep automatic refresh non-interactive, but it does not need the provider/dashboard tail.
- **Settings mix several storage systems.** The constructor accepts many provider secret stores and runs migration/detection logic ([`SettingsStore.swift:238-360`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Sources/CodexBar/SettingsStore.swift#L238-L360)). GitHubBar needs one Keychain credential adapter and a small settings model.
- **Package breadth is product-specific.** CodexBar includes CLI, widgets, watchdog/probe helpers, Sparkle, keyboard shortcuts, browser-cookie support, replay tooling, and multiple test targets ([`Package.swift:27-53`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Package.swift#L27-L53), [`Package.swift:143-197`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/Package.swift#L143-L197)). Add such products only when GitHubBar's scope calls for them.

Therefore: **build GitHubBar as a fresh repository-native implementation, optionally copying the small adaptive-policy algorithm and selected lifecycle/testing idioms with attribution. Do not fork or link `CodexBarCore`.**

## MIT attribution obligations

CodexBar's repository license is MIT, copyright 2026 Peter Steinberger. It permits use, copying, modification, distribution, sublicensing, and sale, but requires that **the copyright notice and permission notice be included in all copies or substantial portions of the software** ([`LICENSE:1-20`](https://github.com/steipete/CodexBar/blob/b41715f3e3fb85d01d807b9bd7a64d9bf384c6f8/LICENSE#L1-L20)).

Practical rule for GitHubBar:

- If GitHubBar copies `AdaptiveRefreshPolicyCore.swift`, other source files, line-equivalent implementations, tests, artwork, or another substantial portion, add a `THIRD_PARTY_NOTICES.md` (or equivalent distributed notice) containing CodexBar's full MIT copyright and permission text, upstream repository URL, and the source commit. Preserve any per-file notices if present.
- Keep GitHubBar's own license separate; the MIT notice can coexist with it.
- A fresh implementation of architectural ideas does not copy source text, but because this design deliberately derives an exact refresh table from CodexBar, retaining the notice is the low-cost, unambiguous choice even if only the policy is reused.
- CodexBar's dependency licenses are separate obligations. Do not assume the root MIT license relicenses Sparkle, KeyboardShortcuts, Vortex, SweetCookieKit, or other dependencies.
- Do not reuse CodexBar's name, icon, or branding for GitHubBar merely because the source is MIT. Use GitHubBar-native artwork and identifiers.

This section records the upstream license's text and an engineering compliance recommendation; it is not legal advice.

## Decision record for the Wayfinder map

The reusable route is now clear:

1. Create a fresh Swift 6/macOS 14 GitHubBar with `GitHubBarCore`, `GitHubBar`, and test targets.
2. Use CodexBar's injected SwiftUI/AppDelegate/`NSStatusItem` lifecycle, but anchor an `NSPopover`, not an `NSMenu`.
3. Use `@MainActor @Observable` stores with injected side effects and generation-guarded publication.
4. Carry over manual/fixed/adaptive refresh choices, the exact bounded adaptive table, fixed-cadence anchoring, single-flight refresh, cached-first launch/open, and interaction-only timer advancement.
5. Make open refresh asynchronous, debounced, coalesced, and independent of the periodic clock; refresh the single GitHub scope on every sustained open as already decided.
6. Persist credentials in Keychain, preferences in defaults, and a versioned identity-bound last-success cache in Application Support.
7. Replace CodexBar's error-string staleness with typed fresh/stale/partial/failed state while retaining the last useful snapshot.
8. Copy the pure-policy, scheduler, lifecycle-factory, cache, and presentation-descriptor testing styles; leave the provider and `NSMenu` regression machinery behind.
9. Include CodexBar's MIT notice if any source or the exact adaptive policy is copied/adapted.

