import Foundation

/// What the widget shows, written by the app and read by the extension.
///
/// A file rather than a shared database. The widget must render in milliseconds on a
/// timeline refresh, with no access to the app's state and no chance to recompute
/// anything — so the app writes the finished figures and the widget only draws them.
///
/// Additive and decoded field by field, like every other file this app reads or writes:
/// a newer app must never leave an older widget unable to draw.
struct TimeMoneyWidgetSnapshot: Codable, Equatable {
    static let appGroupID = AppGroup.identifier
    static let filename = "widget.json"

    var generatedAt: Date = Date()

    /// The number the whole app exists to derive: what an hour of your life is worth.
    var hourlyRate: Double = 0
    /// Take-home divided by the hours work actually takes, commute included.
    var effectiveEarnedRate: Double = 0
    /// Genuinely spare money each month, after bills and what is being saved.
    var discretionaryMonthly: Double = 0
    /// Hours a week that are yours.
    var freeHoursWeekly: Double = 0
    /// "Balanced", "Time-poor" — how the app describes the trade you are making.
    var stance: String = ""
    /// Set when the figures rest on Portfolio's numbers rather than typed ones.
    var usingPortfolioFigures: Bool = false

    /// Decisions saved but never looked back at.
    var awaitingReview: Int = 0

    var hasRate: Bool { hourlyRate > 0 }

    // MARK: Where it lives

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID)?
            .appendingPathComponent("TimeMoney", isDirectory: true)
            .appendingPathComponent(filename)
    }

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

    /// Nil rather than throwing: a widget with no snapshot draws its empty state, and
    /// there is nobody to show an error to.
    static func read() -> TimeMoneyWidgetSnapshot? {
        guard let url = fileURL, let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder().decode(TimeMoneyWidgetSnapshot.self, from: data)
    }

    @discardableResult
    func write() -> Bool {
        guard let url = Self.fileURL else { return false }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        guard let data = try? Self.encoder().encode(self) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
    }

    init() {}

    /// Field by field, so a snapshot written before a field existed still draws.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = TimeMoneyWidgetSnapshot()
        generatedAt = try c.decodeIfPresent(Date.self, forKey: .generatedAt) ?? fresh.generatedAt
        hourlyRate = try c.decodeIfPresent(Double.self, forKey: .hourlyRate) ?? fresh.hourlyRate
        effectiveEarnedRate = try c.decodeIfPresent(Double.self, forKey: .effectiveEarnedRate) ?? fresh.effectiveEarnedRate
        discretionaryMonthly = try c.decodeIfPresent(Double.self, forKey: .discretionaryMonthly) ?? fresh.discretionaryMonthly
        freeHoursWeekly = try c.decodeIfPresent(Double.self, forKey: .freeHoursWeekly) ?? fresh.freeHoursWeekly
        stance = try c.decodeIfPresent(String.self, forKey: .stance) ?? fresh.stance
        usingPortfolioFigures = try c.decodeIfPresent(Bool.self, forKey: .usingPortfolioFigures) ?? fresh.usingPortfolioFigures
        awaitingReview = try c.decodeIfPresent(Int.self, forKey: .awaitingReview) ?? fresh.awaitingReview
    }
}
