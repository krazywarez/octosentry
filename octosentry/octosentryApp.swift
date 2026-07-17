//
//  octosentryApp.swift
//  octosentry
//
//  Created by cmc on 2026-07-17.
//

import SwiftUI

enum SecurityEventWindow {
    static let id = "security-events-window"
}

@main
struct octosentryApp: App {
    @State private var store = SecurityEventStore()
    @State private var authStore = AuthStore()

    var body: some Scene {
        MenuBarExtra {
            SecurityEventListView(store: store, authStore: authStore)
                .frame(width: 380, height: 420)
        } label: {
            MenuBarIconView(criticalCount: store.unseenCriticalCount)
        }
        .menuBarExtraStyle(.window)

        Window("Security Events", id: SecurityEventWindow.id) {
            SecurityEventListView(store: store, authStore: authStore, isStandaloneWindow: true)
                .frame(minWidth: 420, minHeight: 480)
        }
    }
}

private struct MenuBarIconView: View {
    let criticalCount: Int

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: criticalCount > 0 ? "exclamationmark.shield.fill" : "shield.lefthalf.filled")

            if criticalCount > 0 {
                Text(criticalCount > 9 ? "9+" : "\(criticalCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(2)
                    .background(Circle().fill(.red))
                    .offset(x: 8, y: -6)
            }
        }
    }
}
