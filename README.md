# octosentry

A macOS menu bar app that aggregates GitHub security alerts — Dependabot,
code scanning, and secret scanning — across your repos into a single,
severity-ranked feed. No dashboard, no general-purpose GitHub browsing:
just a fast triage view that deep-links out to github.com to act.

## Features

- Unified feed across all three GitHub security alert types, normalized
  onto one severity scale
- Source badge, repo, GitHub's own severity label, one-line summary, and
  age for each alert
- Click an alert to open it directly on github.com
- Errors and unavailable sources (e.g. an alert type disabled for a repo)
  are surfaced in the popover instead of failing silently
- Zero third-party dependencies — pure SwiftUI and URLSession

## Requirements

- macOS 14 or later
- A GitHub personal access token (fine-grained or classic) with read
  access to Dependabot alerts, code scanning alerts, and secret scanning
  alerts for the repo you want to watch

## Usage

octosentry currently watches a single, hardcoded repo and reads its
GitHub token from the `GITHUB_TOKEN` environment variable — this is a
development-only shortcut ahead of a proper device authorization flow.

1. Build and run the app (see Building, below).
2. Set `GITHUB_TOKEN` in your **personal, non-shared** Xcode scheme
   (Product → Scheme → Edit Scheme… → Run → Arguments →
   Environment Variables). Don't add it to a shared scheme — that would
   commit the token to git.
3. Click the shield icon in the menu bar to open the popover. It fetches
   automatically on open, or use the refresh button.
4. Click any alert to open it on github.com.

If a source shows as unavailable, it usually means that alert type is
disabled for the repo, or the token is missing that one permission — not
that something is broken.

## Building

Open `octosentry.xcodeproj` in Xcode and run the `octosentry` scheme.
The project targets macOS 14 with Swift 6 language mode and strict
concurrency enabled — no package dependencies to resolve.

## Contributing

Issues and pull requests are welcome. A few things worth knowing before
you start:

- No third-party dependencies — this is a hard constraint, not a
  preference.
- Swift 6 strict concurrency is on; new code should compile clean under
  it, not suppress it.
- Match the existing file-per-type layout (models, mapping, API client,
  views) rather than introducing new architectural patterns.

## License

GPL-3.0 — see [LICENSE](LICENSE).
