---
status: accepted
---

# Center the app on a deep WorkloadEngine

GitHubBar will put connection resolution, cached-first reconciliation, scheduling, publication guards, Repository scope, and Snapshot persistence behind one actor-owned `WorkloadEngine` interface. A small main-actor presentation adapter will expose immutable state to the AppKit status-item shell and SwiftUI views; GitHub, GitHub CLI, persistence, clock, and updater behavior vary through narrow seams with real and fake adapters.

## Considered options

- View-owned networking and several thin manager objects were rejected because refresh ordering, account switching, cache safety, and partial-result rules would leak across callers.
- A target per feature was rejected for the MVP because it would add build and interface overhead without independent deployment or ownership needs.
- A generic `WorkItem` abstraction for future Issues support was rejected because pull requests and issues do not yet share a proven domain interface. Future Issues support may reuse infrastructure while defining its own workload projection.

## Consequences

- The repository has one macOS app target and one local `GitHubBarCore` Swift package target.
- `GitHubBarCore` contains no AppKit, SwiftUI, or Sparkle imports.
- The UI observes presentation state and sends commands; it does not coordinate GitHub, GitHub CLI, timers, or persistence.
- Apple frameworks are used throughout, with Sparkle as the only third-party runtime dependency.
