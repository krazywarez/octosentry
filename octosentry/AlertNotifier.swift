//
//  AlertNotifier.swift
//  octosentry
//
//  Posts a notification when a poll turns up alerts that weren't there
//  before. One notification per poll, never a burst: a single new alert
//  names it and deep-links to it, several collapse into a count that opens
//  the app. That keeps the first sync of a busy repo from filling
//  Notification Centre.
//
//  Authorization is requested lazily, the first time there is actually
//  something to say, rather than on launch. A denial is not an error —
//  polling carries on and the menu bar badge still updates.
//

import AppKit
import Foundation
import UserNotifications

@MainActor
final class AlertNotifier: NSObject {
    static let shared = AlertNotifier()

    private nonisolated static let detailURLKey = "detailURL"
    private nonisolated static let summaryCategory = "octosentry.summary"

    private let center = UNUserNotificationCenter.current()

    /// Posts at most one notification for `newEvents`. Does nothing when the
    /// list is empty or the user has declined notifications.
    ///
    /// The delegate is installed here rather than at launch on purpose:
    /// touching UNUserNotificationCenter from the App initializer stops the
    /// app launching at all. The cost is that a notification left over from a
    /// previous session, clicked before this app has posted anything, just
    /// activates octosentry instead of opening its alert.
    func notify(about newEvents: [SecurityEvent]) async {
        guard !newEvents.isEmpty else { return }

        center.delegate = self
        guard await requestAuthorizationIfNeeded() else { return }

        let content = UNMutableNotificationContent()
        content.sound = .default

        if let only = newEvents.first, newEvents.count == 1 {
            content.title = "\(only.severity.displayName) · \(only.source.displayName)"
            content.subtitle = only.repoFullName
            content.body = only.summary
            content.userInfo = [Self.detailURLKey: only.detailURL.absoluteString]
        } else {
            let highest = newEvents.map(\.severity).max() ?? .low
            content.title = "\(newEvents.count) new security alerts"
            content.body = "Highest severity: \(highest.displayName)"
            content.categoryIdentifier = Self.summaryCategory
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        try? await center.add(request)
    }

    private func requestAuthorizationIfNeeded() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        }
    }
}

extension AlertNotifier: UNUserNotificationCenterDelegate {
    /// Clicking a single-alert notification opens it on GitHub, matching what
    /// clicking the row does. The summary has no single target, so it opens
    /// the window instead.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let userInfo = response.notification.request.content.userInfo
        let urlString = userInfo[Self.detailURLKey] as? String

        await MainActor.run {
            if let urlString, let url = URL(string: urlString) {
                NSWorkspace.shared.open(url)
            } else {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    /// Show the banner even when octosentry is the frontmost app — the
    /// popover may well be closed.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
