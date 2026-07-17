//
//  PersistedState.swift
//  octosentry
//
//  Everything the app remembers across launches: the repo watch list,
//  local-only seen-state per event, last-fetch timestamp per repo, the
//  minimum severity filter, and whether the current token has the
//  broader "repo" scope needed to list repos. Flat JSON over SwiftData
//  (see #1) — small, inspectable, and these are already plain Codable
//  values passed across actor boundaries, not reference types tied to a
//  persistence context.
//

import Foundation

nonisolated struct PersistedState: Codable {
    var watchedRepos: [String]
    var seenEventIDs: Set<String>
    var lastFetchByRepo: [String: Date]
    var minimumSeverity: SecurityEventSeverity
    var hasRepoScope: Bool

    enum CodingKeys: String, CodingKey {
        case watchedRepos, seenEventIDs, lastFetchByRepo, minimumSeverity, hasRepoScope
    }

    init(
        watchedRepos: [String],
        seenEventIDs: Set<String>,
        lastFetchByRepo: [String: Date],
        minimumSeverity: SecurityEventSeverity,
        hasRepoScope: Bool = false
    ) {
        self.watchedRepos = watchedRepos
        self.seenEventIDs = seenEventIDs
        self.lastFetchByRepo = lastFetchByRepo
        self.minimumSeverity = minimumSeverity
        self.hasRepoScope = hasRepoScope
    }

    // Custom decode so existing state.json files saved before hasRepoScope
    // existed still load instead of falling back to .placeholder.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        watchedRepos = try container.decode([String].self, forKey: .watchedRepos)
        seenEventIDs = try container.decode(Set<String>.self, forKey: .seenEventIDs)
        lastFetchByRepo = try container.decode([String: Date].self, forKey: .lastFetchByRepo)
        minimumSeverity = try container.decode(SecurityEventSeverity.self, forKey: .minimumSeverity)
        hasRepoScope = try container.decodeIfPresent(Bool.self, forKey: .hasRepoScope) ?? false
    }

    static let placeholder = PersistedState(
        watchedRepos: ["ccleberg/cleberg.net"],
        seenEventIDs: [],
        lastFetchByRepo: [:],
        minimumSeverity: .low
    )
}
