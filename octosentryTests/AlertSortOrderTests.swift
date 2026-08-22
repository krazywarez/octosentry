//
//  AlertSortOrderTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct AlertSortOrderTests {

    // Deliberately out of order on every axis.
    private let events = [
        TestEvents.event(id: "old-low", repo: "zulu/repo", severity: .low, ageInHours: 500),
        TestEvents.event(id: "new-critical", repo: "alpha/repo", severity: .critical, ageInHours: 1),
        TestEvents.event(id: "old-critical", repo: "mike/repo", severity: .critical, ageInHours: 100),
        TestEvents.event(id: "new-medium", repo: "alpha/repo", severity: .medium, ageInHours: 2),
    ]

    @Test func severityOrdersHighestFirstThenNewest() {
        let sorted = AlertSortOrder.severity.sorted(events)

        #expect(sorted.map(\.id) == ["new-critical", "old-critical", "new-medium", "old-low"])
    }

    @Test func oldestOrdersLongestOpenFirst() {
        let sorted = AlertSortOrder.oldest.sorted(events)

        #expect(sorted.map(\.id) == ["old-low", "old-critical", "new-medium", "new-critical"])
    }

    @Test func repoGroupsByNameThenSeverityWithinRepo() {
        let sorted = AlertSortOrder.repo.sorted(events)

        #expect(sorted.map(\.repoFullName) == ["alpha/repo", "alpha/repo", "mike/repo", "zulu/repo"])
        // Within alpha/repo, critical sorts above medium.
        #expect(sorted.prefix(2).map(\.id) == ["new-critical", "new-medium"])
    }

    @Test func repoOrderIsCaseInsensitive() {
        let mixedCase = [
            TestEvents.event(id: "upper", repo: "Zulu/repo"),
            TestEvents.event(id: "lower", repo: "alpha/repo"),
        ]

        #expect(AlertSortOrder.repo.sorted(mixedCase).map(\.id) == ["lower", "upper"])
    }

    @Test func sortingNeverDropsOrDuplicatesEvents() {
        for order in AlertSortOrder.allCases {
            #expect(Set(order.sorted(events).map(\.id)) == Set(events.map(\.id)))
            #expect(order.sorted(events).count == events.count)
        }
    }

    @Test func sortingAnEmptyFeedIsEmpty() {
        for order in AlertSortOrder.allCases {
            #expect(order.sorted([]).isEmpty)
        }
    }

    // Raw values are persisted in state.json.
    @Test func rawValuesAreStable() {
        #expect(AlertSortOrder.severity.rawValue == "severity")
        #expect(AlertSortOrder.oldest.rawValue == "oldest")
        #expect(AlertSortOrder.repo.rawValue == "repo")
    }
}
