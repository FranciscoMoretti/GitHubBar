# GitHubBar validation release

This artifact is the first installable validation build of GitHubBar. It is universal (`arm64` and `x86_64`), targets macOS 14 or newer, is ad-hoc signed, and is intentionally not notarized. It is not part of GitHubBar's future trusted Developer ID/Sparkle update channel.

## Install and launch

1. Download the validation ZIP from the GitHub prerelease and verify its adjacent SHA-256 file.
2. Unzip it and move `GitHubBar.app` to `/Applications`.
3. Ensure [GitHub CLI](https://cli.github.com/) is installed and connected to the accounts you want GitHubBar to inspect.
4. Open GitHubBar. It appears in the menu bar and does not add a Dock icon.

Because this build is not Developer ID signed or notarized, macOS Gatekeeper may block the first launch after download. Control-click the app and choose Open; if macOS still blocks it, use System Settings → Privacy & Security → Open Anyway after confirming that the downloaded checksum matches the release checksum. This limitation is expected only for validation builds.

Automatic updates are explicitly disabled. Install a later validation build by replacing the app manually.

## Privacy and local data

GitHubBar retrieves a temporary token from GitHub CLI into process memory. It never stores that token. Preferences contain the selected account login, repository scope, cadence, and general settings. The active PR snapshot is stored in Application Support with owner-only permissions. Local OSLog diagnostics contain refresh reason, timing, cost, counts, completeness, and failure categories—not tokens, headers, GraphQL bodies, repository names, PR titles, or usernames.

## Maintainer verification

Run from a clean checkout:

```sh
scripts/check.sh
GITHUBBAR_VERSION=0.1.0 scripts/package-validation.sh
lipo -archs .build/validation/GitHubBar.app/Contents/MacOS/GitHubBar
codesign --verify --deep --strict --verbose=2 .build/validation/GitHubBar.app
```

Expected architecture output is `arm64 x86_64`. The packaging script also validates the plist, checks the ad-hoc signature, scans the executable for test credential markers, and emits an adjacent SHA-256 file.

Before publishing, manually verify on a supported macOS account:

- instant Snapshot startup and live reconciliation;
- zero, single-digit, and two-digit carved status counts with the exact VoiceOver count;
- both PR sections, drafts, reviewer avatars/fallbacks, and row keyboard activation;
- repository search and persisted selection;
- account recovery/selection, cadence changes, and launch-at-login reporting;
- partial, rate-limited, and failed freshness banners retaining the prior list;
- reduced-motion popover behavior and Settings keyboard navigation;
- disabled validation updates and version/build About information.

## Publish a prerelease

Push a tag matching `validation-v*` (for example `validation-v0.1.0-1`). The validation release workflow builds the artifact from that commit and creates a GitHub prerelease with the ZIP, checksum, and these notes. The workflow can also be started manually with a new validation tag.
