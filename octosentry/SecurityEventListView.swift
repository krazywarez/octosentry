//
//  SecurityEventListView.swift
//  octosentry
//

import AppKit
import SwiftUI

struct SecurityEventListView: View {
    var store: SecurityEventStore
    var authStore: AuthStore
    var updateStore: UpdateStore
    var isStandaloneWindow: Bool = false
    @State private var showingRepoManager = false
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if let release = updateStore.availableRelease {
                UpdateBanner(release: release)
            }
            Divider()
            if !authStore.isSignedIn {
                SignInView(authStore: authStore)
            } else if showingRepoManager {
                RepoManagerView(store: store, authStore: authStore)
            } else {
                content
            }
        }
        .task(id: authStore.isSignedIn) {
            guard authStore.isSignedIn else { return }
            await store.refresh()
            store.startPolling()
        }
        .task {
            await updateStore.checkForUpdate()
        }
    }

    private var header: some View {
        HStack {
            Text("Security Events")
                .font(.headline)

            if store.isLoading {
                ProgressView()
                    .controlSize(.small)
            }

            Spacer()

            if authStore.isSignedIn && !showingRepoManager {
                Picker("Minimum severity", selection: Binding(
                    get: { store.minimumSeverity },
                    set: { newValue in Task { await store.setMinimumSeverity(newValue) } }
                )) {
                    ForEach(SecurityEventSeverity.allCases, id: \.self) { severity in
                        Text(severity.displayName).tag(severity)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()

                Button {
                    Task { await store.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(store.isLoading)
            }

            if authStore.isSignedIn {
                if !isStandaloneWindow {
                    Button {
                        openWindow(id: SecurityEventWindow.id)
                    } label: {
                        Image(systemName: "macwindow")
                    }
                    .buttonStyle(.plain)
                    .help("Open in Window")
                }

                Button {
                    showingRepoManager.toggle()
                } label: {
                    Image(systemName: showingRepoManager ? "xmark.circle" : "gearshape")
                }
                .buttonStyle(.plain)
            }

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(12)
    }

    @ViewBuilder
    private var content: some View {
        if store.events.isEmpty && !store.errorMessages.isEmpty {
            StatusView(systemImage: "exclamationmark.triangle", tint: .orange, message: store.errorMessages.joined(separator: "\n\n"))
        } else if store.events.isEmpty && !store.isLoading {
            VStack(spacing: 8) {
                if store.totalFetchedCount > 0 {
                    StatusView(
                        systemImage: "line.3.horizontal.decrease.circle",
                        tint: .secondary,
                        message: "\(store.totalFetchedCount) alert(s) are below your minimum severity filter"
                    )
                } else {
                    StatusView(systemImage: "checkmark.shield", tint: .green, message: "No open security alerts")
                }
                if !store.unavailableNotices.isEmpty {
                    NoticeBanner(messages: store.unavailableNotices)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
            }
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    if !store.errorMessages.isEmpty {
                        ErrorBanner(messages: store.errorMessages)
                        Divider()
                    }
                    if !store.unavailableNotices.isEmpty {
                        NoticeBanner(messages: store.unavailableNotices)
                        Divider()
                    }
                    ForEach(store.events) { event in
                        SecurityEventRow(event: event) {
                            Task { await store.markSeen(event.id) }
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

private struct RepoManagerView: View {
    var store: SecurityEventStore
    var authStore: AuthStore
    @State private var newRepoText = ""
    @State private var isBrowsingRepos = false
    @State private var availableRepos: [String] = []
    @State private var isLoadingRepos = false
    @State private var browseErrorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Watched Repositories")
                .font(.subheadline.weight(.semibold))

            if store.watchedRepos.isEmpty {
                Text("No repos watched yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.watchedRepos, id: \.self) { repo in
                    HStack {
                        Text(repo)
                            .font(.callout)
                        Spacer()
                        Button {
                            Task { await store.removeRepo(repo) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Divider()

            if isBrowsingRepos {
                browsingContent
            } else {
                HStack {
                    TextField("owner/repo", text: $newRepoText)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(addRepo)

                    Button("Add", action: addRepo)
                        .disabled(newRepoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Button(action: startBrowsing) {
                    Label("Browse your repos", systemImage: "list.bullet")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }

            if let errorMessage = store.watchListErrorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            Spacer()

            Divider()

            Button("Sign Out") {
                authStore.signOut()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.red)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var browsingContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Your Repositories")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button {
                    isBrowsingRepos = false
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.plain)
            }

            if isLoadingRepos {
                ProgressView()
                    .controlSize(.small)
                    .frame(maxWidth: .infinity)
            } else if let browseErrorMessage {
                Text(browseErrorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            } else {
                let selectableRepos = availableRepos.filter { !store.watchedRepos.contains($0) }
                if selectableRepos.isEmpty {
                    Text("All visible repos are already watched.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(selectableRepos, id: \.self) { repo in
                                Button {
                                    Task { await store.addRepo(repo) }
                                    isBrowsingRepos = false
                                } label: {
                                    Text(repo)
                                        .font(.callout)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxHeight: 160)
                }
            }
        }
    }

    private func startBrowsing() {
        guard authStore.hasRepoAccess else {
            authStore.requestRepoAccess()
            return
        }
        isBrowsingRepos = true
        isLoadingRepos = true
        browseErrorMessage = nil
        Task {
            do {
                availableRepos = try await store.fetchAccessibleRepos()
            } catch {
                browseErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isLoadingRepos = false
        }
    }

    private func addRepo() {
        let text = newRepoText
        newRepoText = ""
        Task { await store.addRepo(text) }
    }
}

private struct UpdateBanner: View {
    let release: UpdateChecker.LatestRelease

    var body: some View {
        Button {
            NSWorkspace.shared.open(release.htmlURL)
        } label: {
            Label("Update available: \(release.version)", systemImage: "arrow.down.circle.fill")
                .font(.caption)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.blue)
        .padding(8)
        .background(.blue.opacity(0.1))
    }
}

private struct ErrorBanner: View {
    let messages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(messages, id: \.self) { message in
                Label(message, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.orange.opacity(0.1))
    }
}

private struct NoticeBanner: View {
    let messages: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(messages, id: \.self) { message in
                Label(message, systemImage: "info.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(.secondary.opacity(0.08))
    }
}

private struct StatusView: View {
    let systemImage: String
    let tint: Color
    let message: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(tint)
            Text(message)
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SecurityEventListView(store: SecurityEventStore(), authStore: AuthStore(), updateStore: UpdateStore())
        .frame(width: 380, height: 420)
}
