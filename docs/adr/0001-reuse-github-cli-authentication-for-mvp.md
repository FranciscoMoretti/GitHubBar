---
status: accepted
---

# Reuse GitHub CLI authentication for the MVP

GitHubBar's MVP will use an explicitly selected GitHub CLI session as the credential source for its single monitored account. This avoids operating an OAuth application or authentication backend while the product is being validated at real pull-request volume; GitHubBar will not use `gh pr checkout` or make GitHub CLI responsible for the product's pull-request model.

## Considered options

- An OAuth App offers broad cross-repository coverage and polished onboarding, but private pull requests require the broad `repo` scope and a production-quality browser flow raises client-secret or token-exchange-service decisions.
- A GitHub App offers granular read-only permissions, but installation approval in every relevant organization can leave the active workload incomplete.
- Personal access tokens are appropriate only as an advanced fallback because onboarding and cross-organization coverage are poor.

## Consequences

The MVP requires GitHub CLI to be installed and authenticated. GitHubBar must make the selected CLI account and detected access coverage visible, diagnose missing scopes and organization SSO authorization, and treat the GitHub CLI as credential owner rather than persist another long-lived token. First-party OAuth onboarding remains a post-MVP feature.
