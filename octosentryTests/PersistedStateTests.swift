//
//  PersistedStateTests.swift
//  octosentryTests
//
//  PersistedState is a file format: state.json written by one version has
//  to load in the next. These pin the current shape.
//

import Foundation
import Testing
@testable import octosentry

struct PersistedStateTests {

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    @Test func roundTripsEveryField() throws {
        let fetchedAt = Date(timeIntervalSince1970: 1_785_000_000)
        let original = PersistedState(
            watchedRepos: ["octocat/hello-world", "octocat/spoon-knife"],
            seenEventIDs: ["dependabot-octocat/hello-world-1", "codeScanning-octocat/spoon-knife-7"],
            lastFetchByRepo: ["octocat/hello-world": fetchedAt],
            minimumSeverity: .high,
            hasRepoScope: true,
            sortOrder: .repo,
            notifiedEventIDsByRepo: ["octocat/hello-world": ["dependabot-octocat/hello-world-1"]],
            triage: {
                var triage = AlertTriage()
                triage.dismiss("dependabot-octocat/hello-world-2")
                triage.snooze("codeScanning-octocat/spoon-knife-7", until: Date(timeIntervalSince1970: 1_786_000_000))
                return triage
            }()
        )

        let decoded = try Self.decoder.decode(
            PersistedState.self,
            from: Self.encoder.encode(original)
        )

        #expect(decoded.watchedRepos == original.watchedRepos)
        #expect(decoded.seenEventIDs == original.seenEventIDs)
        #expect(decoded.lastFetchByRepo == original.lastFetchByRepo)
        #expect(decoded.minimumSeverity == original.minimumSeverity)
        #expect(decoded.hasRepoScope == original.hasRepoScope)
        #expect(decoded.sortOrder == original.sortOrder)
        #expect(decoded.notifiedEventIDsByRepo == original.notifiedEventIDsByRepo)
        #expect(decoded.triage == original.triage)
    }

    @Test func encodesTheKeysOnDiskReadersDependOn() throws {
        let data = try Self.encoder.encode(PersistedState.placeholder)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )

        #expect(Set(object.keys) == [
            "watchedRepos", "seenEventIDs", "lastFetchByRepo", "minimumSeverity", "hasRepoScope", "sortOrder",
            "triage",
        ])
        // notifiedEventIDsByRepo is optional and nil on the placeholder, so it
        // encodes to nothing rather than a null.
        #expect(object["notifiedEventIDsByRepo"] == nil)
    }

    // A state.json written before hasRepoScope and sortOrder existed must still load.
    @Test func decodesLegacyStateWithoutRepoScopeOrSortOrder() throws {
        let legacy = """
        {
          "watchedRepos": ["octocat/hello-world"],
          "seenEventIDs": ["dependabot-octocat/hello-world-1"],
          "lastFetchByRepo": {"octocat/hello-world": "2026-08-01T12:00:00Z"},
          "minimumSeverity": 1
        }
        """

        let state = try Self.decoder.decode(PersistedState.self, from: Data(legacy.utf8))

        #expect(state.watchedRepos == ["octocat/hello-world"])
        #expect(state.seenEventIDs == ["dependabot-octocat/hello-world-1"])
        #expect(state.minimumSeverity == .medium)
        #expect(state.hasRepoScope == false)
        #expect(state.sortOrder == .severity)
        #expect(state.notifiedEventIDsByRepo == nil)
        #expect(state.triage == AlertTriage())
    }

    @Test func rejectsStateMissingARequiredField() {
        let missingWatchList = """
        {"seenEventIDs": [], "lastFetchByRepo": {}, "minimumSeverity": 0}
        """

        #expect(throws: (any Error).self) {
            try Self.decoder.decode(PersistedState.self, from: Data(missingWatchList.utf8))
        }
    }

    @Test func placeholderStartsWithNoSeenStateAndNoRepoScope() {
        #expect(PersistedState.placeholder.seenEventIDs.isEmpty)
        #expect(PersistedState.placeholder.lastFetchByRepo.isEmpty)
        #expect(PersistedState.placeholder.minimumSeverity == .low)
        #expect(PersistedState.placeholder.hasRepoScope == false)
        #expect(PersistedState.placeholder.sortOrder == .severity)
    }
}
