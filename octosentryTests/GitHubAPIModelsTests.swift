//
//  GitHubAPIModelsTests.swift
//  octosentryTests
//
//  Decoding against recorded response bodies from the three alert
//  endpoints. Fields octosentry doesn't read are left in the fixtures on
//  purpose — decoding must tolerate them.
//

import Foundation
import Testing
@testable import octosentry

struct GitHubAPIModelsTests {

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static func iso8601(_ string: String) -> Date {
        ISO8601DateFormatter().date(from: string)!
    }

    // MARK: - Dependabot

    @Test func decodesDependabotAlerts() throws {
        let alerts = try Self.decoder.decode([DependabotAlertDTO].self, from: Data(Fixtures.dependabotAlerts.utf8))

        #expect(alerts.count == 2)

        let first = try #require(alerts.first)
        #expect(first.number == 4)
        #expect(first.htmlUrl.absoluteString == "https://github.com/octocat/hello-world/security/dependabot/4")
        #expect(first.securityAdvisory.summary == "Denial of service in some-package")
        #expect(first.securityAdvisory.severity == "high")
        #expect(first.createdAt == Self.iso8601("2026-06-21T22:12:22Z"))
        #expect(first.updatedAt == Self.iso8601("2026-06-22T13:10:00Z"))

        #expect(alerts[1].securityAdvisory.severity == "moderate")
    }

    // MARK: - Code scanning

    @Test func decodesCodeScanningAlertWithSecuritySeverity() throws {
        let alerts = try Self.decoder.decode([CodeScanningAlertDTO].self, from: Data(Fixtures.codeScanningAlerts.utf8))

        let first = try #require(alerts.first)
        #expect(first.number == 12)
        #expect(first.rule.id == "js/sql-injection")
        #expect(first.rule.severity == "error")
        #expect(first.rule.securitySeverityLevel == "high")
        #expect(first.mostRecentInstance?.message?.text == "This query depends on a user-provided value.")
    }

    // A rule with no security_severity_level and no instance message is the
    // case that drives the summary and severity fallbacks in the client.
    @Test func decodesCodeScanningAlertWithNullsAndNoInstance() throws {
        let alerts = try Self.decoder.decode([CodeScanningAlertDTO].self, from: Data(Fixtures.codeScanningAlerts.utf8))

        let second = try #require(alerts.dropFirst().first)
        #expect(second.rule.securitySeverityLevel == nil)
        #expect(second.rule.severity == "warning")
        #expect(second.rule.description == "Unused variable")
        #expect(second.mostRecentInstance == nil)
    }

    // MARK: - Secret scanning

    @Test func decodesSecretScanningAlerts() throws {
        let alerts = try Self.decoder.decode([SecretScanningAlertDTO].self, from: Data(Fixtures.secretScanningAlerts.utf8))

        #expect(alerts.count == 2)

        let first = try #require(alerts.first)
        #expect(first.number == 2)
        #expect(first.secretTypeDisplayName == "GitHub Personal Access Token")
        #expect(first.validity == "active")

        // validity is absent on providers GitHub can't check.
        #expect(alerts[1].validity == nil)
        #expect(alerts[1].secretTypeDisplayName == "Generic API Key")
    }

    // MARK: - Repos

    @Test func decodesAccessibleRepos() throws {
        let repos = try Self.decoder.decode([GitHubRepoDTO].self, from: Data(Fixtures.userRepos.utf8))

        #expect(repos.map(\.fullName) == ["octocat/hello-world", "octocat/spoon-knife"])
    }

    // MARK: - Empty responses

    @Test func decodesAnEmptyAlertList() throws {
        let empty = Data("[]".utf8)

        #expect(try Self.decoder.decode([DependabotAlertDTO].self, from: empty).isEmpty)
        #expect(try Self.decoder.decode([CodeScanningAlertDTO].self, from: empty).isEmpty)
        #expect(try Self.decoder.decode([SecretScanningAlertDTO].self, from: empty).isEmpty)
    }
}
