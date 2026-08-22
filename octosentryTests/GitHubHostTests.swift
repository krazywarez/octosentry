//
//  GitHubHostTests.swift
//  octosentryTests
//

import Foundation
import Testing
@testable import octosentry

struct GitHubHostTests {

    // MARK: - github.com

    @Test func theDefaultIsGitHubDotCom() {
        #expect(GitHubHost.dotCom.isDotCom)
        #expect(GitHubHost.dotCom.displayName == "github.com")
        #expect(GitHubHost.dotCom.apiBaseURL.absoluteString == "https://api.github.com")
        #expect(GitHubHost.dotCom.webBaseURL.absoluteString == "https://github.com")
    }

    @Test func dotComKeepsItsExistingAuthEndpoints() {
        #expect(GitHubHost.dotCom.deviceCodeURL.absoluteString == "https://github.com/login/device/code")
        #expect(GitHubHost.dotCom.accessTokenURL.absoluteString == "https://github.com/login/oauth/access_token")
    }

    // Naming github.com explicitly is still github.com, not an enterprise host.
    @Test func namingGitHubDotComExplicitlyIsNotEnterprise() {
        #expect(GitHubHost(host: "github.com", clientID: "abc").isDotCom)
        #expect(GitHubHost(host: "https://github.com", clientID: "abc").isDotCom)
    }

    // MARK: - Enterprise Server

    // GHES serves the REST API from the same host under /api/v3, not from a
    // separate api. domain.
    @Test func enterpriseAPILivesUnderApiV3OnTheSameHost() {
        let host = GitHubHost(host: "github.example.com", clientID: "abc")

        #expect(host.apiBaseURL.absoluteString == "https://github.example.com/api/v3")
        #expect(host.webBaseURL.absoluteString == "https://github.example.com")
        #expect(!host.isDotCom)
    }

    @Test func enterpriseAuthEndpointsAreOnTheInstance() {
        let host = GitHubHost(host: "github.example.com", clientID: "abc")

        #expect(host.deviceCodeURL.absoluteString == "https://github.example.com/login/device/code")
        #expect(host.accessTokenURL.absoluteString == "https://github.example.com/login/oauth/access_token")
    }

    // MARK: - Normalizing what a user pastes

    @Test func aPastedURLIsReducedToItsHost() {
        for input in [
            "https://github.example.com",
            "http://github.example.com",
            "github.example.com/",
            "https://github.example.com/some/path",
            "  GitHub.Example.com  ",
        ] {
            #expect(GitHubHost(host: input, clientID: "abc").host == "github.example.com", "input: \(input)")
        }
    }

    @Test func anEmptyHostMeansGitHubDotCom() {
        #expect(GitHubHost(host: "", clientID: nil).isDotCom)
        #expect(GitHubHost(host: "   ", clientID: nil).isDotCom)
        #expect(GitHubHost(host: nil, clientID: nil).isDotCom)
    }

    @Test func anEmptyClientIDIsTreatedAsAbsent() {
        #expect(GitHubHost(host: "github.example.com", clientID: "").clientID == nil)
        #expect(GitHubHost(host: "github.example.com", clientID: "  ").clientID == nil)
        #expect(GitHubHost(host: "github.example.com", clientID: " abc ").clientID == "abc")
    }

    // MARK: - Persistence

    @Test func roundTripsThroughCodable() throws {
        for host in [GitHubHost.dotCom, GitHubHost(host: "github.example.com", clientID: "abc")] {
            let decoded = try JSONDecoder().decode(GitHubHost.self, from: try JSONEncoder().encode(host))
            #expect(decoded == host)
        }
    }

    // An account written before Enterprise support has no host field.
    @Test func anAccountWithoutAHostFieldDecodesAsGitHubDotCom() throws {
        let json = """
        {"id": 7, "login": "octocat", "keychainAccount": "account-7", "hasRepoScope": false}
        """

        let account = try JSONDecoder().decode(Account.self, from: Data(json.utf8))

        #expect(account.host == .dotCom)
        #expect(account.displayName == "octocat")
    }

    // MARK: - Accounts

    // Ids are only unique within an instance, so two accounts that happen to
    // share an id on different hosts must not share a Keychain item.
    @Test func sameIdOnDifferentHostsGetsDifferentKeychainItems() {
        let dotCom = Account.new(id: 7, login: "octocat", hasRepoScope: false)
        let enterprise = Account.new(
            id: 7,
            login: "octocat",
            hasRepoScope: false,
            host: GitHubHost(host: "github.example.com", clientID: "abc")
        )

        #expect(dotCom.keychainAccount != enterprise.keychainAccount)
    }

    @Test func enterpriseAccountsAreLabelledWithTheirHost() {
        let account = Account.new(
            id: 7,
            login: "octocat",
            hasRepoScope: false,
            host: GitHubHost(host: "github.example.com", clientID: "abc")
        )

        #expect(account.displayName == "octocat @ github.example.com")
    }
}
