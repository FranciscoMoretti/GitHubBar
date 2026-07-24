#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
cd "$repo_root"

package_path="Packages/GitHubBarCore"
sdk_path="$(xcrun --sdk macosx --show-sdk-path)"
module_path="$package_path/.build/debug/Modules"

swift build --package-path "$package_path" --target GitHubBarCore
swift run --package-path "$package_path" GitHubBarCoreChecks

rg --files GitHubBar -g '*.swift' -0 | xargs -0 swiftc \
  -typecheck \
  -parse-as-library \
  -swift-version 6 \
  -strict-concurrency=complete \
  -target arm64-apple-macosx14.0 \
  -sdk "$sdk_path" \
  -I "$module_path"

mkdir -p .build/checks
swiftc \
  -parse-as-library \
  -swift-version 6 \
  -strict-concurrency=complete \
  GitHubBar/Shared/AvatarImageCache.swift \
  GitHubBarChecks/AvatarImageCacheCheck.swift \
  -framework AppKit \
  -framework Combine \
  -o .build/checks/avatar-image-cache-check
.build/checks/avatar-image-cache-check

swiftc \
  -parse-as-library \
  -swift-version 6 \
  -strict-concurrency=complete \
  GitHubBar/StatusItem/StatusMenuSizing.swift \
  GitHubBarChecks/StatusMenuSizingCheck.swift \
  -o .build/checks/status-menu-sizing-check
.build/checks/status-menu-sizing-check

plutil -lint GitHubBar/Resources/Info.plist
xcodegen generate
