//
//  SecurityEvent.swift
//  octosentry
//

import Foundation

nonisolated struct SecurityEvent: Identifiable, Codable, Sendable {
    let id: String
    let source: SecurityEventSource
    let repoFullName: String
    let severity: SecurityEventSeverity
    let nativeSeverityLabel: String
    let summary: String
    let detailURL: URL
    let createdAt: Date
    let updatedAt: Date
    var seenLocally: Bool
    /// Logins of the accounts whose token can see this alert. More than one
    /// when the same repo is watched under several identities.
    var accountLogins: [String] = []
}
