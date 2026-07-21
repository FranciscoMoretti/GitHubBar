---
status: accepted
---

# Publish 1.0.0 without Apple credentials

GitHubBar 1.0.0 will be published as a normal GitHub release using a universal, ad-hoc-signed validation build. It will not be Developer ID signed, Apple-notarized, or connected to the Sparkle update channel.

This decision explicitly supersedes ADR-0002's requirement that the first non-prerelease version cross the Apple and Sparkle trust gate. Release notes and installation documentation must disclose the missing trust properties and give users checksum verification and the narrow Gatekeeper **Open Anyway** path.

## Consequences

- GitHub recognizes 1.0.0 as the latest release and displays it in the repository sidebar.
- The release includes a universal ZIP and adjacent SHA-256 checksum built from the tagged commit.
- Automatic updates remain disabled, and a future signed release must establish the stable Sparkle channel rather than treating 1.0.0 as an update-capable predecessor.
- The signed stable workflow and credential runbook remain available for that future release.
