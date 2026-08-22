//
//  Account.swift
//  octosentry
//
//  A signed-in GitHub identity. The token itself stays in the Keychain;
//  `keychainAccount` is the item name it lives under.
//
//  Existing single-account installs keep the item they already have —
//  `KeychainTokenStore.legacyAccount` is a perfectly good name for one
//  account, and rewriting it at upgrade time would risk stranding a token to
//  gain nothing.
//

import Foundation

nonisolated struct Account: Codable, Equatable, Identifiable, Hashable {
    /// Stable across renames, unlike the login. Zero for an account carried
    /// over from a single-account install before its login was resolved.
    var id: Int
    var login: String
    var keychainAccount: String
    var hasRepoScope: Bool
    /// Which GitHub this account lives on. Absent in files written before
    /// Enterprise support, which means github.com.
    var host: GitHubHost = .dotCom

    enum CodingKeys: String, CodingKey {
        case id, login, keychainAccount, hasRepoScope, host
    }

    init(id: Int, login: String, keychainAccount: String, hasRepoScope: Bool, host: GitHubHost = .dotCom) {
        self.id = id
        self.login = login
        self.keychainAccount = keychainAccount
        self.hasRepoScope = hasRepoScope
        self.host = host
    }

    // Synthesized decoding ignores property defaults, so an account written
    // before Enterprise support would fail to decode and take the whole
    // state file down with it.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        login = try container.decode(String.self, forKey: .login)
        keychainAccount = try container.decode(String.self, forKey: .keychainAccount)
        hasRepoScope = try container.decode(Bool.self, forKey: .hasRepoScope)
        host = try container.decodeIfPresent(GitHubHost.self, forKey: .host) ?? .dotCom
    }

    var displayName: String {
        let name = login.isEmpty ? "GitHub account" : login
        return host.isDotCom ? name : "\(name) @ \(host.displayName)"
    }

    /// The account an upgrading install already has a token for.
    static func legacy() -> Account {
        Account(
            id: 0,
            login: "",
            keychainAccount: KeychainTokenStore.legacyAccount,
            hasRepoScope: false,
            host: .dotCom
        )
    }

    static func new(id: Int, login: String, hasRepoScope: Bool, host: GitHubHost = .dotCom) -> Account {
        // Ids are only unique within an instance, so a GHES account's
        // Keychain item is namespaced by host too.
        let suffix = host.isDotCom ? "\(id)" : "\(host.displayName)-\(id)"
        return Account(
            id: id,
            login: login,
            keychainAccount: "account-\(suffix)",
            hasRepoScope: hasRepoScope,
            host: host
        )
    }
}

/// A repo on the watch list, and the account whose token can see it. The same
/// repo can appear under more than one account; the feed merges those and
/// attributes them.
nonisolated struct WatchedRepo: Codable, Equatable, Hashable {
    var fullName: String
    /// Account id, or 0 for entries carried over from a single-account install.
    var accountID: Int
}
