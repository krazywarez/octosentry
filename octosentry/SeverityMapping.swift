//
//  SeverityMapping.swift
//  octosentry
//
//  Normalizes each GitHub alert source's native severity vocabulary into
//  the shared SecurityEventSeverity scale. Kept as a single auditable
//  source file per the spec (§4) rather than scattered across the client.
//

import Foundation

nonisolated enum SeverityMapping {
    /// Dependabot alerts report CVSS-derived severity on the vulnerability object.
    static func dependabot(_ nativeSeverity: String) -> SecurityEventSeverity {
        switch nativeSeverity.lowercased() {
        case "critical": .critical
        case "high": .high
        case "moderate", "medium": .medium
        case "low": .low
        default: .medium
        }
    }

    /// Code scanning alerts expose `rule.security_severity_level` (CVSS-derived) when
    /// present, falling back to `rule.severity` (note/warning/error) otherwise.
    static func codeScanning(securitySeverityLevel: String?, ruleSeverity: String?) -> SecurityEventSeverity {
        if let securitySeverityLevel {
            switch securitySeverityLevel.lowercased() {
            case "critical": return .critical
            case "high": return .high
            case "medium": return .medium
            case "low": return .low
            default: break
            }
        }
        switch ruleSeverity?.lowercased() {
        case "error": return .high
        case "warning": return .medium
        case "note": return .low
        default: return .medium
        }
    }

    /// Secret scanning has no native severity field. Per spec: validated/active
    /// secrets are treated as critical, unvalidated ones as high.
    static func secretScanning(validity: String?) -> SecurityEventSeverity {
        switch validity?.lowercased() {
        case "active": .critical
        default: .high
        }
    }
}
