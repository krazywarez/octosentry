//
//  UpdateChecker.swift
//  octosentry
//
//  Polls this repo's own GitHub Releases API (spec §9) — no auto-install,
//  no Sparkle, just a link to the release page. Skipped entirely on the
//  Mac App Store build, detected at runtime via the presence of an App
//  Store receipt rather than a separate build configuration: same
//  outcome (this code never runs there) with far less project surface
//  than maintaining a second Xcode configuration/scheme just for this.
//

import Foundation

actor UpdateChecker {
    private let session: URLSession
    private let repoOwner = "zerolabsco"
    private let repoName = "octosentry"

    init(session: URLSession = .shared) {
        self.session = session
    }

    struct LatestRelease: Sendable {
        let version: String
        let htmlURL: URL
    }

    func fetchLatestRelease() async throws -> LatestRelease {
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw UpdateCheckError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw UpdateCheckError.requestFailed
        }

        let dto: GitHubReleaseDTO
        do {
            dto = try JSONDecoder().decode(GitHubReleaseDTO.self, from: data)
        } catch {
            throw UpdateCheckError.decodingFailed(error.localizedDescription)
        }

        guard let url = URL(string: dto.htmlUrl) else {
            throw UpdateCheckError.decodingFailed("Malformed release URL.")
        }
        return LatestRelease(version: dto.tagName, htmlURL: url)
    }
}

nonisolated struct GitHubReleaseDTO: Decodable {
    let tagName: String
    let htmlUrl: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlUrl = "html_url"
    }
}

nonisolated enum UpdateCheckError: Error, LocalizedError {
    case network(String)
    case requestFailed
    case decodingFailed(String)

    var errorDescription: String? {
        switch self {
        case .network(let message):
            "Network error checking for updates: \(message)"
        case .requestFailed:
            "Failed to check for updates."
        case .decodingFailed(let message):
            "Unexpected response checking for updates: \(message)"
        }
    }
}
