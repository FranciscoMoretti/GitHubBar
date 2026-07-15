# GitHubBar status-item icon study

Independent native-scale design study for GitHubBar's macOS status item. These are monochrome black-and-alpha SVGs intended to become 18×18 pt AppKit template images rendered at 2×.

- `githubbar-status-empty.svg`: no badge when nothing awaits review.
- `githubbar-status-4.svg`: single-digit bottom-right badge.
- `githubbar-status-9plus.svg`: compact capped state for ten or more waiting reviews.
- `preview.svg`: menu-bar context plus enlarged inspection views.

The pull-request silhouette is adapted from GitHub Primer's MIT-licensed `git-pull-request-16` Octicon. The badge is knocked out of the same monochrome mask so macOS can tint the complete image correctly in light, dark, and selected appearances.

Production rendering should use `NSStatusItem.squareLength`, an 18×18 pt `NSImage` with a 36×36 px Retina representation, `isTemplate = true`, and `imageScaling = .scaleNone`. The exact uncapped review count belongs in the accessibility title even when the visible badge is capped.
