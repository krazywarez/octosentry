//
//  AlertExport.swift
//  octosentry
//
//  Serializes the feed for export. Takes whatever list it's given, which is
//  the already-filtered, already-sorted `events` from SecurityEventStore —
//  so an export matches what's on screen.
//
//  Both formats carry the same fields as SecurityEventRow, plus octosentry's
//  normalized severity: the native GitHub labels aren't comparable across
//  the three sources, so a spreadsheet can't rank on them alone.
//

import Foundation

nonisolated enum AlertExportFormat: String, CaseIterable, Hashable {
    case csv
    case json

    var fileExtension: String { rawValue }

    var displayName: String {
        switch self {
        case .csv: "CSV"
        case .json: "JSON"
        }
    }
}

nonisolated enum AlertExport {
    static let columns = [
        "Source", "Repository", "Severity", "GitHub Severity", "Summary", "First Seen", "URL",
    ]

    static func data(_ events: [SecurityEvent], format: AlertExportFormat) throws -> Data {
        switch format {
        case .csv: Data(csv(events).utf8)
        case .json: try json(events)
        }
    }

    static func filename(format: AlertExportFormat, date: Date = .now) -> String {
        let day = date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        return "octosentry-alerts-\(day).\(format.fileExtension)"
    }

    // MARK: - CSV

    /// RFC 4180: CRLF line endings, fields quoted when they contain a
    /// separator, a quote, or a line break, and embedded quotes doubled.
    static func csv(_ events: [SecurityEvent]) -> String {
        let rows = [columns] + events.map { event in
            [
                event.source.displayName,
                event.repoFullName,
                event.severity.displayName,
                event.nativeSeverityLabel,
                event.summary,
                event.createdAt.formatted(.iso8601),
                event.detailURL.absoluteString,
            ]
        }
        return rows.map { $0.map(escapeCSVField).joined(separator: ",") }.joined(separator: "\r\n")
    }

    private static func escapeCSVField(_ field: String) -> String {
        let needsQuoting = field.contains(",")
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        guard needsQuoting else { return field }
        return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    // MARK: - JSON

    static func json(_ events: [SecurityEvent]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(events.map(ExportedAlert.init))
    }

    /// A deliberate projection rather than encoding SecurityEvent directly:
    /// the wire type carries local triage state and a synthetic id that mean
    /// nothing outside the app.
    private struct ExportedAlert: Encodable {
        let source: String
        let repository: String
        let severity: String
        let githubSeverity: String
        let summary: String
        let firstSeen: Date
        let url: URL

        init(_ event: SecurityEvent) {
            source = event.source.displayName
            repository = event.repoFullName
            severity = event.severity.displayName
            githubSeverity = event.nativeSeverityLabel
            summary = event.summary
            firstSeen = event.createdAt
            url = event.detailURL
        }
    }
}
