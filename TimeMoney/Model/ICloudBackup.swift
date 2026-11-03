import Foundation

/// An optional second copy of each automatic snapshot, in iCloud Drive.
///
/// It is a plain file copy of the same JSON the local snapshots use: no sync engine, no
/// merge, no account stored by the app. The copies appear in the Files app and are
/// restored with the ordinary "Restore from a file" action. All of it is inert unless
/// the build is signed with the iCloud entitlement; without it `containerFolder` is nil
/// and nothing happens.
enum ICloudBackup {
    static let keep = AutoBackup.generationsKept

    /// `Documents/Backups` inside the app's iCloud container, or nil when iCloud is
    /// unavailable (no entitlement, signed out, or disabled for the app). Resolving it
    /// can block, so call off the main thread.
    static func containerFolder() -> URL? {
        FileManager.default.url(forUbiquityContainerIdentifier: nil)?
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Backups", isDirectory: true)
    }

    /// Whether the settings row can be offered: this build was configured for iCloud
    /// (`ICLOUD_ENABLED = YES` in Config, which also selects the entitlements) and the
    /// device is signed in to iCloud.
    static var isAvailable: Bool {
        (Bundle.main.object(forInfoDictionaryKey: "ICloudEntitlementEnabled") as? String) == "YES"
            && FileManager.default.ubiquityIdentityToken != nil
    }

    static func mirrorInBackground(_ file: URL) {
        Task.detached(priority: .utility) {
            guard let folder = containerFolder() else { return }
            _ = mirror(file, to: folder, keep: keep)
        }
    }

    /// Copies `file` into `folder` (replacing a same-named copy) and keeps only the
    /// newest `keep` snapshots there. Separate from the container lookup so it can be
    /// tested with an ordinary directory.
    @discardableResult
    static func mirror(_ file: URL, to folder: URL, keep: Int) -> Bool {
        let fm = FileManager.default
        do {
            try fm.createDirectory(at: folder, withIntermediateDirectories: true)
            let destination = folder.appendingPathComponent(file.lastPathComponent)
            if fm.fileExists(atPath: destination.path) { try fm.removeItem(at: destination) }
            try fm.copyItem(at: file, to: destination)
        } catch {
            return false
        }
        prune(folder, keep: keep)
        return true
    }

    static func prune(_ folder: URL, keep: Int) {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return }
        let snapshots = files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix(AutoBackup.prefix) }
            .sorted { modified($0) > modified($1) }
        for url in snapshots.dropFirst(keep) { try? fm.removeItem(at: url) }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }
}
