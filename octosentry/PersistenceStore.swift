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

    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = appSupport.appendingPathComponent("octosentry", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        fileURL = directory.appendingPathComponent("state.json")
    }

    func load() -> PersistedState {
        guard let data = try? Data(contentsOf: fileURL),
              let state = try? Self.decoder.decode(PersistedState.self, from: data) else {
            return .placeholder
        }
        return state
    }

    func save(_ state: PersistedState) {
        guard let data = try? Self.encoder.encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
