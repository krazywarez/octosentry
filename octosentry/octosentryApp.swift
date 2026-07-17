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

    var body: some Scene {
        MenuBarExtra("OctoSentry", systemImage: "shield.lefthalf.filled") {
            SecurityEventListView(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
