# GitHubBar popover prototype

Throwaway prototype for answering one question: **what information hierarchy should the high-throughput menu-bar popover use?**

Four structural variants are available on one route via `?variant=A`, `?variant=B`, `?variant=C`, and `?variant=D`. Variant D maps the GitHubBar PR model into CodexBar's narrow, flat native-menu visual skeleton.

Run from the repository root:

```bash
python3 -m http.server 4173 --directory prototypes/popover
```

Then open <http://127.0.0.1:4173/?variant=A>.

Use the floating arrows or keyboard left/right arrows to change variant. Variant D also exposes a separate scenario switcher for Fresh, first load, Refreshing with existing data, Cached, Failed, Incomplete access, GitHub CLI missing, GitHub CLI sign-in required, and explicit account confirmation. The selected scenario is encoded in the `?scenario=` URL parameter, so each state can be shared and reloaded directly.

Variants A and D include a multi-repository selection whose choice is persisted in browser local storage to model a device-local preference. In Variant D, authored PRs and drafts share one recently-updated stream. Each row uses a stable left-side open/draft status marker and a bottom metadata line; a single-repository scope hides redundant repository names from that line. Refresh, cached-failure, and incomplete-access states retain the last known pull-request snapshot; first load and account-connection states replace the lists until a complete snapshot is available.

**PROTOTYPE — not production code.** The repository-selection demo uses local browser storage, but there is no real GitHub access or production abstraction.
