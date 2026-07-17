//
//  DeviceAuthModels.swift
//  octosentry
//
//  Wire types for GitHub's OAuth 2.0 Device Authorization Grant
//  (RFC 8628): github.com/login/device/code and
//  github.com/login/oauth/access_token.
//

import Foundation

nonisolated struct DeviceCodeResponse: Decodable {
    let deviceCode: String
    let userCode: String
    let verificationUri: URL
    let expiresIn: Int
    let interval: Int

    enum CodingKeys: String, CodingKey {
        case deviceCode = "device_code"
        case userCode = "user_code"
        case verificationUri = "verification_uri"
        case expiresIn = "expires_in"
        case interval
    }
}

nonisolated struct AccessTokenResponse: Decodable {
    let accessToken: String?
    let error: String?
    let interval: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case error
        case interval
    }
}
