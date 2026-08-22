//
//  SecurityEventStore.swift
//  octosentry
//
//  Holds the fetched event stream for the popover. Watch list, seen-state,
//  and last-fetch timestamps are persisted (see PersistedState); the token
//  comes from Keychain, put there by the device authorization flow (spec §6).
//
//  Each alert source is fetched independently, per repo, so a problem
//  with one endpoint (or one repo) doesn't blank out the rest. A 403/404
//  on a single source usually just means that alert type is disabled for
//  the repo (or the token lacks that one permission) — not a real
//  failure — so those are reported as quiet "unavailable" notices rather
//  than alarming errors.
//

import Foundation
import Observation

@Observable
final class SecurityEventStore {
    private(set) var events: [SecurityEvent] = []
    private(set) var isLoading = false
    private(set) var errorMessages: [String] = []
    private(set) var unavailableNotices: [String] = []
    private(set) var minimumSeverity: SecurityEventSeverity = .low
    private(set) var sortOrder: AlertSortOrder = .severity
    private(set) var totalFetchedCount = 0
    private(set) var watchedRepos: [WatchedRepo] = []
    private(set) var watchListErrorMessage: String?

    /// Per-session narrowing, not persisted. Setting it re-derives `events`.
    var filter = AlertFilter() {
        didSet { applyFilters() }
    }

    /// Local triage state (dismissed / snoozed), mirrored from PersistedState
    /// so the feed can be re-derived without touching disk.
    private(set) var triage = AlertTriage()

    /// Trend data for the dedicated window (#10). Mirrored from
    /// PersistedState so the view doesn't touch disk.
    private(set) var history = AlertHistory()

