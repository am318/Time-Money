import Foundation

/// The file Time / Money publishes for Portfolio to read.
///
/// The mirror image of `PortfolioSnapshot`, and deliberately not a backup: a backup
/// carries everything and would drag the whole decision model across the boundary.
/// This carries only what the other side has a use for.
struct TimeMoneySnapshot: Codable, Equatable {
    static let currentVersion = 1

    var formatVersion: Int = TimeMoneySnapshot.currentVersion
    var exportedAt: Date = Date()

    /// What an hour of your life is worth, in pounds. The number the whole app exists
    /// to derive.
    var personalHourlyRate: Double = 0
    /// Take-home divided by every hour work actually takes, commute included.
    var effectiveEarnedRate: Double = 0
    var netMonthlyIncome: Double = 0

    var stance: String?
    var standing: String?

    /// Choices that committed money, newest first. Portfolio completes these into
    /// real transactions rather than importing them silently — it knows the amount
    /// and the date, but not which card paid.
    var committedDecisions: [CommittedDecision] = []

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

    func encoded() throws -> Data { try TimeMoneySnapshot.encoder().encode(self) }

    static func decode(_ data: Data) throws -> TimeMoneySnapshot {
        let snapshot = try decoder().decode(TimeMoneySnapshot.self, from: data)
        guard snapshot.formatVersion <= currentVersion else { throw TimeMoneySnapshotError.tooNew }
        return snapshot
    }

    var suggestedFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return "TimeMoney-\(formatter.string(from: exportedAt)).json"
    }
}

/// A choice that cost money. Enough to recognise it; not enough to book it.
struct CommittedDecision: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    /// What was chosen, where the decision recorded it.
    var chosenOption: String?
    /// Positive means money out.
    var amount: Double = 0
    var committedAt: Date = Date()
    var isRecurring: Bool = false
    /// "every month", "just once" — how the other app says it.
    var frequencyLabel: String?
}

enum TimeMoneySnapshotError: LocalizedError, Equatable {
    case tooNew

    var errorDescription: String? {
        switch self {
        case .tooNew: "This file was written by a newer version of Time / Money than the one reading it."
        }
    }
}

extension TimeMoneySnapshot {
    /// Field by field, so a snapshot written before a field existed still opens.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = TimeMoneySnapshot()
        formatVersion = try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? fresh.formatVersion
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? fresh.exportedAt
        personalHourlyRate = try c.decodeIfPresent(Double.self, forKey: .personalHourlyRate) ?? fresh.personalHourlyRate
        effectiveEarnedRate = try c.decodeIfPresent(Double.self, forKey: .effectiveEarnedRate) ?? fresh.effectiveEarnedRate
        netMonthlyIncome = try c.decodeIfPresent(Double.self, forKey: .netMonthlyIncome) ?? fresh.netMonthlyIncome
        stance = try c.decodeIfPresent(String.self, forKey: .stance)
        standing = try c.decodeIfPresent(String.self, forKey: .standing)
        committedDecisions = try c.decodeIfPresent([CommittedDecision].self, forKey: .committedDecisions) ?? fresh.committedDecisions
    }
}

extension CommittedDecision {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = CommittedDecision()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? fresh.id
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? fresh.title
        chosenOption = try c.decodeIfPresent(String.self, forKey: .chosenOption)
        amount = try c.decodeIfPresent(Double.self, forKey: .amount) ?? fresh.amount
        committedAt = try c.decodeIfPresent(Date.self, forKey: .committedAt) ?? fresh.committedAt
        isRecurring = try c.decodeIfPresent(Bool.self, forKey: .isRecurring) ?? fresh.isRecurring
        frequencyLabel = try c.decodeIfPresent(String.self, forKey: .frequencyLabel)
    }
}
