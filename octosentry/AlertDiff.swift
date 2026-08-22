//
//  AlertDiff.swift
//  octosentry
//
//  Works out what a poll turned up that wasn't there before, and what the
//  next poll should compare against. Kept separate from SecurityEventStore
//  so the rules are testable without a network or a token.
//
//  The baseline is per repo rather than one flat set: a repo that failed to
//  fetch keeps its previous entry, so a transient error doesn't make its
//  alerts look new on the next poll.
//

import Foundation

nonisolated enum AlertDiff {
    /// Alerts present now that weren't in the baseline for the same repo,
    /// filtered to the minimum-severity threshold so notifications and the
    /// feed agree about what's worth surfacing.
    ///
    /// Returns nothing for a repo with no baseline entry — a first sync, or a
    /// repo just added to the watch list. Its backlog isn't news, and
    /// announcing it is how a busy repo produces a notification storm.
    static func newlyAppeared(
        in fetchedByRepo: [String: [SecurityEvent]],
        baseline: [String: Set<String>]?,
        minimumSeverity: SecurityEventSeverity
    ) -> [SecurityEvent] {
        guard let baseline else { return [] }

        let new = fetchedByRepo.flatMap { repoFullName, events -> [SecurityEvent] in
            guard let known = baseline[repoFullName] else { return [] }
            return events.filter { !known.contains($0.id) && $0.severity >= minimumSeverity }
        }

        // Dictionary iteration order isn't stable, so impose one.
        return new.sorted { lhs, rhs in
            lhs.severity != rhs.severity ? lhs.severity > rhs.severity : lhs.id < rhs.id
        }
    }

    /// The baseline to compare the next poll against: fresh IDs for repos that
    /// answered, previous entries kept for repos that didn't, and entries
    /// dropped for repos no longer watched so the file doesn't grow forever.
    static func updatedBaseline(
        from fetchedByRepo: [String: [SecurityEvent]],
        watchedRepos: [String],
        previous: [String: Set<String>]?
    ) -> [String: Set<String>] {
        var baseline = previous ?? [:]
        for (repoFullName, events) in fetchedByRepo {
            baseline[repoFullName] = Set(events.map(\.id))
        }
        return baseline.filter { watchedRepos.contains($0.key) }
    }
}
