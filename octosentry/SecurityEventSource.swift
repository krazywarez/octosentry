//
//  SecurityEventSource.swift
//  octosentry
//

import Foundation

enum SecurityEventSource: String, Codable, CaseIterable {
    case dependabot
    case codeScanning
    case secretScanning

    var displayName: String {
        switch self {
        case .dependabot: "Dependabot"
        case .codeScanning: "CodeQL"
        case .secretScanning: "Secret Scanning"
        }
    }
}
