//
//  GitHubDeviceAuthClient.swift
//  octosentry
//
//  Implements the GitHub device authorization flow (spec §6): request a
//  device/user code pair, show the user code, then poll until they've
//  authorized it on github.com/login/device. No client secret involved —
//  device flow for native apps doesn't use one.
//

import Foundation

actor GitHubDeviceAuthClient {
    // Public client identifier for the "octosentry" OAuth App (Device Flow enabled).
    // Not a secret — safe to embed in source.
    private let clientID = "Ov23li6tqaTghDc4IJYv"

    // Grants Dependabot/code scanning/secret scanning alert access. Classic OAuth
    // scopes have no read-only variant (unlike fine-grained PATs); this is the
    // narrowest scope GitHub offers for these three endpoints via OAuth Apps.
    private let scope = "security_events"

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func requestDeviceCode() async throws -> DeviceCodeResponse {
        let data = try await post(
            url: URL(string: "https://github.com/login/device/code")!,
            parameters: ["client_id": clientID, "scope": scope]
        )
        do {
            return try JSONDecoder().decode(DeviceCodeResponse.self, from: data)
        } catch {
            throw DeviceAuthError.decodingFailed(error.localizedDescription)
        }
    }

    /// Polls until the user authorizes, denies, or the device code expires.
    func pollForToken(deviceCode: String, interval: Int, expiresIn: Int) async throws -> String {
        var currentInterval = interval
        let deadline = Date().addingTimeInterval(TimeInterval(expiresIn))

        while Date() < deadline {
            try await Task.sleep(for: .seconds(currentInterval))
            try Task.checkCancellation()

            let data = try await post(
                url: URL(string: "https://github.com/login/oauth/access_token")!,
                parameters: [
                    "client_id": clientID,
                    "device_code": deviceCode,
                    "grant_type": "urn:ietf:params:oauth:grant-type:device_code",
                ]
            )

            let response: AccessTokenResponse
            do {
                response = try JSONDecoder().decode(AccessTokenResponse.self, from: data)
            } catch {
                throw DeviceAuthError.decodingFailed(error.localizedDescription)
            }

            if let token = response.accessToken {
                return token
            }

            switch response.error {
            case "authorization_pending":
                continue
            case "slow_down":
                currentInterval = response.interval ?? (currentInterval + 5)
            case "expired_token":
                throw DeviceAuthError.expired
            case "access_denied":
                throw DeviceAuthError.denied
            default:
                throw DeviceAuthError.unknown(response.error ?? "unrecognized response")
            }
        }
        throw DeviceAuthError.expired
    }

    private func post(url: URL, parameters: [String: String]) async throws -> Data {
        var components = URLComponents()
        components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data((components.percentEncodedQuery ?? "").utf8)

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeviceAuthError.network(error.localizedDescription)
        }

        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw DeviceAuthError.requestFailed
        }
        return data
    }
}

nonisolated enum DeviceAuthError: Error, LocalizedError {
    case network(String)
    case requestFailed
    case decodingFailed(String)
    case expired
    case denied
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .network(let message):
            "Network error: \(message)"
        case .requestFailed:
            "Failed to reach GitHub."
        case .decodingFailed(let message):
            "Unexpected response from GitHub: \(message)"
        case .expired:
            "The sign-in code expired before it was used. Try again."
        case .denied:
            "Sign-in was denied on GitHub."
        case .unknown(let message):
            "GitHub sign-in failed: \(message)"
        }
    }
}
