//
//  AlertSortOrder.swift
//  octosentry
//
//  How the feed is ordered. Persisted (see PersistedState) because it's a
//  standing preference, unlike the source/repo filters which are per-session.
//

import Foundation

nonisolated enum AlertSortOrder: String, Codable, CaseIterable, Hashable {
    case severity
    case oldest
    case repo

    var displayName: String {
        switch self {
        case .severity: "Severity"
        case .oldest: "Oldest first"
        case .repo: "Repository"
        }
    }

    func sorted(_ events: [SecurityEvent]) -> [SecurityEvent] {
        switch self {
        case .severity:
            events.sorted { lhs, rhs in
                lhs.severity != rhs.severity
                    ? lhs.severity > rhs.severity
                    : lhs.createdAt > rhs.createdAt
            }
        case .oldest:
            events.sorted { $0.createdAt < $1.createdAt }
        case .repo:
            events.sorted { lhs, rhs in
                let order = lhs.repoFullName.localizedCaseInsensitiveCompare(rhs.repoFullName)
                guard order == .orderedSame else { return order == .orderedAscending }
                return lhs.severity != rhs.severity
                    ? lhs.severity > rhs.severity
                    : lhs.createdAt > rhs.createdAt
            }
        }
    }
}
