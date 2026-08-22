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

    var displayName: String {
        login.isEmpty ? "GitHub account" : login
    }

    /// The account an upgrading install already has a token for.
    static func legacy() -> Account {
        Account(
            id: 0,
            login: "",
            keychainAccount: KeychainTokenStore.legacyAccount,
            hasRepoScope: false
        )
    }

    static func new(id: Int, login: String, hasRepoScope: Bool) -> Account {
        Account(
            id: id,
            login: login,
            keychainAccount: "account-\(id)",
            hasRepoScope: hasRepoScope
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
