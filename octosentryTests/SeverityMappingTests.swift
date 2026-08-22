//
//  SeverityMappingTests.swift
//  octosentryTests
//

import Testing
@testable import octosentry

struct SeverityMappingTests {

    @Test func dependabotMapsGitHubVocabulary() {
        #expect(SeverityMapping.dependabot("critical") == .critical)
        #expect(SeverityMapping.dependabot("high") == .high)
        #expect(SeverityMapping.dependabot("moderate") == .medium)
        #expect(SeverityMapping.dependabot("medium") == .medium)
        #expect(SeverityMapping.dependabot("low") == .low)
    }

    @Test func dependabotIsCaseInsensitive() {
        #expect(SeverityMapping.dependabot("CRITICAL") == .critical)
        #expect(SeverityMapping.dependabot("Moderate") == .medium)
    }

    @Test func dependabotFallsBackToMediumOnUnknownSeverity() {
        #expect(SeverityMapping.dependabot("") == .medium)
        #expect(SeverityMapping.dependabot("catastrophic") == .medium)
    }

    @Test func codeScanningPrefersSecuritySeverityLevel() {
        // security_severity_level wins even when rule.severity disagrees.
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: "critical", ruleSeverity: "note") == .critical)
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: "high", ruleSeverity: "note") == .high)
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: "medium", ruleSeverity: "error") == .medium)
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: "low", ruleSeverity: "error") == .low)
    }

    @Test func codeScanningFallsBackToRuleSeverity() {
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: nil, ruleSeverity: "error") == .high)
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: nil, ruleSeverity: "warning") == .medium)
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: nil, ruleSeverity: "note") == .low)
    }

    @Test func codeScanningFallsBackToRuleSeverityWhenLevelIsUnrecognized() {
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: "unknown", ruleSeverity: "error") == .high)
    }

    @Test func codeScanningDefaultsToMediumWithNothingUsable() {
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: nil, ruleSeverity: nil) == .medium)
        #expect(SeverityMapping.codeScanning(securitySeverityLevel: "unknown", ruleSeverity: "unknown") == .medium)
    }

    @Test func secretScanningTreatsActiveSecretsAsCritical() {
        #expect(SeverityMapping.secretScanning(validity: "active") == .critical)
        #expect(SeverityMapping.secretScanning(validity: "ACTIVE") == .critical)
    }

    @Test func secretScanningTreatsEverythingElseAsHigh() {
        #expect(SeverityMapping.secretScanning(validity: nil) == .high)
        #expect(SeverityMapping.secretScanning(validity: "inactive") == .high)
        #expect(SeverityMapping.secretScanning(validity: "unknown") == .high)
    }
}
