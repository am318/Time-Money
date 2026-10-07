import Foundation

/// Unattended local snapshots.
///
/// Manual export already exists, but it only protects the days you remember to run
/// it, and reinstalling an app is routine. This writes a snapshot on a schedule,
/// keeps a handful of generations, and never touches the live file.
///
/// Modelled on the optional Attention companion app's backups, down to the filenames
/// and the count kept.
enum AutoBackup {
    /// Snapshots live inside this app's own container, deliberately.
    ///
    /// Nobody else's folder is ever written to: a reader that treats every `.json` in
    /// its folder as its own would otherwise be handed files it can't read.
    static let folderName = "Backups"
    static let prefix = "TimeMoney-"
    static let generationsKept = 8

    /// Set only by tests, so exercising the writing and pruning for real
    /// doesn't leave files in anybody's Application Support directory.
    static var folderOverride: URL? = nil

    static var folderURL: URL? {
        if let folderOverride {
            try? FileManager.default.createDirectory(at: folderOverride, withIntermediateDirectories: true)
            return folderOverride
        }
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL.temporaryDirectory
        let url = base
            .appendingPathComponent("TimeMoney", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// Newest first.
    static func existing() -> [URL] {
        guard let folder = folderURL,
              let files = try? FileManager.default.contentsOfDirectory(
                at: folder,
                includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        return files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { modified($0) > modified($1) }
    }

    static var lastBackupDate: Date? {
        existing().first.map(modified)
    }

    /// One snapshot, described well enough to choose between them.
    struct Snapshot: Identifiable, Equatable {
        let url: URL
        let writtenAt: Date
        let bytes: Int
        let decisions: Int

        var id: URL { url }
        var name: String { url.lastPathComponent }
    }

    /// Every snapshot with a look inside it, newest first.
    ///
    /// Reading each file to count its decisions is the point: a list of filenames is
    /// not something anyone can choose from under pressure, and the moment you need
    /// these is exactly the moment you want to know which one still has your year in
    /// it.
    static func snapshots() -> [Snapshot] {
        existing().compactMap { url in
            guard let data = try? Data(contentsOf: url),
                  let backup = try? TimeMoneyBackup.decode(data) else { return nil }
            return Snapshot(url: url,
                            writtenAt: backup.exportedAt,
                            bytes: data.count,
                            decisions: backup.decisions.count)
        }
    }

    // MARK: - Writing

    enum Outcome: Equatable {
        case wrote(URL)
        /// Nothing had changed since the last one, so a slot wasn't spent on a copy.
        case unchanged
        case notDue
        case off
        case failed
    }

    /// Writes a snapshot if the newest one is older than `everyDays`.
    @discardableResult
    static func runIfDue(_ backup: TimeMoneyBackup,
                         everyDays: Int,
                         keep: Int = generationsKept,
                         now: Date = Date(),
                         calendar: Calendar = .current) -> Outcome {
        guard everyDays > 0 else { return .off }
        if let last = lastBackupDate, dayDifference(from: last, to: now, calendar: calendar) < everyDays {
            return .notDue
        }
        return write(backup, keep: keep, now: now)
    }

    /// Writes one regardless of the schedule.
    @discardableResult
    static func write(_ backup: TimeMoneyBackup,
                      keep: Int = generationsKept,
                      now: Date = Date()) -> Outcome {
        guard let data = try? backup.encoded() else { return .failed }

        // Eight snapshots of eight identical states is one snapshot and seven wasted
        // slots. Compared with the timestamp normalised, since that is the one field
        // guaranteed to differ and the one nobody is restoring for.
        if let newest = existing().first,
           let previous = try? Data(contentsOf: newest),
           unchanged(previous, matches: backup) {
            return .unchanged
        }

        return writeSnapshot(data, keep: keep, now: now)
    }

    @discardableResult
    static func writeSnapshot(_ data: Data, keep: Int = generationsKept, now: Date = Date()) -> Outcome {
        guard let folder = folderURL else { return .failed }
        let stamp = now.formatted(.iso8601.year().month().day().dateSeparator(.dash))
        var url = folder.appendingPathComponent("\(prefix)\(stamp).json")

        // More than one snapshot in a day shouldn't overwrite the morning's.
        var attempt = 2
        while FileManager.default.fileExists(atPath: url.path) && attempt < 20 {
            url = folder.appendingPathComponent("\(prefix)\(stamp)-\(attempt).json")
            attempt += 1
        }

        do { try data.write(to: url, options: .atomic) } catch { return .failed }
        prune(keep: keep)
        return .wrote(url)
    }

    /// Keeps the newest `keep` snapshots and deletes the rest.
    static func prune(keep: Int) {
        let files = existing()
        guard files.count > keep else { return }
        for url in files.dropFirst(keep) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func delete(_ snapshot: Snapshot) {
        try? FileManager.default.removeItem(at: snapshot.url)
    }

    // MARK: - Bits worth testing on their own

    /// Whole days between two instants, counted by date rather than by elapsed hours,
    /// so "daily" means once a day and not once every twenty-four hours.
    static func dayDifference(from: Date, to: Date, calendar: Calendar = .current) -> Int {
        let a = calendar.startOfDay(for: from)
        let b = calendar.startOfDay(for: to)
        return calendar.dateComponents([.day], from: a, to: b).day ?? 0
    }

    /// Whether a file already holds this exact state, ignoring when it was written.
    static func unchanged(_ data: Data, matches backup: TimeMoneyBackup) -> Bool {
        guard let previous = try? TimeMoneyBackup.decode(data) else { return false }
        let epoch = Date(timeIntervalSince1970: 0)
        var a = previous; a.exportedAt = epoch
        var b = backup;   b.exportedAt = epoch
        // Compared as encoded bytes rather than as values, because a date that has
        // been through the file has lost its fractions and one that hasn't has not.
        // Encoding both puts them on the same footing.
        return (try? a.encoded()) == (try? b.encoded())
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }
}
