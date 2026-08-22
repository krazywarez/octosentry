//
//  AuthStore.swift
//  octosentry
//
//  Drives the device authorization flow and tracks which GitHub identities
//  are signed in. Each account's token lives in its own Keychain item; this
//  holds only the account list, which is persisted alongside everything else.
//
//  Sign-in requests the minimal security_events scope by default.
//  Broader "repo" scope (needed to list repos for the picker, #15) is
//  only ever requested on demand via requestRepoAccess(), never by
//  default — a deliberate choice to keep the default blast radius small.
//

import Foundation
import Observation

@Observable
final class AuthStore {
    private(set) var state: AuthState
    private(set) var errorMessage: String?
    private(set) var accounts: [Account] = []

    private let persistenceStore = PersistenceStore()
    private var authorizationTask: Task<Void, Never>?

    init() {
        // Before the account list loads, fall back to whether the
        // single-account Keychain item exists, so an upgrading install isn't
        // shown a sign-in screen it doesn't need.
        state = KeychainTokenStore.load() != nil ? .signedIn : .signedOut
        Task { await loadAccounts() }
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    /// True when any signed-in account can list repos for the picker.
    var hasRepoAccess: Bool {
        accounts.contains(where: \.hasRepoScope)
    }

    func signIn(host: GitHubHost = .dotCom) {
        beginAuthorization(scope: GitHubDeviceAuthClient.defaultScope, host: host)
    }

    /// Adds another identity, optionally on a GitHub Enterprise Server
    /// instance. Same flow either way — GitHub decides which account
    /// authorizes the code.
    func addAccount(host: GitHubHost = .dotCom) {
        beginAuthorization(scope: GitHubDeviceAuthClient.defaultScope, host: host)
    }

    /// Re-runs device auth with broader scope so the repo picker can list
    /// repos. Only called explicitly from the repo picker UI, never on
    /// the default sign-in path.
    func requestRepoAccess(host: GitHubHost = .dotCom) {
        beginAuthorization(scope: GitHubDeviceAuthClient.repoAccessScope, host: host)
    }

    /// Signs out one account, leaving the others alone.
    func signOut(_ account: Account) async {
        KeychainTokenStore.delete(account: account.keychainAccount)

        var persisted = await persistenceStore.load()
        persisted.accounts.removeAll { $0.keychainAccount == account.keychainAccount }
        // Its repos can no longer be fetched, so drop them too.
        persisted.watchedRepos.removeAll { $0.accountID == account.id }
        await persistenceStore.save(persisted)

        accounts = persisted.accounts
        state = accounts.isEmpty ? .signedOut : .signedIn
    }

    func signOutAll() async {
        for account in accounts {
            KeychainTokenStore.delete(account: account.keychainAccount)
        }
        // Also clear the pre-multi-account item, in case no account row
        // referenced it.
        KeychainTokenStore.delete()

        var persisted = await persistenceStore.load()
        persisted.accounts = []
        persisted.watchedRepos = []
        await persistenceStore.save(persisted)

        authorizationTask?.cancel()
        authorizationTask = nil
        accounts = []
        state = .signedOut
    }

    /// Reconciles the stored account list with the Keychain, and adopts a
    /// token left by a single-account install.
    private func loadAccounts() async {
        var persisted = await persistenceStore.load()

        if persisted.accounts.isEmpty, KeychainTokenStore.load() != nil {
            var legacy = Account.legacy()
            legacy.hasRepoScope = persisted.hasRepoScope
            persisted.accounts = [legacy]
            await persistenceStore.save(persisted)
        }

        accounts = persisted.accounts
        state = accounts.isEmpty ? .signedOut : .signedIn

        await resolveMissingLogins()
    }

    /// An adopted legacy account has no login until we ask GitHub who it is.
    private func resolveMissingLogins() async {
        let unresolved = accounts.filter { $0.login.isEmpty }
        guard !unresolved.isEmpty else { return }

        var persisted = await persistenceStore.load()
        var changed = false

        for account in unresolved {
            guard let token = KeychainTokenStore.load(account: account.keychainAccount),
                  let user = try? await GitHubSecurityAPIClient(token: token, host: account.host).fetchCurrentUser(),
                  let index = persisted.accounts.firstIndex(where: { $0.keychainAccount == account.keychainAccount })
            else { continue }

            persisted.accounts[index].login = user.login
            // Keep the keychain item where it is; only the identity is filled in.
            if persisted.accounts[index].id == 0 {
                let oldID = persisted.accounts[index].id
                persisted.accounts[index].id = user.id
                for repoIndex in persisted.watchedRepos.indices where persisted.watchedRepos[repoIndex].accountID == oldID {
                    persisted.watchedRepos[repoIndex].accountID = user.id
                }
            }
            changed = true
        }

        if changed {
            await persistenceStore.save(persisted)
            accounts = persisted.accounts
        }
    }

    private func beginAuthorization(scope: String, host: GitHubHost) {
        guard authorizationTask == nil else { return }
        errorMessage = nil

        authorizationTask = Task {
            defer { authorizationTask = nil }
            do {
                let client = GitHubDeviceAuthClient(host: host)
                let deviceCode = try await client.requestDeviceCode(scope: scope)
                state = .awaitingAuthorization(userCode: deviceCode.userCode, verificationURL: deviceCode.verificationUri)

                let token = try await client.pollForToken(
                    deviceCode: deviceCode.deviceCode,
                    interval: deviceCode.interval,
                    expiresIn: deviceCode.expiresIn
                )
                try await register(token: token, grantedRepoScope: scope.contains("repo"), host: host)
                state = .signedIn
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                // A failed re-auth (e.g. requestRepoAccess while already
                // signed in) shouldn't sign the user out of their existing
                // valid token — only reflect reality.
                state = accounts.isEmpty && KeychainTokenStore.load() == nil ? .signedOut : .signedIn
            }
        }
    }

    /// Stores a freshly authorized token under its own Keychain item and
    /// records the account. Re-authorizing an account already present updates
    /// it in place rather than adding a duplicate.
    private func register(token: String, grantedRepoScope: Bool, host: GitHubHost) async throws {
        let user = try await GitHubSecurityAPIClient(token: token, host: host).fetchCurrentUser()

        var persisted = await persistenceStore.load()

        if let index = persisted.accounts.firstIndex(where: { $0.id == user.id && $0.host == host }) {
            persisted.accounts[index].login = user.login
            persisted.accounts[index].hasRepoScope = grantedRepoScope
            try KeychainTokenStore.save(token, account: persisted.accounts[index].keychainAccount)
        } else if host.isDotCom, let index = persisted.accounts.firstIndex(where: { $0.id == 0 }) {
            // The adopted single-account entry, now identified.
            let keychainAccount = persisted.accounts[index].keychainAccount
            persisted.accounts[index] = Account(
                id: user.id,
                login: user.login,
                keychainAccount: keychainAccount,
                hasRepoScope: grantedRepoScope,
                host: host
            )
            for repoIndex in persisted.watchedRepos.indices where persisted.watchedRepos[repoIndex].accountID == 0 {
                persisted.watchedRepos[repoIndex].accountID = user.id
            }
            try KeychainTokenStore.save(token, account: keychainAccount)
        } else {
            let account = Account.new(
                id: user.id,
                login: user.login,
                hasRepoScope: grantedRepoScope,
                host: host
            )
            try KeychainTokenStore.save(token, account: account.keychainAccount)
            persisted.accounts.append(account)
        }

        persisted.hasRepoScope = persisted.accounts.contains(where: \.hasRepoScope)
        await persistenceStore.save(persisted)
        accounts = persisted.accounts
    }
}
