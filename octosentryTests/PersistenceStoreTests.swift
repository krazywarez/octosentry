//
//  PersistenceStoreTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct PersistenceStoreTests {

    /// Each test gets its own directory so none of them touch the real
    /// Application Support container.
    private func makeTemporaryDirectory() throws -> URL {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("octosentry-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    @Test func loadReturnsPlaceholderOnFirstLaunch() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let store = PersistenceStore(directory: directory)
        let state = await store.load()

        #expect(state.watchedRepos == PersistedState.placeholder.watchedRepos)
        #expect(await store.loadFailureMessage == nil)
    }

    @Test func savedStateSurvivesAReload() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let saved = PersistedState(
            watchedRepos: ["octocat/hello-world"],
            seenEventIDs: ["dependabot-octocat/hello-world-1"],
            lastFetchByRepo: ["octocat/hello-world": Date(timeIntervalSince1970: 1_785_000_000)],
            minimumSeverity: .high,
            hasRepoScope: true
        )
        await PersistenceStore(directory: directory).save(saved)

        let reloaded = await PersistenceStore(directory: directory).load()

        #expect(reloaded.watchedRepos == saved.watchedRepos)
        #expect(reloaded.seenEventIDs == saved.seenEventIDs)
        #expect(reloaded.lastFetchByRepo == saved.lastFetchByRepo)
        #expect(reloaded.minimumSeverity == saved.minimumSeverity)
        #expect(reloaded.hasRepoScope == saved.hasRepoScope)
    }

    // The failure that matters: state.json exists but won't decode. Falling
    // back to .placeholder is fine, overwriting the user's watch list on the
    // next save is not.
    @Test func unreadableStateIsKeptAndReported() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let stateURL = directory.appendingPathComponent("state.json")
        let original = Data(#"{"watchedRepos":["octocat/hello-world"],"#.utf8)
        try original.write(to: stateURL)

        let store = PersistenceStore(directory: directory)
        let state = await store.load()
        #expect(state.watchedRepos == PersistedState.placeholder.watchedRepos)

        let message = await store.loadFailureMessage
        #expect(message != nil)

        // The original bytes are still on disk under a different name...
        let preserved = try FileManager.default
            .contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasPrefix("state-unreadable-") }
        #expect(preserved.count == 1)
        let preservedName = try #require(preserved.first)
        #expect(message?.contains(preservedName) == true)
        #expect(try Data(contentsOf: directory.appendingPathComponent(preservedName)) == original)

        // ...and a later save doesn't clobber the preserved copy.
        await store.save(state)
        #expect(try Data(contentsOf: directory.appendingPathComponent(preservedName)) == original)
    }

    @Test func loadFailureIsClearedByASubsequentGoodLoad() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        try Data("not json".utf8).write(to: directory.appendingPathComponent("state.json"))

        let store = PersistenceStore(directory: directory)
        _ = await store.load()
        #expect(await store.loadFailureMessage != nil)

        await store.save(PersistedState.placeholder)
        _ = await store.load()
        #expect(await store.loadFailureMessage == nil)
    }
}
