//
//  AlertExportTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct AlertExportTests {

    private let events = [
        TestEvents.event(
            id: "a",
            source: .dependabot,
            repo: "octocat/hello-world",
            severity: .critical,
            summary: "Denial of service in some-package"
        ),
        TestEvents.event(
            id: "b",
            source: .secretScanning,
            repo: "octocat/spoon-knife",
            severity: .high,
            summary: "GitHub Personal Access Token"
        ),
    ]

    // MARK: - CSV

    @Test func csvStartsWithTheHeaderRow() {
        let lines = AlertExport.csv(events).components(separatedBy: "\r\n")

        #expect(lines.first == "Source,Repository,Severity,GitHub Severity,Summary,First Seen,URL")
    }

    @Test func csvWritesOneRowPerEventInOrder() throws {
        let lines = AlertExport.csv(events).components(separatedBy: "\r\n")

        try #require(lines.count == 3)
        #expect(lines[1].hasPrefix("Dependabot,octocat/hello-world,Critical,Critical,Denial of service in some-package,"))
        #expect(lines[2].hasPrefix("Secret Scanning,octocat/spoon-knife,High,High,GitHub Personal Access Token,"))
        #expect(lines[1].hasSuffix("https://github.com/octocat/hello-world/security/a"))
    }

    // The case worth being explicit about: a summary carrying every
    // character CSV cares about.
    @Test func csvQuotesAndEscapesAwkwardSummaries() throws {
        let awkward = [
            TestEvents.event(
                id: "x",
                summary: #"Contains a comma, a "quote", and a"# + "\nnewline"
            )
        ]

        // Records are CRLF-separated, so the field's embedded LF stays inside
        // the record rather than starting a new one.
        let records = AlertExport.csv(awkward).components(separatedBy: "\r\n")
        try #require(records.count == 2)

        let record = records[1]
        #expect(record.contains(#""Contains a comma, a ""quote"", and a"#))
        #expect(record.contains("\nnewline\""))
        // The quoted field opens right after the GitHub severity column.
        #expect(record.contains(#",High,"Contains"#))
    }

    @Test func csvLeavesOrdinaryFieldsUnquoted() {
        let plain = [TestEvents.event(id: "x", summary: "Nothing special here")]

        #expect(AlertExport.csv(plain).contains(",Nothing special here,"))
    }

    @Test func csvOfAnEmptyFeedIsJustTheHeader() {
        #expect(AlertExport.csv([]) == "Source,Repository,Severity,GitHub Severity,Summary,First Seen,URL")
    }

    @Test func csvUsesCRLFLineEndings() {
        #expect(AlertExport.csv(events).contains("\r\n"))
    }

    // MARK: - JSON

    @Test func jsonEncodesTheDocumentedFields() throws {
        let data = try AlertExport.json(events)
        let objects = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])

        try #require(objects.count == 2)

        let first = try #require(objects.first)
        #expect(Set(first.keys) == [
            "source", "repository", "severity", "githubSeverity", "summary", "firstSeen", "url",
        ])
        #expect(first["source"] as? String == "Dependabot")
        #expect(first["repository"] as? String == "octocat/hello-world")
        #expect(first["severity"] as? String == "Critical")
        #expect(first["summary"] as? String == "Denial of service in some-package")
        #expect(first["url"] as? String == "https://github.com/octocat/hello-world/security/a")
    }

    // Local triage state and the synthetic id are app internals.
    @Test func jsonOmitsInternalFields() throws {
        let json = try #require(String(data: try AlertExport.json(events), encoding: .utf8))

        #expect(!json.contains("seenLocally"))
        #expect(!json.contains("\"id\""))
        #expect(!json.contains("detailURL"))
    }

    @Test func jsonEncodesDatesAsISO8601() throws {
        let data = try AlertExport.json([TestEvents.event(id: "x")])
        let objects = try #require(try JSONSerialization.jsonObject(with: data) as? [[String: Any]])
        let firstSeen = try #require(objects.first?["firstSeen"] as? String)

        #expect(ISO8601DateFormatter().date(from: firstSeen) == TestEvents.referenceDate)
    }

    @Test func jsonOfAnEmptyFeedIsAnEmptyArray() throws {
        let objects = try JSONSerialization.jsonObject(with: try AlertExport.json([])) as? [Any]

        #expect(objects?.isEmpty == true)
    }

    // MARK: - Format plumbing

    @Test func dataMatchesTheFormatSpecificEncoders() throws {
        #expect(try AlertExport.data(events, format: .csv) == Data(AlertExport.csv(events).utf8))
        #expect(try AlertExport.data(events, format: .json) == (try AlertExport.json(events)))
    }

    @Test func filenameCarriesTheDateAndExtension() {
        let date = Date(timeIntervalSince1970: 1_785_000_000)

        #expect(AlertExport.filename(format: .csv, date: date).hasSuffix(".csv"))
        #expect(AlertExport.filename(format: .json, date: date).hasSuffix(".json"))
        #expect(AlertExport.filename(format: .csv, date: date).hasPrefix("octosentry-alerts-"))
    }

    // Export follows the feed, so filter and sort decide its contents.
    @Test func exportReflectsFilterAndSortApplied() throws {
        var filter = AlertFilter()
        filter.sources = [.secretScanning]
        let shown = AlertSortOrder.severity.sorted(filter.apply(to: events))

        let lines = AlertExport.csv(shown).components(separatedBy: "\r\n")

        try #require(lines.count == 2)
        #expect(lines[1].hasPrefix("Secret Scanning,"))
    }
}
