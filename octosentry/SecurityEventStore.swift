//
//  SecurityEventStore.swift
//  octosentry
//
//  Holds the fetched event stream for the popover. MVP scope: one
//  hardcoded repo, in-memory only, PAT read from GITHUB_TOKEN (spec §13).
//
//  Each alert source is fetched independently so a problem with one
//  endpoint doesn't blank out the other two. A 403/404 on a single source
//  usually just means that alert type is disabled for the repo (or the
//  token lacks that one permission) — not a real failure — so those are
//  reported as quiet "unavailable" notices rather than alarming errors.
//

import Foundation
import Observation

@Observable
final class SecurityEventStore {
    private(set) var events: [SecurityEvent] = []
    private(set) var isLoading = false
    private(set) var errorMessages: [String] = []
    private(set) var unavailableNotices: [String] = []

    private let owner = "ccleberg"
    private let repo = "cleberg.net"

    func refresh() async {
        isLoading = true
        errorMessages = []
        unavailableNotices = []
        defer { isLoading = false }

        guard let token = ProcessInfo.processInfo.environment["GITHUB_TOKEN"], !token.isEmpty else {
            errorMessages = [GitHubAPIError.missingToken.errorDescription ?? "Missing GITHUB_TOKEN."]
            return
        }

        let client = GitHubSecurityAPIClient(token: token)

        async let dependabot = fetchSource(label: "Dependabot") {
            try await client.fetchDependabotAlerts(owner: self.owner, repo: self.repo)
        }
        async let codeScanning = fetchSource(label: "Code scanning") {
            try await client.fetchCodeScanningAlerts(owner: self.owner, repo: self.repo)
        }
        async let secretScanning = fetchSource(label: "Secret scanning") {
            try await client.fetchSecretScanningAlerts(owner: self.owner, repo: self.repo)
        }

        let outcomes = await [dependabot, codeScanning, secretScanning]

        var fetchedEvents: [SecurityEvent] = []
        var errors: [String] = []
        var notices: [String] = []
        for outcome in outcomes {
            switch outcome {
            case .events(let sourceEvents):
                fetchedEvents += sourceEvents
            case .unavailable(let label):
                notices.append("\(label) alerts aren't available for this repo (disabled, or token lacks that permission).")
            case .failed(let label, let message):
                errors.append("\(label): \(message)")
            }
        }

        events = fetchedEvents.sorted { lhs, rhs in
            lhs.severity != rhs.severity ? lhs.severity > rhs.severity : lhs.createdAt > rhs.createdAt
        }
        errorMessages = errors
        unavailableNotices = notices
    }

    private enum SourceOutcome {
        case events([SecurityEvent])
        case unavailable(label: String)
        case failed(label: String, message: String)
    }

    private func fetchSource(
        label: String,
        _ operation: () async throws -> [SecurityEvent]
    ) async -> SourceOutcome {
        do {
            return .events(try await operation())
        } catch GitHubAPIError.forbidden, GitHubAPIError.notFound {
            return .unavailable(label: label)
        } catch {
            let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            return .failed(label: label, message: description)
        }
    }
}
