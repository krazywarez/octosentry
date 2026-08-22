//
//  TestEvents.swift
//  octosentryTests
//

import Foundation
@testable import octosentry

enum TestEvents {
    static let referenceDate = Date(timeIntervalSince1970: 1_785_000_000)

    static func event(
        id: String,
        source: SecurityEventSource = .dependabot,
        repo: String = "octocat/hello-world",
        severity: SecurityEventSeverity = .high,
        summary: String = "A summary",
        ageInHours: Double = 0
    ) -> SecurityEvent {
        let createdAt = referenceDate.addingTimeInterval(-ageInHours * 3600)
        return SecurityEvent(
            id: id,
            source: source,
            repoFullName: repo,
            severity: severity,
            nativeSeverityLabel: severity.displayName,
            summary: summary,
            detailURL: URL(string: "https://github.com/\(repo)/security/\(id)")!,
            createdAt: createdAt,
            updatedAt: createdAt,
            seenLocally: false
        )
    }
}
