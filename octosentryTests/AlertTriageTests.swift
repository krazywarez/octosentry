//
//  AlertTriageTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct AlertTriageTests {

    private let now = Date(timeIntervalSince1970: 1_785_000_000)
    private var later: Date { now.addingTimeInterval(3600) }
    private var earlier: Date { now.addingTimeInterval(-3600) }

    // MARK: - Dismiss

    @Test func dismissHidesAnAlert() {
        var triage = AlertTriage()
        triage.dismiss("a")

        #expect(triage.isHidden("a", now: now))
        #expect(triage.isDismissed("a"))
        #expect(!triage.isHidden("b", now: now))
    }

    @Test func dismissedAlertsStayHiddenIndefinitely() {
        var triage = AlertTriage()
        triage.dismiss("a")

        #expect(triage.isHidden("a", now: now.addingTimeInterval(60 * 60 * 24 * 365)))
    }

    // MARK: - Snooze

    @Test func snoozeHidesUntilItsDeadline() {
        var triage = AlertTriage()
        triage.snooze("a", until: later)

        #expect(triage.isHidden("a", now: now))
        #expect(triage.snoozedUntil("a", now: now) == later)
    }

    // The resurfacing behaviour: a later poll sees the deadline has passed.
    @Test func snoozeStopsHidingOnceItsDeadlinePasses() {
        var triage = AlertTriage()
        triage.snooze("a", until: later)

        #expect(!triage.isHidden("a", now: later.addingTimeInterval(1)))
        #expect(triage.snoozedUntil("a", now: later.addingTimeInterval(1)) == nil)
    }

    @Test func snoozeExactlyAtItsDeadlineIsNoLongerHidden() {
        var triage = AlertTriage()
        triage.snooze("a", until: later)

        #expect(!triage.isHidden("a", now: later))
    }

    // MARK: - The two are exclusive

    @Test func snoozingADismissedAlertReplacesTheDismissal() {
        var triage = AlertTriage()
        triage.dismiss("a")
        triage.snooze("a", until: later)

        #expect(!triage.isDismissed("a"))
        #expect(triage.isHidden("a", now: now))
        #expect(!triage.isHidden("a", now: later))
    }

    @Test func dismissingASnoozedAlertReplacesTheSnooze() {
        var triage = AlertTriage()
        triage.snooze("a", until: later)
        triage.dismiss("a")

        #expect(triage.isDismissed("a"))
        #expect(triage.snoozedUntil("a", now: now) == nil)
        #expect(triage.isHidden("a", now: later.addingTimeInterval(1)))
    }

    @Test func restoreClearsBothStates() {
        var triage = AlertTriage()
        triage.dismiss("a")
        triage.snooze("b", until: later)

        triage.restore("a")
        triage.restore("b")

        #expect(!triage.isHidden("a", now: now))
        #expect(!triage.isHidden("b", now: now))
    }

    // MARK: - Pruning

    // The case the issue calls out: an alert resolved on GitHub must not leave
    // local state behind forever.
    @Test func pruningDropsStateForAlertsGoneUpstream() {
        var triage = AlertTriage()
        triage.dismiss("resolved")
        triage.dismiss("still-open")
        triage.snooze("also-resolved", until: later)

        let pruned = triage.pruned(presentEventIDs: ["still-open"], now: now)

        #expect(pruned.dismissedEventIDs == ["still-open"])
        #expect(pruned.snoozedUntilByEventID.isEmpty)
    }

    @Test func pruningDropsElapsedSnoozes() {
        var triage = AlertTriage()
        triage.snooze("expired", until: earlier)
        triage.snooze("active", until: later)

        let pruned = triage.pruned(presentEventIDs: ["expired", "active"], now: now)

        #expect(Set(pruned.snoozedUntilByEventID.keys) == ["active"])
    }

    @Test func pruningKeepsStateForAlertsStillPresent() {
        var triage = AlertTriage()
        triage.dismiss("a")
        triage.snooze("b", until: later)

        let pruned = triage.pruned(presentEventIDs: ["a", "b"], now: now)

        #expect(pruned == triage)
    }

    @Test func pruningAnEmptyTriageIsEmpty() {
        let pruned = AlertTriage().pruned(presentEventIDs: ["a"], now: now)

        #expect(pruned == AlertTriage())
    }

    // MARK: - Persistence

    @Test func roundTripsThroughCodable() throws {
        var triage = AlertTriage()
        triage.dismiss("a")
        triage.snooze("b", until: later)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let decoded = try decoder.decode(AlertTriage.self, from: try encoder.encode(triage))

        #expect(decoded == triage)
    }
}

struct SnoozeDurationTests {

    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    // 2026-07-25T17:20:00Z
    private let now = Date(timeIntervalSince1970: 1_785_000_000)

    @Test func anHourIsAnHourLater() {
        #expect(SnoozeDuration.anHour.date(from: now, calendar: calendar) == now.addingTimeInterval(3600))
    }

    // Snoozing late at night shouldn't resurface the alert minutes later at
    // midnight, so "tomorrow" is the start of the next day.
    @Test func tomorrowIsTheStartOfTheNextDay() {
        let date = SnoozeDuration.tomorrow.date(from: now, calendar: calendar)
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)

        #expect(components.day == 26)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(date > now)
    }

    @Test func nextWeekIsTheStartOfTheDaySevenDaysOn() {
        let date = SnoozeDuration.nextWeek.date(from: now, calendar: calendar)
        let components = calendar.dateComponents([.month, .day, .hour], from: date)

        #expect(components.month == 8)
        #expect(components.day == 1)
        #expect(components.hour == 0)
    }

    @Test func everyDurationMovesForward() {
        for duration in SnoozeDuration.allCases {
            #expect(duration.date(from: now, calendar: calendar) > now)
            #expect(!duration.displayName.isEmpty)
        }
    }
}
