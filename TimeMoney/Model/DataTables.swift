import Foundation

/// Loads the versioned JSON tables bundled with the app (`Resources/*.json`).
///
/// Figures that change every year, such as tax bands, student-loan thresholds and the
/// Living Wage, live in data files rather than code, so updating them is a data change
/// with no logic to touch. A missing or malformed file is a build defect rather than
/// a runtime condition, so it traps; the unit tests load every table and catch it.
enum DataTables {
    private final class BundleToken {}

    static func load<T: Decodable>(_ type: T.Type, from name: String) -> T {
        let bundle = Bundle(for: BundleToken.self)
        guard let url = bundle.url(forResource: name, withExtension: "json") else {
            fatalError("Missing bundled data file \(name).json")
        }
        do {
            return try JSONDecoder().decode(T.self, from: Data(contentsOf: url))
        } catch {
            fatalError("Could not decode \(name).json: \(error)")
        }
    }

    /// Parses "yyyy-MM-dd" in the UK calendar, which is the one tax years are defined in.
    static func date(_ iso: String) -> Date? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/London") ?? .current
        let parts = iso.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }
}
