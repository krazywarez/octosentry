//
//  SignInView.swift
//  octosentry
//

import AppKit
import SwiftUI

struct SignInView: View {
    var authStore: AuthStore

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            switch authStore.state {
            case .signedOut:
                signedOutContent
            case .awaitingAuthorization(let userCode, let verificationURL):
                awaitingAuthorizationContent(userCode: userCode, verificationURL: verificationURL)
            case .signedIn:
                EmptyView()
            }

            if let errorMessage = authStore.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    private var signedOutContent: some View {
        VStack(spacing: 16) {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Sign in with GitHub to see your security alerts.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal)
            Button("Sign in with GitHub") {
                authStore.signIn()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private func awaitingAuthorizationContent(userCode: String, verificationURL: URL) -> some View {
        VStack(spacing: 12) {
            Text("Enter this code on GitHub")
                .font(.callout)
                .foregroundStyle(.secondary)

            Text(userCode)
                .font(.system(.title, design: .monospaced).weight(.bold))
                .textSelection(.enabled)

            HStack(spacing: 8) {
                Button("Copy Code") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(userCode, forType: .string)
                }
                Button("Open GitHub") {
                    NSWorkspace.shared.open(verificationURL)
                }
                .buttonStyle(.borderedProminent)
            }

            ProgressView()
                .controlSize(.small)
                .padding(.top, 4)
        }
    }
}

#Preview {
    SignInView(authStore: AuthStore())
}
