//
//  SecurityEventListView.swift
//  octosentry
//

import AppKit
import SwiftUI

struct SecurityEventListView: View {
    var store: SecurityEventStore
    @State private var showingRepoManager = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            if showingRepoManager {
                RepoManagerView(store: store)
            } else {
                content
            }
        }
        .frame(width: 380, height: 420)
        .task {
            await store.refresh()
            store.startPolling()
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

            if !showingRepoManager {
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

            Button {
                showingRepoManager.toggle()
            } label: {
                Image(systemName: showingRepoManager ? "xmark.circle" : "gearshape")
            }
            .buttonStyle(.plain)

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
                        SecurityEventRow(event: event)
                        Divider()
                    }
                }
            }
        }
    }
}

private struct RepoManagerView: View {
    var store: SecurityEventStore
    @State private var newRepoText = ""

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

            HStack {
                TextField("owner/repo", text: $newRepoText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(addRepo)

                Button("Add", action: addRepo)
                    .disabled(newRepoText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let errorMessage = store.watchListErrorMessage {
                Text(errorMessage)
                    .font(.caption2)
                    .foregroundStyle(.red)
            }

            Spacer()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addRepo() {
        let text = newRepoText
        newRepoText = ""
        Task { await store.addRepo(text) }
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
    SecurityEventListView(store: SecurityEventStore())
}
