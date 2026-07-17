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
    private(set) var totalFetchedCount = 0
    private(set) var watchedRepos: [String] = []
    private(set) var watchListErrorMessage: String?

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
        minimumSeverity = state.minimumSeverity
        watchedRepos = state.watchedRepos

        guard let token = KeychainTokenStore.load() else {
            errorMessages = [GitHubAPIError.missingToken.errorDescription ?? "Not signed in."]
            return
        }

        let client = GitHubSecurityAPIClient(token: token)

        var fetchedEvents: [SecurityEvent] = []
        var errors: [String] = []
        var notices: [String] = []

        for repoFullName in state.watchedRepos {
            let parts = repoFullName.split(separator: "/", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let owner = String(parts[0])
            let repo = String(parts[1])

            async let dependabot = fetchSource(label: "\(repoFullName) · Dependabot") {
                try await client.fetchDependabotAlerts(owner: owner, repo: repo)
            }
            async let codeScanning = fetchSource(label: "\(repoFullName) · Code scanning") {
                try await client.fetchCodeScanningAlerts(owner: owner, repo: repo)
            }
            async let secretScanning = fetchSource(label: "\(repoFullName) · Secret scanning") {
                try await client.fetchSecretScanningAlerts(owner: owner, repo: repo)
            }

            let outcomes = await [dependabot, codeScanning, secretScanning]
            var repoSucceeded = false
            for outcome in outcomes {
                switch outcome {
                case .events(let sourceEvents):
                    fetchedEvents += sourceEvents
                    repoSucceeded = true
                case .unavailable(let label):
                    notices.append("\(label) alerts aren't available for this repo (disabled, or token lacks that permission).")
                case .failed(let label, let message):
                    errors.append("\(label): \(message)")
                }
            }
            if repoSucceeded {
                state.lastFetchByRepo[repoFullName] = Date()
            }
        }

        rawEvents = fetchedEvents.map { event in
            var event = event
            event.seenLocally = state.seenEventIDs.contains(event.id)
            return event
        }
        totalFetchedCount = rawEvents.count
        applyMinimumSeverityFilter()

        errorMessages = errors
        unavailableNotices = notices
        await persistenceStore.save(state)
    }

    func setMinimumSeverity(_ severity: SecurityEventSeverity) async {
        minimumSeverity = severity
        applyMinimumSeverityFilter()

        var state = await persistenceStore.load()
        state.minimumSeverity = severity
        await persistenceStore.save(state)
    }

    func addRepo(_ input: String) async {
        watchListErrorMessage = nil
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: "/", omittingEmptySubsequences: true)
        guard parts.count == 2 else {
            watchListErrorMessage = "Enter a repo as \"owner/repo\"."
            return
        }

        var state = await persistenceStore.load()
        guard !state.watchedRepos.contains(trimmed) else {
            watchListErrorMessage = "\(trimmed) is already watched."
            return
        }
        state.watchedRepos.append(trimmed)
        await persistenceStore.save(state)
        watchedRepos = state.watchedRepos

        await refresh()
    }

    /// Lists repos the current token can see, for the repo picker (#15).
    /// Requires broader repo-access scope — throws if the token only has
    /// the default security_events scope.
    func fetchAccessibleRepos() async throws -> [String] {
        guard let token = KeychainTokenStore.load() else {
            throw GitHubAPIError.missingToken
        }
        return try await GitHubSecurityAPIClient(token: token).fetchAccessibleRepos()
    }

    /// Local-only triage state (spec §11) — no API write, no scope beyond
    /// read needed. Removes the event from the active stream.
    func markSeen(_ eventID: String) async {
        var state = await persistenceStore.load()
        state.seenEventIDs.insert(eventID)
        await persistenceStore.save(state)

        rawEvents.removeAll { $0.id == eventID }
        totalFetchedCount = rawEvents.count
        applyMinimumSeverityFilter()
    }

    func removeRepo(_ repoFullName: String) async {
        var state = await persistenceStore.load()
        state.watchedRepos.removeAll { $0 == repoFullName }
        state.lastFetchByRepo.removeValue(forKey: repoFullName)
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

    private func applyMinimumSeverityFilter() {
        events = rawEvents
            .filter { $0.severity >= minimumSeverity }
            .sorted { lhs, rhs in
                lhs.severity != rhs.severity ? lhs.severity > rhs.severity : lhs.createdAt > rhs.createdAt
            }
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
