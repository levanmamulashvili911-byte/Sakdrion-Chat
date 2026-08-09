import Foundation

/// Everything the app keeps between launches, in one Codable envelope.
struct AppSnapshot: Codable {
    var currentUser: Contact?
    var contacts: [Contact] = []
    var chats: [Chat] = []
    var calls: [CallRecord] = []
    var preferences: Preferences = Preferences()
    var schemaVersion: Int = 1
}

/// Atomic JSON storage in Application Support.
///
/// A real client would keep messages in a database with an encrypted store; this
/// keeps the same shape (load once, save on change) so swapping the backing
/// implementation only touches this file.
struct SnapshotStorage {
    static let shared = SnapshotStorage(fileName: "sakdrion-store.json")

    let fileName: String

    private var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL.temporaryDirectory
        return base.appendingPathComponent("SakdrionChat", isDirectory: true)
    }

    private var fileURL: URL {
        directoryURL.appendingPathComponent(fileName)
    }

    func load() -> AppSnapshot? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(AppSnapshot.self, from: data)
    }

    func save(_ snapshot: AppSnapshot) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(snapshot) else { return }
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("[SakdrionChat] Failed to persist snapshot: \(error)")
            #endif
        }
    }

    func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
