import Foundation

/// Where an Attention backup comes from.
///
/// Attention is a separate, optional app; this reads its exported backup file and
/// nothing else. The user hands the file over once (Settings → Attention → "Choose a
/// backup file…"), it is copied into this app's own storage, and it is used until they
/// hand over a newer one. The format is described in `AttentionData.swift`.
///
/// Nothing here reaches into another app's storage, and nothing is ever written back.
enum AttentionSource {

    enum Origin: String, Equatable {
        case imported

        var label: String { "From a file you shared" }
    }

    struct Found: Equatable {
        let data: Data
        let modified: Date
        let origin: Origin
        let name: String
    }

    // MARK: - A file handed over once

    static var importedURL: URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL.temporaryDirectory
        let dir = base.appendingPathComponent("TimeMoney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("attention-import.json")
    }

    static func importedCopy() -> Found? {
        let url = importedURL
        guard let data = try? Data(contentsOf: url) else { return nil }
        return Found(data: data, modified: modified(url), origin: .imported, name: url.lastPathComponent)
    }

    /// Copies the bytes in rather than holding a bookmark into somebody else's folder.
    /// A security-scoped URL that quietly stops resolving is a worse failure than an
    /// obviously old file, because it looks like nothing is wrong.
    static func storeImported(from url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        // Decode before keeping it, so an unrelated JSON file fails here and not
        // silently three screens later.
        _ = try AttentionSnapshot.decode(data)
        try data.write(to: importedURL, options: .atomic)
    }

    static func clearImported() {
        try? FileManager.default.removeItem(at: importedURL)
    }

    // MARK: - The file in use

    static func newest() -> Found? { importedCopy() }

    static func loadSummary(now: Date = Date()) -> (summary: AttentionSummary, origin: Origin, name: String)? {
        guard let found = newest(),
              let snapshot = try? AttentionSnapshot.decode(found.data) else { return nil }
        return (AttentionAnalysis.summarise(snapshot, now: now), found.origin, found.name)
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }
}
