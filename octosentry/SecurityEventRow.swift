//
//  SecurityEventRow.swift
//  octosentry
//

import AppKit
import SwiftUI

struct SecurityEventRow: View {
    let event: SecurityEvent

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    var body: some View {
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
    }
}

#Preview {
    SecurityEventRow(event: SecurityEvent(
        id: "preview-1",
        source: .dependabot,
        repoFullName: "zerolabsco/octosentry",
        severity: .critical,
        nativeSeverityLabel: "Critical",
        summary: "Denial of service in some-package",
        detailURL: URL(string: "https://github.com")!,
        createdAt: .now.addingTimeInterval(-3600 * 26),
        updatedAt: .now,
        seenLocally: false
    ))
}
