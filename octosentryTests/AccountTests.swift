//
//  AccountTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct AccountTests {

    // An install that already has a token must keep using the Keychain item
    // it's in — rewriting it at upgrade time risks stranding the token.
    @Test func theLegacyAccountPointsAtTheExistingKeychainItem() {
        let account = Account.legacy()

        #expect(account.keychainAccount == KeychainTokenStore.legacyAccount)
        #expect(account.id == 0)
        #expect(account.login.isEmpty)
    }

    @Test func newAccountsGetTheirOwnKeychainItem() {
        let first = Account.new(id: 1, login: "octocat", hasRepoScope: false)
        let second = Account.new(id: 2, login: "hubot", hasRepoScope: true)

        #expect(first.keychainAccount != second.keychainAccount)
        #expect(first.keychainAccount != KeychainTokenStore.legacyAccount)
        #expect(second.hasRepoScope)
    }

    @Test func displayNameFallsBackBeforeTheLoginIsKnown() {
        #expect(Account.legacy().displayName == "GitHub account")
        #expect(Account.new(id: 1, login: "octocat", hasRepoScope: false).displayName == "octocat")
    }

    @Test func roundTripsThroughCodable() throws {
        let account = Account.new(id: 7, login: "octocat", hasRepoScope: true)
        let decoded = try JSONDecoder().decode(Account.self, from: try JSONEncoder().encode(account))

        #expect(decoded == account)
    }

    @Test func watchedRepoRoundTripsThroughCodable() throws {
        let repo = WatchedRepo(fullName: "octocat/hello-world", accountID: 7)
        let decoded = try JSONDecoder().decode(WatchedRepo.self, from: try JSONEncoder().encode(repo))

        #expect(decoded == repo)
    }
}

struct MultiAccountFeedTests {

    private func event(_ id: String, repo: String = "octocat/hello-world", logins: [String]) -> SecurityEvent {
        var event = TestEvents.event(id: id, repo: repo)
        event.accountLogins = logins
        return event
    }

    // MARK: - Merging

    // The same alert reached through two identities is one alert.
    @Test func duplicateAlertsCollapseAndUnionTheirAttributions() {
        let merged = SecurityEventStore.merged([
            event("a", logins: ["octocat"]),
            event("a", logins: ["hubot"]),
        ])

        #expect(merged.count == 1)
        #expect(merged[0].accountLogins.sorted() == ["hubot", "octocat"])
    }

    @Test func mergingLeavesDistinctAlertsAlone() {
        let merged = SecurityEventStore.merged([
            event("a", logins: ["octocat"]),
            event("b", logins: ["octocat"]),
        ])

        #expect(merged.map(\.id) == ["a", "b"])
    }

    @Test func mergingPreservesInputOrder() {
        let merged = SecurityEventStore.merged([
            event("b", logins: ["octocat"]),
            event("a", logins: ["hubot"]),
            event("b", logins: ["hubot"]),
        ])

        #expect(merged.map(\.id) == ["b", "a"])
    }

    @Test func mergingDoesNotRepeatTheSameLogin() {
        let merged = SecurityEventStore.merged([
            event("a", logins: ["octocat"]),
            event("a", logins: ["octocat"]),
        ])

        #expect(merged[0].accountLogins == ["octocat"])
    }

    @Test func mergingAnEmptyFeedIsEmpty() {
        #expect(SecurityEventStore.merged([]).isEmpty)
    }

    // MARK: - Attribution

    // Attribution is noise unless a repo is genuinely reachable two ways.
    @Test func onlyReposWatchedUnderSeveralAccountsAreAttributed() {
        let watched = [
            WatchedRepo(fullName: "octocat/shared", accountID: 1),
            WatchedRepo(fullName: "octocat/shared", accountID: 2),
            WatchedRepo(fullName: "octocat/solo", accountID: 1),
        ]

        let attributed = SecurityEventStore.reposWatchedBySeveralAccounts(in: watched)

        #expect(attributed == ["octocat/shared"])
    }

    @Test func aRepoListedTwiceUnderOneAccountIsNotAttributed() {
        let watched = [
            WatchedRepo(fullName: "octocat/solo", accountID: 1),
            WatchedRepo(fullName: "octocat/solo", accountID: 1),
        ]

        #expect(SecurityEventStore.reposWatchedBySeveralAccounts(in: watched).isEmpty)
    }

    @Test func anEmptyWatchListAttributesNothing() {
        #expect(SecurityEventStore.reposWatchedBySeveralAccounts(in: []).isEmpty)
    }
}
