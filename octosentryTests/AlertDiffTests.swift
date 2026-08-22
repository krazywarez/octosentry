//
//  AlertDiffTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct AlertDiffTests {

    private let repo = "octocat/hello-world"

    private func fetched(_ ids: [String], severity: SecurityEventSeverity = .high) -> [String: [SecurityEvent]] {
        [repo: ids.map { TestEvents.event(id: $0, repo: repo, severity: severity) }]
    }

    // MARK: - Seeding

    // The first sync of a busy repo is the case that would otherwise produce a
    // notification storm.
    @Test func firstEverSyncNotifiesAboutNothing() {
        let new = AlertDiff.newlyAppeared(
            in: fetched(["a", "b", "c"]),
            baseline: nil,
            minimumSeverity: .low
        )

        #expect(new.isEmpty)
    }

    @Test func newlyWatchedRepoIsSeededQuietly() {
        let new = AlertDiff.newlyAppeared(
            in: fetched(["a", "b"]),
            baseline: ["octocat/other": ["z"]],
            minimumSeverity: .low
        )

        #expect(new.isEmpty)
    }

    // MARK: - Detecting new alerts

    @Test func reportsOnlyAlertsMissingFromTheBaseline() {
        let new = AlertDiff.newlyAppeared(
            in: fetched(["a", "b", "c"]),
            baseline: [repo: ["a", "b"]],
            minimumSeverity: .low
        )

        #expect(new.map(\.id) == ["c"])
    }

    @Test func reportsNothingWhenTheFeedIsUnchanged() {
        let new = AlertDiff.newlyAppeared(
            in: fetched(["a", "b"]),
            baseline: [repo: ["a", "b"]],
            minimumSeverity: .low
        )

        #expect(new.isEmpty)
    }

    // An alert that disappeared and came back is reported again — GitHub
    // re-opening it is worth knowing about.
    @Test func reappearingAlertIsReportedAgain() {
        let new = AlertDiff.newlyAppeared(
            in: fetched(["a"]),
            baseline: [repo: ["b"]],
            minimumSeverity: .low
        )

        #expect(new.map(\.id) == ["a"])
    }

    // MARK: - Severity threshold

    @Test func respectsTheMinimumSeverityThreshold() {
        let events = [repo: [
            TestEvents.event(id: "low", repo: repo, severity: .low),
            TestEvents.event(id: "critical", repo: repo, severity: .critical),
        ]]

        let new = AlertDiff.newlyAppeared(in: events, baseline: [repo: []], minimumSeverity: .high)

        #expect(new.map(\.id) == ["critical"])
    }

    @Test func thresholdAdmitsAlertsExactlyAtTheFloor() {
        let new = AlertDiff.newlyAppeared(
            in: fetched(["a"], severity: .high),
            baseline: [repo: []],
            minimumSeverity: .high
        )

        #expect(new.map(\.id) == ["a"])
    }

    // MARK: - Ordering

    @Test func resultsAreOrderedBySeverityThenID() {
        let events = [
            "b/repo": [TestEvents.event(id: "2", repo: "b/repo", severity: .medium)],
            "a/repo": [
                TestEvents.event(id: "3", repo: "a/repo", severity: .critical),
                TestEvents.event(id: "1", repo: "a/repo", severity: .critical),
            ],
        ]
        let baseline = ["a/repo": Set<String>(), "b/repo": Set<String>()]

        let new = AlertDiff.newlyAppeared(in: events, baseline: baseline, minimumSeverity: .low)

        #expect(new.map(\.id) == ["1", "3", "2"])
    }

    // MARK: - Baseline maintenance

    @Test func baselineTakesFreshIDsForReposThatAnswered() {
        let baseline = AlertDiff.updatedBaseline(
            from: fetched(["a", "b"]),
            watchedRepos: [repo],
            previous: [repo: ["old"]]
        )

        #expect(baseline[repo] == ["a", "b"])
    }

    // The case that would otherwise re-announce everything after a blip.
    @Test func baselineKeepsEntriesForReposThatFailedToFetch() {
        let baseline = AlertDiff.updatedBaseline(
            from: [:],
            watchedRepos: [repo],
            previous: [repo: ["a", "b"]]
        )

        #expect(baseline[repo] == ["a", "b"])
    }

    @Test func baselineDropsUnwatchedRepos() {
        let baseline = AlertDiff.updatedBaseline(
            from: [:],
            watchedRepos: ["octocat/kept"],
            previous: ["octocat/kept": ["a"], "octocat/removed": ["b"]]
        )

        #expect(Set(baseline.keys) == ["octocat/kept"])
    }

    @Test func baselineStartsFromNothingWhenThereIsNoPrevious() {
        let baseline = AlertDiff.updatedBaseline(
            from: fetched(["a"]),
            watchedRepos: [repo],
            previous: nil
        )

        #expect(baseline == [repo: ["a"]])
    }

    // Seed once, then the same alerts are no longer new.
    @Test func seedingThenPollingReportsOnlyWhatArrivedAfterwards() {
        let firstPoll = fetched(["a", "b"])
        let seeded = AlertDiff.updatedBaseline(from: firstPoll, watchedRepos: [repo], previous: nil)
        #expect(AlertDiff.newlyAppeared(in: firstPoll, baseline: nil, minimumSeverity: .low).isEmpty)

        let secondPoll = fetched(["a", "b", "c"])
        let new = AlertDiff.newlyAppeared(in: secondPoll, baseline: seeded, minimumSeverity: .low)

        #expect(new.map(\.id) == ["c"])
    }
}
