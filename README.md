# GitHubBar

GitHubBar is a native macOS menu-bar app that keeps pull requests waiting for your review and your own open pull requests visible without repeatedly loading GitHub in a browser.

## Requirements

- macOS 14 or newer
- Xcode with the macOS 14 SDK or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [GitHub CLI](https://cli.github.com/) for the account connection used by the app

## Build

```sh
scripts/generate-project.sh
open GitHubBar.xcodeproj
```

Choose the `GitHubBar` scheme and run it. GitHubBar is an accessory app, so it appears in the menu bar rather than the Dock.

## Checks

```sh
scripts/check.sh
```

The check script builds the strict-concurrency core package, exercises its public seams, and typechecks the AppKit/SwiftUI shell. The normal XCTest suite is also available from a full Xcode installation.

## Validation release

### Install the latest developer build

Validation builds are intended for developers and are not notarized. Download the ZIP and checksum from the current [validation release](https://github.com/FranciscoMoretti/githubbar/releases), then install it with:

```sh
release=validation-v0.1.0-3
download_dir="$(mktemp -d)"
mkdir -p "$HOME/Applications"
cd "$download_dir"

gh release download "$release" \
  --repo FranciscoMoretti/githubbar \
  --pattern '*.zip' \
  --pattern '*.zip.sha256' \
  --clobber

shasum -a 256 --check ./*.zip.sha256
ditto -x -k ./*.zip .
rm -rf "$HOME/Applications/GitHubBar.app"
mv GitHubBar.app "$HOME/Applications/GitHubBar.app"
xattr -dr com.apple.quarantine "$HOME/Applications/GitHubBar.app"
open "$HOME/Applications/GitHubBar.app"
```

These commands replace an existing copy in `~/Applications`. For a future validation release, change the `release` value. Removing the quarantine attribute opts this specific downloaded copy out of Gatekeeper assessment; only do this after the checksum succeeds and when the release came from this repository. Because validation builds have no Apple-verified Developer ID or notarization, the checksum detects a corrupted or mismatched download but is not an independent authenticity guarantee if the GitHub release itself is compromised. Every newly downloaded build must be verified and installed again.

### Package a developer build

Create the universal, ad-hoc-signed validation artifact with:

```sh
GITHUBBAR_VERSION=0.1.0 scripts/package-validation.sh
```

The ZIP and SHA-256 file are written to `dist/`. Validation builds deliberately have automatic updates disabled and are not notarized. Installation, Gatekeeper, privacy, verification, and prerelease publishing steps are documented in [docs/releases/validation-release.md](docs/releases/validation-release.md).

Trusted Developer ID, notarization, stapling, and Sparkle releases use the fail-closed `scripts/package-stable.sh` pipeline. Maintainer-owned credentials, protected workflow configuration, update-key rotation, rollback, revocation, and recovery are documented in [docs/releases/stable-release-runbook.md](docs/releases/stable-release-runbook.md).
