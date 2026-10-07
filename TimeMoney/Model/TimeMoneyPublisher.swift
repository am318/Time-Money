import Foundation

/// Writes this app's snapshot into the shared container, for an optional companion app
/// that joins the same App Group to read.
///
/// Its own subfolder in a neutral group, never anybody else's. `AutoBackup` keeps its
/// generations in this app's private container and is untouched — that is a backup,
/// and this is an interface; conflating them would mean exporting a year of
/// decisions to a neighbour.
enum TimeMoneyPublisher {
    static let appGroupID = AppGroup.identifier
    static let folderName = "TimeMoney"
    static let prefix = "TimeMoney-"
    static let generationsKept = 4

    /// Only decisions committed recently are worth another app's attention.
    static let windowDays: Double = 45

    /// Set only by tests.
    static var folderOverride: URL?

    static var folderURL: URL? {
        if let folderOverride {
            try? FileManager.default.createDirectory(at: folderOverride, withIntermediateDirectories: true)
            return folderOverride
        }
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else { return nil }
        let url = container.appendingPathComponent(folderName, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    static var isAvailable: Bool { folderURL != nil }

    static func existing() -> [URL] {
        guard let folder = folderURL,
              let files = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: [.contentModificationDateKey]) else { return [] }
        return files
            .filter { $0.pathExtension == "json" && $0.lastPathComponent.hasPrefix(prefix) }
            .sorted { modified($0) > modified($1) }
    }

    /// Builds the snapshot from what the app already knows. Nothing is computed
    /// specially for export.
    static func snapshot(profile: Profile, decisions: [Decision], breakdown: RateBreakdown,
                         now: Date = Date()) -> TimeMoneySnapshot {
        var snapshot = TimeMoneySnapshot()
        snapshot.exportedAt = now
        snapshot.personalHourlyRate = breakdown.personalHourlyRate
        snapshot.effectiveEarnedRate = breakdown.effectiveEarnedRate
        snapshot.netMonthlyIncome = breakdown.netMonthlyIncome
        snapshot.stance = profile.stance.rawValue
        snapshot.standing = profile.standing.rawValue

        let cutoff = now.addingTimeInterval(-windowDays * 86_400)
        snapshot.committedDecisions = decisions
            .compactMap { decision -> CommittedDecision? in
                guard let amount = decision.committedMoney, amount > 0,
                      let at = decision.committedAt, at >= cutoff else { return nil }
                return CommittedDecision(
                    id: decision.id,
                    title: decision.title.isEmpty ? "A decision" : decision.title,
                    chosenOption: chosenName(of: decision),
                    amount: amount,
                    committedAt: at,
                    isRecurring: decision.frequency.isRecurring,
                    frequencyLabel: decision.frequency.isRecurring ? decision.frequency.label : nil
                )
            }
            .sorted { $0.committedAt > $1.committedAt }

        return snapshot
    }

    private static func chosenName(of decision: Decision) -> String? {
        switch decision.chosenSide {
        case "a", "A": return decision.optionA.name.isEmpty ? nil : decision.optionA.name
        case "b", "B": return decision.optionB.name.isEmpty ? nil : decision.optionB.name
        default: return nil
        }
    }

    /// Value-only entry point, so the debounced save can publish without capturing
    /// the store itself into a concurrently-executing task.
    static func publishIfLinked(profile: Profile, decisions: [Decision], breakdown: RateBreakdown) {
        guard profile.portfolioLinkEnabled, isAvailable else { return }
        publish(snapshot(profile: profile, decisions: decisions, breakdown: breakdown))
    }

    @discardableResult
    static func publish(_ snapshot: TimeMoneySnapshot) -> Bool {
        guard let folder = folderURL else { return false }
        do {
            let url = folder.appendingPathComponent(snapshot.suggestedFilename)
            try snapshot.encoded().write(to: url, options: .atomic)
            prune()
            return true
        } catch {
            return false
        }
    }

    private static func prune() {
        let files = existing()
        guard files.count > generationsKept else { return }
        for url in files.dropFirst(generationsKept) { try? FileManager.default.removeItem(at: url) }
    }

    private static func modified(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
            ?? .distantPast
    }
}
