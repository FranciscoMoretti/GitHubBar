# GitHub native Pull request stack API

Research date: 2026-07-30

## Question

Can GitHubBar replace branch-name matching with GitHub's public-preview Stack API, and can a Pull request stack open a filtered “See all” view on GitHub?

## Findings

GitHub's GraphQL API now exposes native Stack membership directly on `PullRequest`:

- `stack` returns the Stack node ID, repository-local Stack number, and authoritative size.
- `stackEntry` returns the member's position, where position 1 is closest to the base branch.
- `PullRequestStack.entries` returns the Pull requests in the Stack and is cursor-paginated.

This is sufficient to identify and order a Pull request stack without inferring relationships from head and base branch names. GitHub also documents REST endpoints for creating and managing stacks, but GitHubBar only needs the GraphQL read path for Reconciliation.

The documented issue and pull-request search qualifiers do not include Stack membership, Stack number, or Stack ID. Live searches against a known public Stack on 2026-07-30 confirmed that likely candidates such as `stack:350`, `is:stacked`, and `stacked:true` do not select its members. Unknown `has:` and `no:` values are ignored, so their unchanged totals are not evidence of hidden Stack support.

Sources:

- [Stacked pull requests public-preview announcement](https://github.blog/changelog/2026-07-30-stacked-pull-requests-are-now-in-public-preview/)
- [GitHub GraphQL Pull requests reference](https://docs.github.com/en/graphql/reference/pulls)
- [GitHub GraphQL 2026 changelog](https://docs.github.com/en/graphql/overview/changelog/2026)
- [GitHub issue and pull-request search qualifiers](https://docs.github.com/en/search-github/searching-on-github/searching-issues-and-pull-requests)

## Decision

GitHubBar will:

1. Use native Stack node IDs and positions as the only source of Pull request stack identity and order.
2. Hydrate Stack entries so the submenu can include open, merged, and closed members as navigation context.
3. Use GitHub's reported Stack size for totals and say how many members are available when hydration is incomplete.
4. Keep each section's existing “See all” search section-based because GitHub has no Stack search qualifier.
5. Add **View stack on GitHub** to the Stack submenu. It opens the Stack root's Pull request page when available, or another hydrated member when it is not; GitHub provides native Stack navigation on either page.

## Preview limits

GitHubBar requests up to 100 entries per Stack, matching the public-preview Stack creation limit documented at launch. A paginated response or failed member hydration makes Reconciliation partial and the menu does not claim that its hydrated subset is the complete Stack.
