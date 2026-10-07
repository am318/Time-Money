import Foundation

/// Where a Portfolio snapshot comes from.
///
/// Portfolio is a separate, optional app that tracks investments; this reads its
/// exported snapshot file and nothing else. Same shape as `AttentionSource`: the user
/// hands the file over once, it is copied into this app's own storage, and it is used
/// until they hand over a newer one.
///
/// Nothing here reaches into another app's storage.
enum PortfolioSource {

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
        return dir.appendingPathComponent("portfolio-import.json")
    }

    static func importedCopy() -> Found? {
        let url = importedURL
        guard let data = try? Data(contentsOf: url) else { return nil }
        return Found(data: data, modified: modified(url), origin: .imported, name: url.lastPathComponent)
    }

    /// Copies the bytes in rather than holding a bookmark into somebody else's folder,
    /// for the same reason `AttentionSource` does: a security-scoped URL that quietly
    /// stops resolving looks like nothing is wrong.
    static func storeImported(from url: URL) throws {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        let data = try Data(contentsOf: url)
        // Decode before keeping it, so an unrelated JSON file fails here rather than
        // three screens later.
        _ = try PortfolioSnapshot.decode(data)
        try data.write(to: importedURL, options: .atomic)
    }

    static func clearImported() {
        try? FileManager.default.removeItem(at: importedURL)
    }

    // MARK: - The file in use

    static func newest() -> Found? { importedCopy() }

    static func load() -> (snapshot: PortfolioSnapshot, origin: Origin, name: String)? {
        guard let found = newest(),
              let snapshot = try? PortfolioSnapshot.decode(found.data) else { return nil }
        return (snapshot, found.origin, found.name)
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }
}
