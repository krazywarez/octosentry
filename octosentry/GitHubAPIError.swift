//
//  GitHubAPIError.swift
//  octosentry
//

import Foundation

enum GitHubAPIError: Error, LocalizedError, Sendable {
    case missingToken
    case network(String)
    case invalidResponse
    case unauthorized
    case forbidden
    case notFound
    case rateLimited
    case httpError(status: Int)
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            "No GitHub token found in the GITHUB_TOKEN environment variable."
        case .network(let message):
            "Network error: \(message)"
        case .invalidResponse:
            "Received an unexpected response from GitHub."
        case .unauthorized:
            "GitHub rejected the token (401 Unauthorized)."
        case .forbidden:
            "Token lacks permission for this alert type (403 Forbidden)."
        case .notFound:
            "Repository or endpoint not found (404)."
        case .rateLimited:
            "GitHub API rate limit exceeded (429)."
        case .httpError(let status):
            "GitHub API returned HTTP \(status)."
        case .decodingFailed(let message):
            "Failed to parse GitHub API response: \(message)"
        }
    }
}
