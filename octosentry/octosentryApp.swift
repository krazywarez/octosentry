//
//  octosentryApp.swift
//  octosentry
//
//  Created by cmc on 2026-07-17.
//

import SwiftUI

@main
struct octosentryApp: App {
    @State private var store = SecurityEventStore()
    @State private var authStore = AuthStore()

    var body: some Scene {
        MenuBarExtra("OctoSentry", systemImage: "shield.lefthalf.filled") {
            SecurityEventListView(store: store, authStore: authStore)
        }
        .menuBarExtraStyle(.window)
    }
}
