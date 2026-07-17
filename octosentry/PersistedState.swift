//
//  PersistedState.swift
//  octosentry
//
//  Everything the app remembers across launches: the repo watch list,
//  local-only seen-state per event, last-fetch timestamp per repo, and the
//  minimum severity filter. Flat JSON over SwiftData (see #1) — small,
//  inspectable, and these are already plain Codable values passed across
//  actor boundaries, not reference types tied to a persistence context.
//

import Foundation

nonisolated struct PersistedState: Codable {
    var watchedRepos: [String]
    var seenEventIDs: Set<String>
    var lastFetchByRepo: [String: Date]
    var minimumSeverity: SecurityEventSeverity

    static let placeholder = PersistedState(
        watchedRepos: ["ccleberg/cleberg.net"],
        seenEventIDs: [],
        lastFetchByRepo: [:],
        minimumSeverity: .low
    )
}
