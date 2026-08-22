//
//  SecurityEventListView.swift
//  octosentry
//

import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct SecurityEventListView: View {
    var store: SecurityEventStore
    var authStore: AuthStore
    var updateStore: UpdateStore
    var isStandaloneWindow: Bool = false
    @State private var showingRepoManager = false
    @State private var showingHistory = false
    @State private var exportErrorMessage: String?
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
            } else if showingHistory {
                AlertHistoryView(store: store)
            } else {
                filterBar
                Divider()
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
        .alert(
            "Export failed",
            isPresented: Binding(
                get: { exportErrorMessage != nil },
                set: { if !$0 { exportErrorMessage = nil } }
            ),
            presenting: exportErrorMessage
        ) { _ in
            Button("OK", role: .cancel) { exportErrorMessage = nil }
        } message: { message in
            Text(message)
        }
    }

    /// Writes exactly what the feed is showing — store.events is already
    /// filtered and sorted.
    private func export(_ format: AlertExportFormat) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = AlertExport.filename(format: format)
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [format == .csv ? .commaSeparatedText : .json]

        // The app is an accessory (LSUIElement), so it has to come forward or
        // the panel opens behind whatever is frontmost.
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try AlertExport.data(store.events, format: format).write(to: url, options: .atomic)
        } catch {
            exportErrorMessage = error.localizedDescription
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

            if authStore.isSignedIn && !showingRepoManager && !showingHistory {
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

                Menu {
                    ForEach(AlertExportFormat.allCases, id: \.self) { format in
                        Button("Export as \(format.displayName)…") { export(format) }
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .disabled(store.events.isEmpty)
                .help("Export the alerts currently shown")
            }

            if authStore.isSignedIn {
                if isStandaloneWindow {
                    Button {
                        showingHistory.toggle()
                    } label: {
                        Image(systemName: showingHistory ? "list.bullet" : "chart.xyaxis.line")
                    }
                    .buttonStyle(.plain)
                    .help(showingHistory ? "Back to alerts" : "Trends")
                } else {
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

    private var filterBar: some View {
        HStack(spacing: 8) {
            Menu {
                ForEach(SecurityEventSource.allCases, id: \.self) { source in
                    Toggle(source.displayName, isOn: binding(for: source))
                }
            } label: {
                FilterLabel(title: "Source", count: store.filter.sources.count)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Menu {
                if store.reposInFeed.isEmpty {
                    Text("No repos in the current feed")
                } else {
                    ForEach(store.reposInFeed, id: \.self) { repo in
                        Toggle(repo, isOn: binding(for: repo))
                    }
                }
            } label: {
                FilterLabel(title: "Repo", count: store.filter.repos.count)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .disabled(store.reposInFeed.isEmpty)

            Menu {
                Picker("Sort", selection: Binding(
                    get: { store.sortOrder },
                    set: { newValue in Task { await store.setSortOrder(newValue) } }
                )) {
                    ForEach(AlertSortOrder.allCases, id: \.self) { order in
                        Text(order.displayName).tag(order)
                    }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                FilterLabel(title: store.sortOrder.displayName, count: 0, systemImage: "arrow.up.arrow.down")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            Button {
                store.filter.showsHidden.toggle()
            } label: {
                FilterLabel(
                    title: "Hidden",
                    count: 0,
                    systemImage: store.filter.showsHidden ? "eye" : "eye.slash"
                )
                .foregroundStyle(store.filter.showsHidden ? Color.accentColor : .secondary)
            }
            .buttonStyle(.plain)
            .help("Show dismissed and snoozed alerts")

            Spacer()

            if store.filter.isActive {
                Button("Clear") {
                    store.filter = AlertFilter()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }

    private func binding(for source: SecurityEventSource) -> Binding<Bool> {
        Binding(
            get: { store.filter.sources.contains(source) },
            set: { isOn in
                if isOn {
                    store.filter.sources.insert(source)
                } else {
                    store.filter.sources.remove(source)
                }
            }
        )
    }

    private func binding(for repo: String) -> Binding<Bool> {
        Binding(
            get: { store.filter.repos.contains(repo) },
            set: { isOn in
                if isOn {
                    store.filter.repos.insert(repo)
                } else {
                    store.filter.repos.remove(repo)
                }
            }
        )
    }

    @ViewBuilder
    private var content: some View {
        if store.events.isEmpty && !store.errorMessages.isEmpty {
            StatusView(systemImage: "exclamationmark.triangle", tint: .orange, message: store.errorMessages.joined(separator: "\n\n"))
        } else if store.events.isEmpty && !store.isLoading {
            VStack(spacing: 8) {
                if store.filter.isActive && store.filteredOutCount > 0 {
                    StatusView(
                        systemImage: "line.3.horizontal.decrease.circle",
                        tint: .secondary,
                        message: "\(store.filteredOutCount) alert(s) hidden by the current filter"
                    )
                } else if store.totalFetchedCount > 0 {
                    StatusView(
                        systemImage: "line.3.horizontal.decrease.circle",
                        tint: .secondary,
                        message: "\(store.totalFetchedCount) alert(s) are below your minimum severity filter"
                    )
                } else if store.watchedRepos.isEmpty {
                    // "No open alerts" would be misleading when nothing is
                    // being watched in the first place.
                    StatusView(
                        systemImage: "plus.circle",
                        tint: .secondary,
                        message: "No repositories watched yet — add one from the gear menu"
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
                        SecurityEventRow(
                            event: event,
                            attribution: store.showsAttribution(for: event.repoFullName)
                                ? event.accountLogins.sorted().joined(separator: ", ")
                                : nil,
                            isHidden: store.triage.isHidden(event.id, now: .now),
                            snoozedUntil: store.triage.snoozedUntil(event.id, now: .now),
                            onMarkSeen: { Task { await store.markSeen(event.id) } },
                            onDismiss: { Task { await store.dismiss(event.id) } },
                            onSnooze: { duration in
                                Task { await store.snooze(event.id, until: duration.date(from: .now)) }
                            },
                            onRestore: { Task { await store.restore(event.id) } }
                        )
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
    @State private var addingToAccountID: Int?
    @State private var browsingAccount: Account?
    @State private var availableRepos: [String] = []
    @State private var isLoadingRepos = false
    @State private var browseErrorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(authStore.accounts) { account in
                    accountSection(account)
                    Divider()
                }

                Button {
                    authStore.addAccount()
                } label: {
                    Label("Add another account", systemImage: "person.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)

                EnterpriseSignInView(authStore: authStore)

                if let errorMessage = store.watchListErrorMessage {
                    Text(errorMessage)
                        .font(.caption2)
                        .foregroundStyle(.red)
                }

                Divider()

                Button("Sign Out of All Accounts") {
                    Task { await authStore.signOutAll() }
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func accountSection(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(account.displayName)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button("Sign out") {
                    Task { await authStore.signOut(account) }
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.red)
            }

            let repos = store.watchedRepos.filter { $0.accountID == account.id }
            if repos.isEmpty {
                Text("No repos watched under this account.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(repos, id: \.self) { watched in
                    HStack {
                        Text(watched.fullName)
                            .font(.callout)
                        Spacer()
                        Button {
                            Task { await store.removeRepo(watched) }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if browsingAccount == account {
                browsingContent(account)
            } else {
                HStack {
                    TextField("owner/repo", text: Binding(
                        get: { addingToAccountID == account.id ? newRepoText : "" },
                        set: { newRepoText = $0; addingToAccountID = account.id }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addRepo(to: account) }

                    Button("Add") { addRepo(to: account) }
                        .disabled(addingToAccountID != account.id
                            || newRepoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Button { startBrowsing(account) } label: {
                    Label("Browse repos", systemImage: "list.bullet")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundStyle(Color.accentColor)
            }
        }
    }

    @ViewBuilder
    private func browsingContent(_ account: Account) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Repositories")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button {
                    browsingAccount = nil
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
                let watched = Set(
                    store.watchedRepos.filter { $0.accountID == account.id }.map(\.fullName)
                )
                let selectableRepos = availableRepos.filter { !watched.contains($0) }
                if selectableRepos.isEmpty {
                    Text("All visible repos are already watched.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(selectableRepos, id: \.self) { repo in
                                Button {
                                    Task { await store.addRepo(repo, accountID: account.id) }
                                    browsingAccount = nil
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

    private func startBrowsing(_ account: Account) {
        guard account.hasRepoScope else {
            authStore.requestRepoAccess(host: account.host)
            return
        }
        browsingAccount = account
        isLoadingRepos = true
        browseErrorMessage = nil
        Task {
            do {
                availableRepos = try await store.fetchAccessibleRepos(for: account)
            } catch {
                browseErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
            isLoadingRepos = false
        }
    }

    private func addRepo(to account: Account) {
        let text = newRepoText
        newRepoText = ""
        addingToAccountID = nil
        Task { await store.addRepo(text, accountID: account.id) }
    }
}

/// Signing in to a GitHub Enterprise Server instance. Collapsed by default —
/// most people are on github.com, and GHES needs details they have to get
/// from an instance admin.
private struct EnterpriseSignInView: View {
    var authStore: AuthStore
    @State private var isExpanded = false
    @State private var hostText = ""
    @State private var clientIDText = ""

    private var host: GitHubHost {
        GitHubHost(host: hostText, clientID: clientIDText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                isExpanded.toggle()
            } label: {
                Label("Add a GitHub Enterprise account", systemImage: "building.2")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)

            if isExpanded {
                TextField("github.example.com", text: $hostText)
                    .textFieldStyle(.roundedBorder)
                TextField("OAuth app client ID", text: $clientIDText)
                    .textFieldStyle(.roundedBorder)

                Text("Device flow on Enterprise Server needs an OAuth app registered on the instance. Ask an admin for its client ID.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Button("Sign In") {
                    authStore.addAccount(host: host)
                    isExpanded = false
                    hostText = ""
                    clientIDText = ""
                }
                .disabled(host.isDotCom || host.clientID == nil)
            }
        }
    }
}

private struct FilterLabel: View {
    let title: String
    let count: Int
    var systemImage = "line.3.horizontal.decrease.circle"

    var body: some View {
        Label(count > 0 ? "\(title) (\(count))" : title, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(count > 0 ? Color.accentColor : .secondary)
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
