//
//  UpdateStore.swift
//  octosentry
//

import Foundation
import Observation

@Observable
final class UpdateStore {
    private(set) var availableRelease: UpdateChecker.LatestRelease?

    private let checker = UpdateChecker()

    /// True for a Mac App Store build (has an App Store receipt), false for
    /// a direct DMG/Homebrew build. Runtime check rather than a build flag —
    /// see UpdateChecker.swift for why.
    var isMacAppStoreBuild: Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else { return false }
        return FileManager.default.fileExists(atPath: receiptURL.path)
    }

    func checkForUpdate() async {
        guard !isMacAppStoreBuild else { return }
        guard let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return }
        guard let latest = try? await checker.fetchLatestRelease() else { return }

        if Self.isNewer(latest.version, than: currentVersion) {
            availableRelease = latest
        }
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let candidateParts = versionComponents(candidate)
        let currentParts = versionComponents(current)
        let count = max(candidateParts.count, currentParts.count)

        for i in 0..<count {
            let candidatePart = i < candidateParts.count ? candidateParts[i] : 0
            let currentPart = i < currentParts.count ? currentParts[i] : 0
            if candidatePart != currentPart {
                return candidatePart > currentPart
            }
        }
        return false
    }

    private static func versionComponents(_ version: String) -> [Int] {
        var trimmed = version
        if trimmed.hasPrefix("v") {
            trimmed.removeFirst()
        }
        return trimmed.split(separator: ".").map { Int($0) ?? 0 }
    }
}
