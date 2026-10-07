import Foundation

/// Everything the app knows, in one file.
///
/// The app signs with a development profile that expires after a week, so
/// reinstalling is routine rather than exceptional. A year of decisions and a
/// carefully tuned set of anchors living only inside a container that a reinstall
/// can take away is a bad place for them to live.
///
/// Written the same way Attention writes its own: pretty-printed, keys sorted,
/// dates as ISO 8601, so the file is readable by a person and diffable by a tool.
struct TimeMoneyBackup: Codable, Equatable {
    var formatVersion: Int = TimeMoneyBackup.currentVersion
    var exportedAt: Date = Date()
    var profile: Profile
    var decisions: [Decision]

    static let currentVersion = 1

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encoded() throws -> Data {
        try TimeMoneyBackup.encoder().encode(self)
    }

    static func decode(_ data: Data) throws -> TimeMoneyBackup {
        let backup = try decoder().decode(TimeMoneyBackup.self, from: data)
        guard backup.formatVersion <= currentVersion else { throw BackupError.tooNew }
        return backup
    }

    /// What a restore would do, so it can be said out loud before it's done rather
    /// than reported afterwards.
    struct Summary: Equatable {
        let exportedAt: Date
        let decisions: Int
        let reviewed: Int
        let rate: Double

        var age: String {
            let days = Int((Date().timeIntervalSince(exportedAt) / 86_400).rounded())
            if days <= 0 { return "today" }
            return days == 1 ? "yesterday" : "\(days) days ago"
        }
    }

    var summary: Summary {
        Summary(exportedAt: exportedAt,
                decisions: decisions.count,
                reviewed: decisions.filter { $0.review != nil }.count,
                rate: RateEngine.breakdown(for: profile).personalHourlyRate)
    }

    /// A filename with the date in it, because a folder of files all called
    /// "backup.json" is not a backup.
    var suggestedFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return "TimeMoney-\(formatter.string(from: exportedAt)).json"
    }
}

enum BackupError: LocalizedError, Equatable {
    case tooNew
    case unreadable

    var errorDescription: String? {
        switch self {
        case .tooNew:
            return "This file was written by a newer version of the app than the one you're running."
        case .unreadable:
            return "That doesn't look like a Time / Money backup."
        }
    }
}
