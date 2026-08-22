//
//  PersistedState.swift
//  octosentry
//
//  Everything the app remembers across launches: the signed-in accounts and
//  the repo watch list,
//  local-only seen-state per event, last-fetch timestamp per repo, the
//  minimum severity filter, the feed sort order, local triage state, the
//  per-repo alert IDs the notifier has already accounted for, and whether the current token
//  has the broader "repo" scope needed to list repos. Flat JSON over SwiftData
//  (see #1) — small, inspectable, and these are already plain Codable
//  values passed across actor boundaries, not reference types tied to a
//  persistence context.
//

import Foundation

nonisolated struct PersistedState: Codable {
    var accounts: [Account]
    var watchedRepos: [WatchedRepo]
    var seenEventIDs: Set<String>
    var lastFetchByRepo: [String: Date]
    var minimumSeverity: SecurityEventSeverity
    var hasRepoScope: Bool
    var sortOrder: AlertSortOrder

    /// Alert IDs seen on the last successful fetch, per repo. nil means this
    /// install has never completed a fetch, which is what tells the notifier
    /// to seed quietly instead of announcing every pre-existing alert. A repo
    /// with no entry is treated the same way, so newly watched repos don't
    /// arrive as a burst.
    var notifiedEventIDsByRepo: [String: Set<String>]?

    /// What the user has hidden locally, and until when.
    var triage: AlertTriage

    /// Snapshots and per-alert lifecycles behind the trends view. Bounded by
    /// AlertHistory's own retention rules.
    var history: AlertHistory

    enum CodingKeys: String, CodingKey {
        case watchedRepos, seenEventIDs, lastFetchByRepo, minimumSeverity, hasRepoScope, sortOrder
        case notifiedEventIDsByRepo, triage, history, accounts
    }

    init(
        accounts: [Account] = [],
        watchedRepos: [WatchedRepo],
        seenEventIDs: Set<String>,
        lastFetchByRepo: [String: Date],
        minimumSeverity: SecurityEventSeverity,
        hasRepoScope: Bool = false,
        sortOrder: AlertSortOrder = .severity,
        notifiedEventIDsByRepo: [String: Set<String>]? = nil,
        triage: AlertTriage = AlertTriage(),
        history: AlertHistory = AlertHistory()
    ) {
        self.accounts = accounts
        self.watchedRepos = watchedRepos
        self.seenEventIDs = seenEventIDs
        self.lastFetchByRepo = lastFetchByRepo
        self.minimumSeverity = minimumSeverity
        self.hasRepoScope = hasRepoScope
        self.sortOrder = sortOrder
        self.notifiedEventIDsByRepo = notifiedEventIDsByRepo
        self.triage = triage
        self.history = history
    }

    // Custom decode so existing state.json files saved before hasRepoScope
    // and sortOrder existed still load instead of falling back to .placeholder.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        accounts = try container.decodeIfPresent([Account].self, forKey: .accounts) ?? []
        // Before multi-account, watchedRepos was a plain [String] belonging to
        // the one signed-in account. Decode either shape.
        if let repos = try? container.decode([WatchedRepo].self, forKey: .watchedRepos) {
            watchedRepos = repos
        } else {
            let names = try container.decode([String].self, forKey: .watchedRepos)
            watchedRepos = names.map { WatchedRepo(fullName: $0, accountID: 0) }
        }
        seenEventIDs = try container.decode(Set<String>.self, forKey: .seenEventIDs)
        lastFetchByRepo = try container.decode([String: Date].self, forKey: .lastFetchByRepo)
        minimumSeverity = try container.decode(SecurityEventSeverity.self, forKey: .minimumSeverity)
        hasRepoScope = try container.decodeIfPresent(Bool.self, forKey: .hasRepoScope) ?? false
        sortOrder = try container.decodeIfPresent(AlertSortOrder.self, forKey: .sortOrder) ?? .severity
        notifiedEventIDsByRepo = try container.decodeIfPresent(
            [String: Set<String>].self,
            forKey: .notifiedEventIDsByRepo
        )
        triage = try container.decodeIfPresent(AlertTriage.self, forKey: .triage) ?? AlertTriage()
        history = try container.decodeIfPresent(AlertHistory.self, forKey: .history) ?? AlertHistory()
    }

    /// A fresh install watches nothing until the user adds a repo. Seeding a
    /// specific repo here meant every new install started by fetching someone
    /// else's alerts, which it usually can't read.
    static let placeholder = PersistedState(
        watchedRepos: [],
        seenEventIDs: [],
        lastFetchByRepo: [:],
        minimumSeverity: .low
    )
}