    /// Repos represented in the current fetch, for the repo filter menu —
    /// the watch list can contain repos that returned nothing.
    var reposInFeed: [String] {
        Set(rawEvents.map(\.repoFullName)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Repo names watched under more than one account — the feed shows
    /// attribution only for these, since it's noise everywhere else.
    private var reposWatchedBySeveralAccounts: Set<String> = []

    func showsAttribution(for repoFullName: String) -> Bool {
        reposWatchedBySeveralAccounts.contains(repoFullName)
    }

    /// Alerts held back by the source/repo filter, as opposed to the
    /// severity floor, so the empty state can say which one is hiding them.
    var filteredOutCount: Int {
        rawEvents.filter { $0.severity >= minimumSeverity }.count - events.count
    }

    var unseenCriticalCount: Int {
        rawEvents.filter { $0.severity == .critical && !$0.seenLocally }.count
    }

    private let persistenceStore = PersistenceStore()
    private var rawEvents: [SecurityEvent] = []
    private var pollingTask: Task<Void, Never>?

    func refresh() async {
        isLoading = true
        errorMessages = []
        unavailableNotices = []
        defer { isLoading = false }

        var state = await persistenceStore.load()
        let stateLoadFailure = await persistenceStore.loadFailureMessage
        minimumSeverity = state.minimumSeverity
        sortOrder = state.sortOrder
        watchedRepos = state.watchedRepos
        triage = state.triage
        history = state.history

        let accountsByID = Dictionary(uniqueKeysWithValues: state.accounts.map { ($0.id, $0) })
        guard !accountsByID.isEmpty else {
            errorMessages = [stateLoadFailure, GitHubAPIError.missingToken.errorDescription ?? "Not signed in."]
                .compactMap { $0 }
            return
        }

        var fetchedEvents: [SecurityEvent] = []
        var errors: [String] = [stateLoadFailure].compactMap { $0 }
        var notices: [String] = []
        // Only repos that actually answered this round; a repo that errored
        // keeps its previous baseline so a transient failure doesn't make its
        // alerts look new on the next poll.
        var fetchedEventsByRepo: [String: [SecurityEvent]] = [:]

        for watched in state.watchedRepos {
            let repoFullName = watched.fullName
            let parts = repoFullName.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repo = String(parts[1])

            guard let account = accountsByID[watched.accountID],
                  let token = KeychainTokenStore.load(account: account.keychainAccount) else {
                errors.append("\(repoFullName): no signed-in account can reach this repo.")
                continue
            }
            let client = GitHubSecurityAPIClient(token: token, host: account.host)
            let label = accountsByID.count > 1
                ? "\(repoFullName) (\(account.displayName))"
                : repoFullName

            async let dependabot = fetchSource(label: "\(label) · Dependabot") {
                try await client.fetchDependabotAlerts(owner: owner, repo: repo)
            }
            async let codeScanning = fetchSource(label: "\(label) · Code scanning") {
                try await client.fetchCodeScanningAlerts(owner: owner, repo: repo)
            }
            async let secretScanning = fetchSource(label: "\(label) · Secret scanning") {
                try await client.fetchSecretScanningAlerts(owner: owner, repo: repo)
            }

            let outcomes = await [dependabot, codeScanning, secretScanning]
            var repoEvents: [SecurityEvent] = []
            var repoSucceeded = false
            for outcome in outcomes {
                switch outcome {
                case .events(let sourceEvents):
                    repoEvents += sourceEvents.map { event in
                        var event = event
                        event.accountLogins = [account.displayName]
                        return event
                    }
                    repoSucceeded = true
                case .unavailable(let label):
                    notices.append("\(label) alerts aren't available for this repo (disabled, or token lacks that permission).")
                case .failed(let label, let message):
                    errors.append("\(label): \(message)")
                }
            }
            fetchedEvents += repoEvents
            if repoSucceeded {
                state.lastFetchByRepo[repoFullName] = Date()
                fetchedEventsByRepo[repoFullName, default: []] += repoEvents
            }
        }

        // The same alert reached through two identities is one alert; merge
        // the attributions rather than showing it twice.
        fetchedEvents = Self.merged(fetchedEvents)
        for (repoFullName, events) in fetchedEventsByRepo {
            fetchedEventsByRepo[repoFullName] = Self.merged(events)
        }
        reposWatchedBySeveralAccounts = Self.reposWatchedBySeveralAccounts(in: state.watchedRepos)

        rawEvents = fetchedEvents.map { event in
            var event = event
            event.seenLocally = state.seenEventIDs.contains(event.id)
            return event
        }
        totalFetchedCount = rawEvents.count
        applyFilters()

        errorMessages = errors
        unavailableNotices = notices

        // Only prune against a complete picture: if a repo failed this round
        // its alerts are missing, and pruning would forget they were hidden.
        if fetchedEventsByRepo.count == Set(state.watchedRepos.map(\.fullName)).count {
            let now = Date()
            state.triage = state.triage.pruned(
                presentEventIDs: Set(fetchedEvents.map(\.id)),
                now: now
            )
            triage = state.triage
            applyFilters()

            // Same completeness rule: an alert missing because its repo
            // errored has not been resolved.
            state.history.record(fetchedEvents, at: now)
            history = state.history
        }

        let newEvents = AlertDiff.newlyAppeared(
            in: fetchedEventsByRepo,
            baseline: state.notifiedEventIDsByRepo,
            minimumSeverity: state.minimumSeverity
        )
        state.notifiedEventIDsByRepo = AlertDiff.updatedBaseline(
            from: fetchedEventsByRepo,
            watchedRepos: state.watchedRepos.map(\.fullName),
            previous: state.notifiedEventIDsByRepo
        )
        await persistenceStore.save(state)

        await AlertNotifier.shared.notify(about: newEvents)
    }

    func setMinimumSeverity(_ severity: SecurityEventSeverity) async {
        minimumSeverity = severity
        applyFilters()

        var state = await persistenceStore.load()
        state.minimumSeverity = severity
        await persistenceStore.save(state)
    }

    func setSortOrder(_ order: AlertSortOrder) async {
        sortOrder = order
        applyFilters()

        var state = await persistenceStore.load()
        state.sortOrder = order
        await persistenceStore.save(state)
    }

    func addRepo(_ input: String, accountID: Int) async {
        watchListErrorMessage = nil
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            watchListErrorMessage = "Enter a repo as \"owner/repo\"."
            return
        }
        // Store the canonical "owner/repo" rather than the raw input, so
        // stray slashes (e.g. "owner/repo/") can't produce a malformed
        // entry that silently 404s on refresh.
        let repoFullName = "\(parts[0])/\(parts[1])"

        var state = await persistenceStore.load()
        // GitHub owner/repo names are case-insensitive, so treat entries
        // that differ only in case as the same watched repo. The same repo
        // under a different account is a separate entry on purpose.
        guard !state.watchedRepos.contains(where: {
            $0.accountID == accountID && $0.fullName.caseInsensitiveCompare(repoFullName) == .orderedSame
        }) else {
            watchListErrorMessage = "\(repoFullName) is already watched."
            return
        }
        state.watchedRepos.append(WatchedRepo(fullName: repoFullName, accountID: accountID))
        await persistenceStore.save(state)
        watchedRepos = state.watchedRepos

        await refresh()
    }

    /// Lists repos the current token can see, for the repo picker (#15).
    /// Requires broader repo-access scope — throws if the token only has
    /// the default security_events scope.
    func fetchAccessibleRepos(for account: Account) async throws -> [String] {
        guard let token = KeychainTokenStore.load(account: account.keychainAccount) else {
            throw GitHubAPIError.missingToken
        }
        return try await GitHubSecurityAPIClient(token: token, host: account.host).fetchAccessibleRepos()
    }

    /// Local-only triage state (spec §11) — no API write, no scope beyond
    /// read needed. Removes the event from the active stream.
    func markSeen(_ eventID: String) async {
        var state = await persistenceStore.load()
        state.seenEventIDs.insert(eventID)
        await persistenceStore.save(state)

        rawEvents.removeAll { $0.id == eventID }
        totalFetchedCount = rawEvents.count
        applyFilters()
    }

    /// Hides an alert until the user brings it back. Local only — the alert
    /// is still open on GitHub.
    func dismiss(_ eventID: String) async {
        await updateTriage { $0.dismiss(eventID) }
    }

    /// Hides an alert until `date`; a later poll brings it back.
    func snooze(_ eventID: String, until date: Date) async {
        await updateTriage { $0.snooze(eventID, until: date) }
    }

    func restore(_ eventID: String) async {
        await updateTriage { $0.restore(eventID) }
    }

    private func updateTriage(_ change: (inout AlertTriage) -> Void) async {
        var state = await persistenceStore.load()
        change(&state.triage)
        await persistenceStore.save(state)

        triage = state.triage
        applyFilters()
    }

    func removeRepo(_ watched: WatchedRepo) async {
        var state = await persistenceStore.load()
        state.watchedRepos.removeAll { $0 == watched }
        if !state.watchedRepos.contains(where: { $0.fullName == watched.fullName }) {
            state.lastFetchByRepo.removeValue(forKey: watched.fullName)
        }
        await persistenceStore.save(state)
        watchedRepos = state.watchedRepos

        await refresh()
    }

    /// Keeps the feed reasonably fresh even while the popover is closed,
    /// without hammering GitHub's rate limit (5000/hr authenticated).
    /// Idempotent — safe to call every time the popover opens.
    func startPolling(interval: Duration = .seconds(900)) {
        guard pollingTask == nil else { return }
        pollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: interval)
                guard !Task.isCancelled else { return }
                await refresh()
            }
        }
    }

    private func applyFilters() {
        let now = Date()
        let admitted = rawEvents.filter { event in
            guard event.severity >= minimumSeverity else { return false }
            return filter.showsHidden || !triage.isHidden(event.id, now: now)
        }
        events = sortOrder.sorted(filter.apply(to: admitted))
    }

    /// Collapses alerts that arrived through more than one account, keeping
    /// one row and unioning the attributions. Input order is preserved.
    nonisolated static func merged(_ events: [SecurityEvent]) -> [SecurityEvent] {
        var order: [String] = []
        var byID: [String: SecurityEvent] = [:]

        for event in events {
            if var existing = byID[event.id] {
                for login in event.accountLogins where !existing.accountLogins.contains(login) {
                    existing.accountLogins.append(login)
                }
                byID[event.id] = existing
            } else {
                order.append(event.id)
                byID[event.id] = event
            }
        }

        return order.compactMap { byID[$0] }
    }

    nonisolated static func reposWatchedBySeveralAccounts(in watched: [WatchedRepo]) -> Set<String> {
        var accountsByRepo: [String: Set<Int>] = [:]
        for repo in watched {
            accountsByRepo[repo.fullName, default: []].insert(repo.accountID)
        }
        return Set(accountsByRepo.filter { $0.value.count > 1 }.keys)
    }

    private enum SourceOutcome {
        case events([SecurityEvent])
        case unavailable(label: String)
        case failed(label: String, message: String)
    }

    private func fetchSource(
        label: String,
        _ operation: () async throws -> [SecurityEvent]
    ) async -> SourceOutcome {
        do {
            return .events(try await operation())
        } catch GitHubAPIError.forbidden, GitHubAPIError.notFound {
            return .unavailable(label: label)
        } catch {
            let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return .failed(label: label, message: description)
        }
    }
}
