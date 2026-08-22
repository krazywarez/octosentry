//
//  PersistenceStore.swift
//  octosentry
//
//  Loads and saves PersistedState as JSON in the app's Application Support
//  container. No entitlement needed — sandboxed apps always get a private
//  Application Support directory in their own container.
//

import Foundation

actor PersistenceStore {
    private let fileURL: URL

    /// Set when state.json existed but could not be decoded. The unreadable
    /// file is moved aside rather than overwritten, so nothing is lost
    /// silently; the message names where it went.
    private(set) var loadFailureMessage: String?

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("octosentry", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("state.json")
    }

    func load() -> PersistedState {
        // No file at all is first launch, not a failure.
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return .placeholder
        }

        do {
            let data = try Data(contentsOf: fileURL)
            let state = try Self.decoder.decode(PersistedState.self, from: data)
            loadFailureMessage = nil
            return state
        } catch {
            // Falling back to .placeholder here means the next save writes a
            // default watch list over the user's. Preserve the file first.
            loadFailureMessage = preserveUnreadableState(error: error)
            return .placeholder
        }
    }

    func save(_ state: PersistedState) {
        guard let data = try? Self.encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func preserveUnreadableState(error: Error) -> String {
        let backupURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("state-unreadable-\(Int(Date().timeIntervalSince1970)).json")

        guard (try? FileManager.default.moveItem(at: fileURL, to: backupURL)) != nil else {
            return "Saved settings couldn't be read (\(error.localizedDescription))."
        }
        return "Saved settings couldn't be read (\(error.localizedDescription)). "
            + "The previous file was kept as \(backupURL.lastPathComponent); octosentry started from defaults."
    }
}
