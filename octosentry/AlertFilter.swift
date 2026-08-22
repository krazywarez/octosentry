//
//  AlertFilter.swift
//  octosentry
//
//  Per-session narrowing of the feed by source and repo. An empty set means
//  "no restriction" rather than "match nothing", so the default value shows
//  everything. Severity is not here: the minimum-severity threshold already
//  filters on it, and it stays a persisted floor because the badge and
//  notifications key off it.
//

import Foundation

nonisolated struct AlertFilter: Equatable {
    var sources: Set<SecurityEventSource> = []
    var repos: Set<String> = []

    /// Reveals dismissed and snoozed alerts so they can be brought back —
    /// without it, hiding an alert would be irreversible.
    var showsHidden = false

    var isActive: Bool {
        !sources.isEmpty || !repos.isEmpty || showsHidden
    }

    func matches(_ event: SecurityEvent) -> Bool {
        (sources.isEmpty || sources.contains(event.source))
            && (repos.isEmpty || repos.contains(event.repoFullName))
    }

    func apply(to events: [SecurityEvent]) -> [SecurityEvent] {
        isActive ? events.filter(matches) : events
    }
}
