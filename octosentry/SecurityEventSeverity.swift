//
//  SecurityEventSeverity.swift
//  octosentry
//

import SwiftUI

nonisolated enum SecurityEventSeverity: Int, Codable, Comparable, CaseIterable, Hashable {
    case low
    case medium
    case high
    case critical

    static func < (lhs: SecurityEventSeverity, rhs: SecurityEventSeverity) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        case .critical: "Critical"
        }
    }

    var color: Color {
        switch self {
        case .low: .blue
        case .medium: .yellow
        case .high: .orange
        case .critical: .red
        }
    }
}
