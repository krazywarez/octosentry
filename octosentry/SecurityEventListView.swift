//
//  SecurityEventListView.swift
//  octosentry
//

import AppKit
import SwiftUI

struct SecurityEventListView: View {
    var store: SecurityEventStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(width: 380, height: 420)
        .task {
            await store.refresh()
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

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.plain)
            .disabled(store.isLoading)

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
                StatusView(systemImage: "checkmark.shield", tint: .green, message: "No open security alerts")
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
