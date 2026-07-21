# Mixed review states in pull-request stacks

Research date: 2026-07-21

## Question

When members of one pull-request stack occupy different workflow states, should GitHubBar show one canonical stack row in a single section, or represent the stack in every relevant section?

## Findings

| Product | Representation of a mixed stack | Ordering and placement evidence |
| --- | --- | --- |
| Graphite | Review state remains a property of each PR. After a review, Graphite says that PR moves to the appropriate inbox section. The stack is then available as secondary navigation from an individual PR through **Show stack**. | Graphite recommends reviewing a stack from the bottom (closest to `main`) upward. Its documented inbox behavior supports section membership per PR, not assigning the entire stack one aggregate state. [Review pull requests](https://graphite.com/docs/review-pull-requests) |
| Sapling / ReviewStack | Sapling's official Smartlog example shows one connected stack whose members simultaneously have different states: **Unreviewed**, **Approved**, and **Closed**. ReviewStack lets the reviewer move between the individual changes. | The lineage stays visible and every member keeps its own state; no single member's state replaces the others. [Sapling getting started](https://sapling-scm.com/docs/introduction/getting-started/), [ReviewStack](https://reviewstack.dev/) |
| GitHub Stacked PRs | GitHub describes each member as still being a regular pull request and evaluates reviews and checks for each PR. Stack dependencies add context: a PR also depends on requirements passing for PRs below it. | The stack is explicitly ordered bottom-to-top. Merging proceeds bottom-up, while PRs above a partially merged stack remain open. This supports retaining individual PR state while showing dependency order. [GitHub Stacked PR FAQ](https://github.github.com/gh-stack/faq/), [GitHub Stacked PR overview](https://github.github.com/gh-stack/introduction/overview/) |
| Gerrit | Gerrit presents dependent changes together in a **Relation Chain**, while review properties remain attached to individual changes. An arrow identifies the currently viewed change. | The chain supplies context around the selected change; it does not establish a canonical workflow bucket for the chain. [Gerrit: Changes](https://gerrit-review.googlesource.com/Documentation/concept-changes.html#related-changes) |
| Git Town | Git Town can embed a stack breadcrumb in every proposal and allows root-first direction. | It exposes lineage but does not define an aggregate review status or inbox placement for the stack. [Git Town proposal breadcrumb](https://www.git-town.com/how-to/proposal-breadcrumb.html) |

## What this means for GitHubBar

The common pattern is **individual workflow state plus stack context**. None of the first-party sources found assigns a mixed stack to one highest-priority status bucket. Graphite, the closest match to GitHubBar's sectioned inbox, explicitly moves each PR to its own appropriate section.

Therefore, GitHubBar should keep a collapsed representation of the stack in every section containing one or more of its PRs. This is safer than promoting the entire stack to one section because it does not hide authored work, requested reviews, or approved PRs from the section where the user expects to find them.

For a compact menu:

1. Anchor each section's stack row on the lowest/downstack PR present in that section. This follows Graphite's bottom-up review guidance and gives the next dependency the most prominence.
2. Make the row summary section-aware. Prefer `2 here · 5 total` (or a compact `2/5`) over a global `+4`, which does not explain why the same stack appears elsewhere.
3. Keep the submenu as the complete stack view, ordered bottom-to-top, with a visible state on every PR: needs your review, returned, needs reviewers, waiting, approved, or draft.
4. If space permits, visually emphasize submenu members belonging to the section that opened it; do not reorder the stack by status.

Example: a five-PR stack with one requested review and two authored approvals appears once under **Needs your review** and once under **Approved**. Both rows open the same five-member, bottom-to-top submenu; their compact summaries say `1/5` and `2/5` respectively.

## Recommendation

Keep GitHubBar's current cross-section representation rather than introducing one canonical highest-priority row. Improve its clarity with a section-local/total count and per-member status in the submenu.

## Uncertainty

The sources clearly establish per-PR state, stack ordering, and stack-as-context, but they do not document the exact behavior of a collapsed stack row inside a very small menu-bar interface. The `2 here · 5 total` treatment and the choice of the lowest section member as row anchor are design deductions from those patterns, not copied product behavior. They should be validated in the local app before implementation.
