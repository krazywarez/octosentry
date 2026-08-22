//
//  AlertHistoryTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct AlertHistoryTests {

    private let day0 = Date(timeIntervalSince1970: 1_785_000_000)
    private func days(_ count: Double) -> TimeInterval { count * 86_400 }

    private func event(_ id: String, severity: SecurityEventSeverity = .high, openedDaysAgo: Double = 0) -> SecurityEvent {
        TestEvents.event(id: id, severity: severity, ageInHours: openedDaysAgo * 24)
    }

    // MARK: - Lifecycles

    @Test func recordingCreatesALifecyclePerAlert() {
        var history = AlertHistory()
        history.record([event("a"), event("b")], at: day0)

        #expect(Set(history.lifecycles.keys) == ["a", "b"])
        #expect(history.currentlyOpenCount == 2)
        #expect(history.lifecycles["a"]?.resolvedAt == nil)
    }

    // openedAt comes from GitHub, not from when octosentry first polled,
    // otherwise time-to-resolution starts at install day.
    @Test func lifecycleOpenedAtComesFromTheAlertNotThePoll() {
        var history = AlertHistory()
        let alert = event("a", openedDaysAgo: 10)
        history.record([alert], at: day0)

        #expect(history.lifecycles["a"]?.openedAt == alert.createdAt)
        #expect(history.lifecycles["a"]?.openedAt != day0)
    }

    @Test func anAlertThatDisappearsIsMarkedResolved() {
        var history = AlertHistory()
        history.record([event("a"), event("b")], at: day0)

        let later = day0.addingTimeInterval(days(1))
        history.record([event("a")], at: later)

        #expect(history.lifecycles["b"]?.resolvedAt == later)
        #expect(history.lifecycles["a"]?.resolvedAt == nil)
        #expect(history.currentlyOpenCount == 1)
    }

    @Test func resolutionTimeIsNotOverwrittenByLaterPolls() {
        var history = AlertHistory()
        history.record([event("a")], at: day0)
        let resolvedAt = day0.addingTimeInterval(days(1))
        history.record([], at: resolvedAt)
        history.record([], at: day0.addingTimeInterval(days(2)))

        #expect(history.lifecycles["a"]?.resolvedAt == resolvedAt)
    }

    @Test func aReReportedAlertBecomesOpenAgain() {
        var history = AlertHistory()
        history.record([event("a")], at: day0)
        history.record([], at: day0.addingTimeInterval(days(1)))
        history.record([event("a")], at: day0.addingTimeInterval(days(2)))

        #expect(history.lifecycles["a"]?.resolvedAt == nil)
        #expect(history.currentlyOpenCount == 1)
    }

    // MARK: - Snapshots

    @Test func theFirstPollRecordsASnapshot() {
        var history = AlertHistory()
        history.record([event("a", severity: .critical), event("b", severity: .low)], at: day0)

        #expect(history.snapshots.count == 1)
        let snapshot = history.snapshots[0]
        #expect(snapshot.openCount == 2)
        #expect(snapshot.countsBySeverity["Critical"] == 1)
        #expect(snapshot.countsBySeverity["Low"] == 1)
        #expect(snapshot.countsBySource["dependabot"] == 2)
    }

    // Polls run every 15 minutes; a snapshot per poll would be 96 a day.
    @Test func snapshotsAreRateLimited() {
        var history = AlertHistory()
        history.record([event("a")], at: day0)
        history.record([event("a")], at: day0.addingTimeInterval(900))
        history.record([event("a")], at: day0.addingTimeInterval(3600))

        #expect(history.snapshots.count == 1)
    }

    @Test func aSnapshotIsTakenOnceTheIntervalHasPassed() {
        var history = AlertHistory()
        history.record([event("a")], at: day0)
        history.record([event("a")], at: day0.addingTimeInterval(AlertHistory.snapshotInterval))

        #expect(history.snapshots.count == 2)
    }

    @Test func openCountOverTimeIsChronological() {
        var history = AlertHistory()
        for step in 0..<4 {
            history.record([event("a")], at: day0.addingTimeInterval(AlertHistory.snapshotInterval * Double(step)))
        }

        let dates = history.openCountOverTime.map(\.recordedAt)
        #expect(dates == dates.sorted())
    }

    // MARK: - Retention

    @Test func snapshotsOlderThanRetentionAreDropped() {
        var history = AlertHistory()
        history.record([event("a")], at: day0)
        history.record([event("a")], at: day0.addingTimeInterval(AlertHistory.retention + days(1)))

        #expect(history.snapshots.count == 1)
        #expect(history.snapshots[0].recordedAt > day0)
    }

    @Test func resolvedLifecyclesAreDroppedAfterRetentionButOpenOnesAreKept() {
        var history = AlertHistory()
        history.record([event("old"), event("survivor")], at: day0)
        history.record([event("survivor")], at: day0.addingTimeInterval(days(1)))

        // Long enough that "old" resolved outside the retention window.
        history.record([event("survivor")], at: day0.addingTimeInterval(AlertHistory.retention + days(2)))

        #expect(history.lifecycles["old"] == nil)
        #expect(history.lifecycles["survivor"] != nil)
    }

    // The growth question: a per-poll series must stay bounded.
    @Test func aYearOfPollingStaysBounded() {
        var history = AlertHistory()
        // Every 15 minutes for 365 days.
        let pollInterval: TimeInterval = 900
        var date = day0
        for _ in 0..<(365 * 96) {
            history.record([event("a")], at: date)
            date = date.addingTimeInterval(pollInterval)
        }

        let maximumSnapshots = Int(AlertHistory.retention / AlertHistory.snapshotInterval) + 2
        #expect(history.snapshots.count <= maximumSnapshots)
        #expect(history.snapshots.count > 0)
    }

    // MARK: - Trends

    @Test func newAndResolvedCountsAreWindowed() {
        var history = AlertHistory()
        history.record([event("old", openedDaysAgo: 60), event("recent", openedDaysAgo: 1)], at: day0)

        let since = day0.addingTimeInterval(-days(30))
        #expect(history.openedCount(since: since) == 1)
        #expect(history.resolvedCount(since: since) == 0)

        history.record([event("old", openedDaysAgo: 60)], at: day0.addingTimeInterval(days(1)))
        #expect(history.resolvedCount(since: since) == 1)
    }

    @Test func meanTimeToResolutionIsNilUntilSomethingResolves() {
        var history = AlertHistory()
        history.record([event("a")], at: day0)

        #expect(history.meanTimeToResolution == nil)
    }

    @Test func meanTimeToResolutionAveragesOpenToResolved() {
        var history = AlertHistory()
        // "a" opened 2 days before day0, "b" opened 4 days before.
        history.record([event("a", openedDaysAgo: 2), event("b", openedDaysAgo: 4)], at: day0)
        history.record([], at: day0)

        let mean = try? #require(history.meanTimeToResolution)
        // Resolved at day0, so durations are 2 and 4 days; mean is 3.
        #expect(mean != nil)
        if let mean {
            #expect(abs(mean - days(3)) < 1)
        }
    }

    @Test func meanTimeToResolutionIgnoresStillOpenAlerts() {
        var history = AlertHistory()
        history.record([event("resolved", openedDaysAgo: 2), event("open", openedDaysAgo: 100)], at: day0)
        history.record([event("open", openedDaysAgo: 100)], at: day0)

        if let mean = history.meanTimeToResolution {
            #expect(abs(mean - days(2)) < 1)
        } else {
            Issue.record("expected a mean time to resolution")
        }
    }

    // MARK: - Persistence

    @Test func roundTripsThroughCodable() throws {
        var history = AlertHistory()
        history.record([event("a", severity: .critical)], at: day0)
        history.record([], at: day0.addingTimeInterval(AlertHistory.snapshotInterval))

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(AlertHistory.self, from: try encoder.encode(history))

        #expect(decoded == history)
    }
}
