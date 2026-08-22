//
//  SecurityEventRow.swift
//  octosentry
//

import AppKit
import SwiftUI

struct SecurityEventRow: View {
    let event: SecurityEvent
    var isHidden = false
    var snoozedUntil: Date?
    var onMarkSeen: () -> Void
    var onDismiss: () -> Void = {}
    var onSnooze: (SnoozeDuration) -> Void = { _ in }
    var onRestore: () -> Void = {}

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            Button {
                NSWorkspace.shared.open(event.detailURL)
            } label: {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(event.nativeSeverityLabel.uppercased())
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(event.severity.color)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(event.severity.color.opacity(0.18), in: Capsule())

                        Text(event.source.displayName)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.secondary.opacity(0.15), in: Capsule())

                        Text(event.repoFullName)
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if let hiddenLabel {
                            Text(hiddenLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(.secondary.opacity(0.15), in: Capsule())
                        }

                        Text(Self.relativeFormatter.localizedString(for: event.createdAt, relativeTo: .now))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Text(event.summary)
                        .font(.callout)
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isHidden {
                Button(action: onRestore) {
                    Image(systemName: "arrow.uturn.backward.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Bring back")
                .padding(.top, 12)
                .padding(.trailing, 10)
            } else {
                Button(action: onMarkSeen) {
                    Image(systemName: "checkmark.circle")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Mark as seen")
                .padding(.top, 12)
                .padding(.trailing, 6)

                Menu {
                    Menu("Snooze") {
                        ForEach(SnoozeDuration.allCases, id: \.self) { duration in
                            Button(duration.displayName) { onSnooze(duration) }
                        }
                    }
                    Button("Dismiss", action: onDismiss)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
                .foregroundStyle(.secondary)
                .help("Snooze or dismiss")
                .padding(.top, 10)
                .padding(.trailing, 10)
            }
        }
    }

    private var hiddenLabel: String? {
        guard isHidden else { return nil }
        guard let snoozedUntil else { return "Dismissed" }
        return "Snoozed until \(snoozedUntil.formatted(date: .abbreviated, time: .shortened))"
    }
}

#Preview {
    SecurityEventRow(
        event: SecurityEvent(
            id: "preview-1",
            source: .dependabot,
            repoFullName: "krazywarez/octosentry",
            severity: .critical,
            nativeSeverityLabel: "Critical",
            summary: "Denial of service in some-package",
            detailURL: URL(string: "https://github.com")!,
            createdAt: .now.addingTimeInterval(-3600 * 26),
            updatedAt: .now,
            seenLocally: false
        ),
        onMarkSeen: {}
    )
}
