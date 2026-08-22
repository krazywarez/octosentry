//
//  AlertFilterTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct AlertFilterTests {

    private let dependabotHello = TestEvents.event(id: "a", source: .dependabot, repo: "octocat/hello-world")
    private let codeScanningHello = TestEvents.event(id: "b", source: .codeScanning, repo: "octocat/hello-world")
    private let secretScanningSpoon = TestEvents.event(id: "c", source: .secretScanning, repo: "octocat/spoon-knife")

    private var allEvents: [SecurityEvent] {
        [dependabotHello, codeScanningHello, secretScanningSpoon]
    }

    @Test func emptyFilterIsInactiveAndMatchesEverything() {
        let filter = AlertFilter()

        #expect(filter.isActive == false)
        #expect(filter.apply(to: allEvents).map(\.id) == ["a", "b", "c"])
    }

    @Test func filtersBySource() {
        var filter = AlertFilter()
        filter.sources = [.dependabot]

        #expect(filter.isActive)
        #expect(filter.apply(to: allEvents).map(\.id) == ["a"])
    }

    @Test func sourceFilterUnionsSelectedSources() {
        var filter = AlertFilter()
        filter.sources = [.dependabot, .secretScanning]

        #expect(filter.apply(to: allEvents).map(\.id) == ["a", "c"])
    }

    @Test func filtersByRepo() {
        var filter = AlertFilter()
        filter.repos = ["octocat/spoon-knife"]

        #expect(filter.apply(to: allEvents).map(\.id) == ["c"])
    }

    // Source and repo intersect: an event has to satisfy both.
    @Test func sourceAndRepoAreCombinedWithAnd() {
        var filter = AlertFilter()
        filter.sources = [.dependabot]
        filter.repos = ["octocat/spoon-knife"]

        #expect(filter.apply(to: allEvents).isEmpty)

        filter.repos = ["octocat/hello-world"]
        #expect(filter.apply(to: allEvents).map(\.id) == ["a"])
    }

    @Test func showingHiddenCountsAsAnActiveFilter() {
        var filter = AlertFilter()
        #expect(filter.isActive == false)

        filter.showsHidden = true
        #expect(filter.isActive)
        // It reveals rows rather than removing them, so nothing is filtered out.
        #expect(filter.apply(to: allEvents).map(\.id) == ["a", "b", "c"])
    }

    @Test func filterPreservesInputOrder() {
        var filter = AlertFilter()
        filter.repos = ["octocat/hello-world"]

        #expect(filter.apply(to: allEvents.reversed()).map(\.id) == ["b", "a"])
    }
}
