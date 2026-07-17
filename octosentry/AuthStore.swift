//
//  AuthStore.swift
//  octosentry
//
//  Drives the device authorization flow and mirrors whether a token is
//  currently in the Keychain. Replaces the GITHUB_TOKEN env var dev
//  shortcut (spec §13) with the real v1 auth flow (spec §6).
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
    private(set) var hasRepoAccess = false

    private let client = GitHubDeviceAuthClient()
    private let persistenceStore = PersistenceStore()
    private var authorizationTask: Task<Void, Never>?

    init() {
        state = KeychainTokenStore.load() != nil ? .signedIn : .signedOut
        Task {
            hasRepoAccess = await persistenceStore.load().hasRepoScope
        }
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    func signIn() {
        beginAuthorization(scope: GitHubDeviceAuthClient.defaultScope)
    }

    /// Re-runs device auth with broader scope so the repo picker can list
    /// repos. Only called explicitly from the repo picker UI, never on
    /// the default sign-in path.
    func requestRepoAccess() {
        beginAuthorization(scope: GitHubDeviceAuthClient.repoAccessScope)
    }

    func signOut() {
        authorizationTask?.cancel()
        authorizationTask = nil
        KeychainTokenStore.delete()
        state = .signedOut
        hasRepoAccess = false
    }

    private func beginAuthorization(scope: String) {
        guard authorizationTask == nil else { return }
        errorMessage = nil

        authorizationTask = Task {
            defer { authorizationTask = nil }
            do {
                let deviceCode = try await client.requestDeviceCode(scope: scope)
                state = .awaitingAuthorization(userCode: deviceCode.userCode, verificationURL: deviceCode.verificationUri)

                let token = try await client.pollForToken(
                    deviceCode: deviceCode.deviceCode,
                    interval: deviceCode.interval,
                    expiresIn: deviceCode.expiresIn
                )
                try KeychainTokenStore.save(token)

                let grantedRepoScope = scope.contains("repo")
                var persisted = await persistenceStore.load()
                persisted.hasRepoScope = grantedRepoScope
                await persistenceStore.save(persisted)
                hasRepoAccess = grantedRepoScope

                state = .signedIn
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                // A failed re-auth (e.g. requestRepoAccess while already
                // signed in) shouldn't sign the user out of their existing
                // valid token — only reflect reality from the Keychain.
                state = KeychainTokenStore.load() != nil ? .signedIn : .signedOut
            }
        }
    }
}
