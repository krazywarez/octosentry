//
//  AuthStore.swift
//  octosentry
//
//  Drives the device authorization flow and mirrors whether a token is
//  currently in the Keychain. Replaces the GITHUB_TOKEN env var dev
//  shortcut (spec §13) with the real v1 auth flow (spec §6).
//

import Foundation
import Observation

@Observable
final class AuthStore {
    private(set) var state: AuthState
    private(set) var errorMessage: String?

    private let client = GitHubDeviceAuthClient()
    private var authorizationTask: Task<Void, Never>?

    init() {
        state = KeychainTokenStore.load() != nil ? .signedIn : .signedOut
    }

    var isSignedIn: Bool {
        if case .signedIn = state { return true }
        return false
    }

    func signIn() {
        guard authorizationTask == nil else { return }
        errorMessage = nil

        authorizationTask = Task {
            defer { authorizationTask = nil }
            do {
                let deviceCode = try await client.requestDeviceCode()
                state = .awaitingAuthorization(userCode: deviceCode.userCode, verificationURL: deviceCode.verificationUri)

                let token = try await client.pollForToken(
                    deviceCode: deviceCode.deviceCode,
                    interval: deviceCode.interval,
                    expiresIn: deviceCode.expiresIn
                )
                try KeychainTokenStore.save(token)
                state = .signedIn
            } catch {
                errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
                state = .signedOut
            }
        }
    }

    func signOut() {
        authorizationTask?.cancel()
        authorizationTask = nil
        KeychainTokenStore.delete()
        state = .signedOut
    }
}
