//
//  AlertHistory.swift
//  octosentry
//
//  A record of what the feed looked like over time, so the app can answer
//  "are we getting better or worse?" and "how long do alerts sit open?"
//
//  Two parts, because they answer different questions: periodic snapshots
//  give the open-count trend, and a per-alert lifecycle gives new-vs-resolved
//  and time to resolution.
//
//  Both are bounded. Snapshots are taken at most every six hours and kept for
//  90 days (≈360 entries); resolved lifecycles are dropped after 90 days.
//  Unbounded growth is the obvious failure mode for a per-poll time series,
//  and this lives in the same state.json as everything else.
//

import Foundation

nonisolated struct AlertHistory: Codable, Equatable {
    static let snapshotInterval: TimeInterval = 6 * 3600
    static let retention: TimeInterval = 90 * 24 * 3600

    var snapshots: [Snapshot] = []
    var lifecycles: [String: Lifecycle] = [:]

    nonisolated struct Snapshot: Codable, Equatable {
        var recordedAt: Date
        var openCount: Int
        /// Keyed by SecurityEventSource.rawValue / SecurityEventSeverity
        /// displayName so the file stays readable.
        var countsBySource: [String: Int]
        var countsBySeverity: [String: Int]
    }

    nonisolated struct Lifecycle: Codable, Equatable {
        var repoFullName: String
        var source: String
        var severity: SecurityEventSeverity
        /// When GitHub opened the alert, not when octosentry first saw it —
        /// otherwise time-to-resolution would be measured from install day.
        var openedAt: Date
        var lastSeenAt: Date
        /// First poll that no longer reported it. "No longer reported" is the
        /// only resolution signal the API gives.
        var resolvedAt: Date?
    }

    /// Folds one complete poll into the history.
    ///
    /// `events` must come from a poll where every watched repo answered:
    /// an alert missing because its repo errored is not a resolved alert.
    mutating func record(_ events: [SecurityEvent], at date: Date) {
        let presentIDs = Set(events.map(\.id))

        for event in events {
            if var lifecycle = lifecycles[event.id] {
                lifecycle.lastSeenAt = date
                lifecycle.severity = event.severity
                // Back from the dead: GitHub re-reported it.
                lifecycle.resolvedAt = nil
                lifecycles[event.id] = lifecycle
            } else {
                lifecycles[event.id] = Lifecycle(
                    repoFullName: event.repoFullName,
                    source: event.source.rawValue,
                    severity: event.severity,
                    openedAt: event.createdAt,
                    lastSeenAt: date,
                    resolvedAt: nil
                )
            }
        }

        for (id, var lifecycle) in lifecycles where !presentIDs.contains(id) && lifecycle.resolvedAt == nil {
            lifecycle.resolvedAt = date
            lifecycles[id] = lifecycle
        }

        appendSnapshot(for: events, at: date)
        prune(now: date)
    }

    private mutating func appendSnapshot(for events: [SecurityEvent], at date: Date) {
        if let last = snapshots.last, date.timeIntervalSince(last.recordedAt) < Self.snapshotInterval {
            return
        }

        var countsBySource: [String: Int] = [:]
        var countsBySeverity: [String: Int] = [:]
        for event in events {
            countsBySource[event.source.rawValue, default: 0] += 1
            countsBySeverity[event.severity.displayName, default: 0] += 1
        }

        snapshots.append(
            Snapshot(
                recordedAt: date,
                openCount: events.count,
                countsBySource: countsBySource,
                countsBySeverity: countsBySeverity
            )
        )
    }

    private mutating func prune(now: Date) {
        let cutoff = now.addingTimeInterval(-Self.retention)
        snapshots.removeAll { $0.recordedAt < cutoff }
        lifecycles = lifecycles.filter { _, lifecycle in
            guard let resolvedAt = lifecycle.resolvedAt else { return true }
            return resolvedAt >= cutoff
        }
    }

    // MARK: - Trends

    var openCountOverTime: [Snapshot] {
        snapshots.sorted { $0.recordedAt < $1.recordedAt }
    }

    func openedCount(since date: Date) -> Int {
        lifecycles.values.filter { $0.openedAt >= date }.count
    }

    func resolvedCount(since date: Date) -> Int {
        lifecycles.values.filter { ($0.resolvedAt ?? .distantFuture) >= date && $0.resolvedAt != nil }.count
    }

    var currentlyOpenCount: Int {
        lifecycles.values.filter { $0.resolvedAt == nil }.count
    }

    /// Mean time from GitHub opening an alert to octosentry no longer seeing
    /// it. nil when nothing has been resolved yet.
    var meanTimeToResolution: TimeInterval? {
        let durations = lifecycles.values.compactMap { lifecycle -> TimeInterval? in
            guard let resolvedAt = lifecycle.resolvedAt else { return nil }
            return resolvedAt.timeIntervalSince(lifecycle.openedAt)
        }
        guard !durations.isEmpty else { return nil }
        return durations.reduce(0, +) / Double(durations.count)
    }
}
