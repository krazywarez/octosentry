//
//  AlertTriage.swift
//  octosentry
//
//  Local-only triage: what the user has hidden, and until when. octosentry
//  deep-links out to github.com to actually resolve an alert, so dismissing
//  here means "hide from my feed", not "dismiss on GitHub".
//
//  Dismiss and snooze are two shapes of one idea — an alert is hidden, either
//  forever or until a date — so they live in one type behind a single
//  isHidden check. "Seen" (#8) stays separate: it's an acknowledgement that
//  feeds the menu bar badge, not a visibility control.
//

import Foundation

nonisolated struct AlertTriage: Codable, Equatable {
    var dismissedEventIDs: Set<String> = []
    var snoozedUntilByEventID: [String: Date] = [:]

    func isHidden(_ eventID: String, now: Date) -> Bool {
        if dismissedEventIDs.contains(eventID) { return true }
        guard let until = snoozedUntilByEventID[eventID] else { return false }
        return until > now
    }

    func isDismissed(_ eventID: String) -> Bool {
        dismissedEventIDs.contains(eventID)
    }

    func snoozedUntil(_ eventID: String, now: Date) -> Date? {
        guard let until = snoozedUntilByEventID[eventID], until > now else { return nil }
        return until
    }

    mutating func dismiss(_ eventID: String) {
        snoozedUntilByEventID.removeValue(forKey: eventID)
        dismissedEventIDs.insert(eventID)
    }

    mutating func snooze(_ eventID: String, until: Date) {
        dismissedEventIDs.remove(eventID)
        snoozedUntilByEventID[eventID] = until
    }

    mutating func restore(_ eventID: String) {
        dismissedEventIDs.remove(eventID)
        snoozedUntilByEventID.removeValue(forKey: eventID)
    }

    /// Drops state that can no longer apply: alerts resolved upstream, and
    /// snoozes that have already elapsed. Without this the file grows for the
    /// life of the install.
    ///
    /// `presentEventIDs` must come from a poll where every watched repo
    /// answered — pruning against a partial fetch would forget that a repo's
    /// alerts were dismissed.
    func pruned(presentEventIDs: Set<String>, now: Date) -> AlertTriage {
        var pruned = self
        pruned.dismissedEventIDs = dismissedEventIDs.intersection(presentEventIDs)
        pruned.snoozedUntilByEventID = snoozedUntilByEventID.filter { eventID, until in
            presentEventIDs.contains(eventID) && until > now
        }
        return pruned
    }
}

nonisolated enum SnoozeDuration: String, CaseIterable, Hashable {
    case anHour
    case tomorrow
    case nextWeek

    var displayName: String {
        switch self {
        case .anHour: "For an hour"
        case .tomorrow: "Until tomorrow"
        case .nextWeek: "Until next week"
        }
    }

    /// Tomorrow and next week mean the start of that day, not "24 hours from
    /// now" — snoozing at 23:50 should not resurface the alert at midnight.
    func date(from now: Date, calendar: Calendar = .current) -> Date {
        switch self {
        case .anHour:
            now.addingTimeInterval(3600)
        case .tomorrow:
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now) ?? now)
        case .nextWeek:
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: 7, to: now) ?? now)
        }
    }
}
