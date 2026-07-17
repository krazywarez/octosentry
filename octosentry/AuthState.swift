//
//  AuthState.swift
//  octosentry
//

import Foundation

nonisolated enum AuthState {
    case signedOut
    case awaitingAuthorization(userCode: String, verificationURL: URL)
    case signedIn
}
