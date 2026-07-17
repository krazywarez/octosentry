//
//  GitHubAPIModels.swift
//  octosentry
//
//  Decodable wire types for the three GitHub REST alert endpoints. Kept
//  private to this file — GitHubSecurityAPIClient maps them into SecurityEvent.
//

import Foundation

nonisolated struct DependabotAlertDTO: Decodable {
    let number: Int
    let htmlUrl: URL
    let createdAt: Date
    let updatedAt: Date
    let securityAdvisory: SecurityAdvisory

    struct SecurityAdvisory: Decodable {
        let summary: String
        let severity: String
    }

    enum CodingKeys: String, CodingKey {
        case number
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case securityAdvisory = "security_advisory"
    }
}

nonisolated struct CodeScanningAlertDTO: Decodable {
    let number: Int
    let htmlUrl: URL
    let createdAt: Date
    let updatedAt: Date
    let rule: Rule
    let mostRecentInstance: MostRecentInstance?

    struct Rule: Decodable {
        let id: String?
        let description: String?
        let severity: String?
        let securitySeverityLevel: String?

        enum CodingKeys: String, CodingKey {
            case id
            case description
            case severity
            case securitySeverityLevel = "security_severity_level"
        }
    }

    struct MostRecentInstance: Decodable {
        let message: Message?

        struct Message: Decodable {
            let text: String?
        }
    }

    enum CodingKeys: String, CodingKey {
        case number
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case rule
        case mostRecentInstance = "most_recent_instance"
    }
}

nonisolated struct SecretScanningAlertDTO: Decodable {
    let number: Int
    let htmlUrl: URL
    let createdAt: Date
    let updatedAt: Date
    let secretTypeDisplayName: String
    let validity: String?

    enum CodingKeys: String, CodingKey {
        case number
        case htmlUrl = "html_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case secretTypeDisplayName = "secret_type_display_name"
        case validity
    }
}

nonisolated struct GitHubRepoDTO: Decodable {
    let fullName: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
    }
}
