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
- Add or remove watched repos from the popover; a background poll keeps
  the feed fresh even while it's closed
- Sign in with GitHub via device authorization — no password or manually
  generated token needed, and nothing is ever typed into the app itself
- Zero third-party dependencies — pure SwiftUI and URLSession

## Requirements

- macOS 14 or later
- A GitHub account with access to whatever repos you want to watch

## Usage

1. Build and run the app (see Building, below).
2. Click the shield icon in the menu bar, then **Sign in with GitHub**.
   You'll get a short code — click **Open GitHub**, enter the code there,
   and authorize. The popover updates automatically once that completes.
3. Click the gear icon to add or remove watched repos (`owner/repo`).
4. Click any alert to open it on github.com.

If a source shows as unavailable, it usually means that alert type is
disabled for the repo, or your account lacks permission for it — not
that something is broken. Classic OAuth's `security_events` scope
(what device flow grants) may not be sufficient for Dependabot alerts on
private repos — if you hit that, it needs verifying against a real
private repo case by case.

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
