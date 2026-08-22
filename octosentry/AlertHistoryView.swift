//
//  AlertHistoryView.swift
//  octosentry
//
//  Trends over time. Lives in the dedicated window (#10) rather than the
//  popover — the popover is 380pt wide and meant for at-a-glance triage.
//

import Charts
import SwiftUI

struct AlertHistoryView: View {
    var store: SecurityEventStore

    private static let windowLength: TimeInterval = 30 * 24 * 3600

    private var since: Date {
        Date().addingTimeInterval(-Self.windowLength)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summary
                Divider()
                openOverTime
                Divider()
                resolutionNote
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var summary: some View {
        HStack(alignment: .top, spacing: 24) {
            Statistic(label: "Open now", value: "\(store.history.currentlyOpenCount)")
            Statistic(label: "New (30d)", value: "\(store.history.openedCount(since: since))")
            Statistic(label: "Resolved (30d)", value: "\(store.history.resolvedCount(since: since))")
            Statistic(label: "Mean time to resolution", value: meanTimeToResolutionText)
        }
    }

    private var meanTimeToResolutionText: String {
        guard let interval = store.history.meanTimeToResolution else { return "—" }
        let days = interval / 86_400
        return days >= 1
            ? String(format: "%.1f d", days)
            : String(format: "%.0f h", interval / 3600)
    }

    @ViewBuilder
    private var openOverTime: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Open alerts over time")
                .font(.subheadline.weight(.semibold))

            let snapshots = store.history.openCountOverTime
            if snapshots.count < 2 {
                Text("Not enough history yet — octosentry records a snapshot every few hours.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                Chart(snapshots, id: \.recordedAt) { snapshot in
                    LineMark(
                        x: .value("Date", snapshot.recordedAt),
                        y: .value("Open", snapshot.openCount)
                    )
                    .interpolationMethod(.monotone)
                }
                .chartYScale(domain: .automatic(includesZero: true))
                .frame(height: 180)
            }
        }
    }

    private var resolutionNote: some View {
        Text("An alert counts as resolved once GitHub stops reporting it — the API gives no other signal, "
            + "so a repo losing access or leaving the watch list can look the same. Only polls where every "
            + "watched repo answered are recorded.")
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}

private struct Statistic: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
