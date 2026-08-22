//
//  GitHubHost.swift
//  octosentry
//
//  Which GitHub a token talks to. github.com and GitHub Enterprise Server
//  differ in more than a hostname: GHES puts the REST API under /api/v3 on
//  the same host rather than on a separate api. domain, and its device flow
//  needs an OAuth app registered by an instance admin, so octosentry's own
//  client ID doesn't apply.
//
//  Host is a property of an account (#19), not a global setting — someone
//  can reasonably watch repos on github.com and on their employer's GHES at
//  the same time.
//

import Foundation

nonisolated struct GitHubHost: Codable, Equatable, Hashable {
    /// nil means github.com. Otherwise the GHES web host, without a scheme.
    var host: String?
    /// Required for GHES; github.com uses octosentry's registered app.
    var clientID: String?

    static let dotCom = GitHubHost(host: nil, clientID: nil)

    /// Accepts what a user is likely to paste — with or without a scheme,
    /// with or without a trailing slash or path.
    init(host: String?, clientID: String?) {
        self.host = host.flatMap(Self.normalize)
        let trimmedClientID = clientID?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.clientID = (trimmedClientID?.isEmpty == false) ? trimmedClientID : nil
    }

    private static func normalize(_ raw: String) -> String? {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for prefix in ["https://", "http://"] where value.hasPrefix(prefix) {
            value.removeFirst(prefix.count)
        }
        if let slash = value.firstIndex(of: "/") {
            value = String(value[value.startIndex..<slash])
        }
        guard !value.isEmpty, value != "github.com" else { return nil }
        return value
    }

    var isDotCom: Bool { host == nil }

    var displayName: String { host ?? "github.com" }

    /// GHES serves the REST API from the same host under /api/v3.
    var apiBaseURL: URL {
        guard let host else { return URL(string: "https://api.github.com")! }
        return URL(string: "https://\(host)/api/v3")!
    }

    var webBaseURL: URL {
        URL(string: "https://\(host ?? "github.com")")!
    }

    var deviceCodeURL: URL {
        webBaseURL.appendingPathComponent("login/device/code")
    }

    var accessTokenURL: URL {
        webBaseURL.appendingPathComponent("login/oauth/access_token")
    }
}
