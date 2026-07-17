//
//  GitHubSecurityAPIClient.swift
//  octosentry
//
//  Fetches Dependabot, code scanning, and secret scanning alerts for a
//  single repo and normalizes them into SecurityEvent. Auth is a PAT read
//  by the caller from the GITHUB_TOKEN environment variable — a dev-only
//  shortcut ahead of the device authorization flow (spec §6, §13).
//

import Foundation

actor GitHubSecurityAPIClient {
    private let token: String
    private let session: URLSession
    private let baseURL = URL(string: "https://api.github.com")!

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    init(token: String, session: URLSession = .shared) {
        self.token = token
        self.session = session
    }

    func fetchDependabotAlerts(owner: String, repo: String) async throws -> [SecurityEvent] {
        let url = alertsURL(owner: owner, repo: repo, path: "dependabot/alerts")
        let dtos: [DependabotAlertDTO] = try await fetchAllPages(url: url)
        let repoFullName = "\(owner)/\(repo)"
        return dtos.map { dto in
            SecurityEvent(
                id: "dependabot-\(repoFullName)-\(dto.number)",
                source: .dependabot,
                repoFullName: repoFullName,
                severity: SeverityMapping.dependabot(dto.securityAdvisory.severity),
                nativeSeverityLabel: dto.securityAdvisory.severity.capitalized,
                summary: dto.securityAdvisory.summary,
                detailURL: dto.htmlUrl,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                seenLocally: false
            )
        }
    }

    func fetchCodeScanningAlerts(owner: String, repo: String) async throws -> [SecurityEvent] {
        let url = alertsURL(owner: owner, repo: repo, path: "code-scanning/alerts")
        let dtos: [CodeScanningAlertDTO] = try await fetchAllPages(url: url)
        let repoFullName = "\(owner)/\(repo)"
        return dtos.map { dto in
            SecurityEvent(
                id: "codeScanning-\(repoFullName)-\(dto.number)",
                source: .codeScanning,
                repoFullName: repoFullName,
                severity: SeverityMapping.codeScanning(
                    securitySeverityLevel: dto.rule.securitySeverityLevel,
                    ruleSeverity: dto.rule.severity
                ),
                nativeSeverityLabel: (dto.rule.securitySeverityLevel ?? dto.rule.severity ?? "unknown").capitalized,
                summary: dto.mostRecentInstance?.message?.text ?? dto.rule.description ?? dto.rule.id ?? "Code scanning alert",
                detailURL: dto.htmlUrl,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                seenLocally: false
            )
        }
    }

    func fetchSecretScanningAlerts(owner: String, repo: String) async throws -> [SecurityEvent] {
        let url = alertsURL(owner: owner, repo: repo, path: "secret-scanning/alerts")
        let dtos: [SecretScanningAlertDTO] = try await fetchAllPages(url: url)
        let repoFullName = "\(owner)/\(repo)"
        return dtos.map { dto in
            SecurityEvent(
                id: "secretScanning-\(repoFullName)-\(dto.number)",
                source: .secretScanning,
                repoFullName: repoFullName,
                severity: SeverityMapping.secretScanning(validity: dto.validity),
                nativeSeverityLabel: (dto.validity ?? "unknown").capitalized,
                summary: dto.secretTypeDisplayName,
                detailURL: dto.htmlUrl,
                createdAt: dto.createdAt,
                updatedAt: dto.updatedAt,
                seenLocally: false
            )
        }
    }

    private func alertsURL(owner: String, repo: String, path: String) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/repos/\(owner)/\(repo)/\(path)"
        components.queryItems = [
            URLQueryItem(name: "state", value: "open"),
            URLQueryItem(name: "per_page", value: "100"),
        ]
        return components.url!
    }

    /// Follows the `Link: rel="next"` header until GitHub stops returning one,
    /// since these endpoints paginate (default 30, up to 100 per page) rather
    /// than returning every open alert in one response.
    private func fetchAllPages<T: Decodable>(url: URL) async throws -> [T] {
        var results: [T] = []
        var nextURL: URL? = url
        while let currentURL = nextURL {
            let (data, response) = try await fetchData(url: currentURL)
            results += try decode(data)
            nextURL = nextPageURL(from: response)
        }
        return results
    }

    private func nextPageURL(from response: HTTPURLResponse) -> URL? {
        guard let linkHeader = response.value(forHTTPHeaderField: "Link") else { return nil }
        for part in linkHeader.components(separatedBy: ",") {
            let segments = part.components(separatedBy: ";").map { $0.trimmingCharacters(in: .whitespaces) }
            guard segments.count >= 2, segments[1] == "rel=\"next\"" else { continue }
            let urlString = segments[0].trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
            return URL(string: urlString)
        }
        return nil
    }

    private func fetchData(url: URL) async throws -> (data: Data, response: HTTPURLResponse) {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw GitHubAPIError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw GitHubAPIError.invalidResponse
        }

        switch httpResponse.statusCode {
        case 200:
            return (data, httpResponse)
        case 401:
            throw GitHubAPIError.unauthorized
        case 403:
            throw GitHubAPIError.forbidden
        case 404:
            throw GitHubAPIError.notFound
        case 429:
            throw GitHubAPIError.rateLimited
        default:
            throw GitHubAPIError.httpError(status: httpResponse.statusCode)
        }
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do {
            return try Self.decoder.decode(T.self, from: data)
        } catch {
            throw GitHubAPIError.decodingFailed(error.localizedDescription)
        }
    }
}
