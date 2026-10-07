import Foundation
import Observation
import UserNotifications

/// Single source of truth, persisted as JSON in Application Support.
/// Small enough that there is no reason to reach for a database.
@Observable
final class Store {

    var profile: Profile {
        didSet { scheduleSave() }
    }

    var decisions: [Decision] {
        didSet { scheduleSave() }
    }

    // MARK: - What Attention knows

    /// Conclusions drawn from the newest Attention backup, and where it came from.
    ///
    /// Held rather than recomputed because the whole file is parsed to produce it and
    /// the rate is read on every keystroke of a decision. Refreshed when the app comes
    /// back to the foreground, which is often enough for a file that changes weekly.
    private(set) var attention: AttentionSummary? = nil
    private(set) var attentionOrigin: AttentionSource.Origin? = nil
    private(set) var attentionFileName: String? = nil

    /// Corrections to apply to the time side of a decision. Empty unless the user has
    /// switched the link on and the file has something to say.
    var timeCalibration: TimeCalibration {
        profile.attentionLinkEnabled ? TimeCalibration(summary: attention) : .none
    }

    /// Whether the link is on but there's nothing behind it — worth saying out loud,
    /// since the alternative is a switch that silently does nothing.
    var attentionIsLinkedButEmpty: Bool {
        profile.attentionLinkEnabled && (attention?.isUsable != true)
    }

    // MARK: - What Portfolio knows

    /// The newest Portfolio snapshot, and where it came from. Held rather than
    /// re-read for the same reason the Attention summary is: the rate is read on
    /// every keystroke of a decision, and this is a file that changes every few days.
    private(set) var portfolio: PortfolioSnapshot? = nil
    private(set) var portfolioOrigin: PortfolioSource.Origin? = nil
    private(set) var portfolioFileName: String? = nil

    /// Corrections to apply to the money side. Empty unless the link is on and there
    /// is a file behind it.
    var moneyCalibration: MoneyCalibration {
        profile.portfolioLinkEnabled ? MoneyCalibration(snapshot: portfolio) : .none
    }

    var portfolioIsLinkedButEmpty: Bool {
        profile.portfolioLinkEnabled && portfolio == nil
    }

    /// Publishes this app's own snapshot for Portfolio to read.
    ///
    /// Called after a save rather than on a timer: the thing Portfolio wants is a
    /// decision that has just committed money, and waiting three days to mention it
    /// would mean the purchase is long forgotten by the time it is offered.
    func publishForPortfolio() {
        guard profile.portfolioLinkEnabled, TimeMoneyPublisher.isAvailable else { return }
        TimeMoneyPublisher.publish(
            TimeMoneyPublisher.snapshot(profile: profile, decisions: decisions, breakdown: breakdown)
        )
    }

    func refreshPortfolio() {
        guard let found = PortfolioSource.load() else {
            portfolio = nil
            portfolioOrigin = nil
            portfolioFileName = nil
            return
        }
        portfolio = found.snapshot
        portfolioOrigin = found.origin
        portfolioFileName = found.name
    }

    func importPortfolioFile(at url: URL) throws {
        try PortfolioSource.storeImported(from: url)
        refreshPortfolio()
    }

    func clearPortfolioImport() {
        PortfolioSource.clearImported()
        refreshPortfolio()
    }

    func refreshAttention() {
        guard let found = AttentionSource.loadSummary() else {
            attention = nil
            attentionOrigin = nil
            attentionFileName = nil
            return
        }
        attention = found.summary
        attentionOrigin = found.origin
        attentionFileName = found.name
    }

    func importAttentionFile(at url: URL) throws {
        try AttentionSource.storeImported(from: url)
        refreshAttention()
        refreshPortfolio()
        settleSavingsBaseline()
        runAutoBackupIfDue()
    }

    func clearAttentionImport() {
        AttentionSource.clearImported()
        refreshAttention()
        refreshPortfolio()
    }

    /// How far back a decision keeps affecting the ones after it.
    static let commitmentWindowDays: Double = 30

    /// Money tied up by choices made in the last month. Positive is money out;
    /// selling something recorded as income puts money back.
    var recentlyCommitted: Double {
        let cutoff = Date().addingTimeInterval(-Store.commitmentWindowDays * 86_400)
        return decisions.reduce(0) { running, decision in
            guard let amount = decision.committedMoney,
                  let at = decision.committedAt, at >= cutoff else { return running }
            return running + amount
        }
    }

    var breakdown: RateBreakdown {
        RateEngine.breakdown(for: profile,
                             recentlyCommitted: recentlyCommitted,
                             attention: attention,
                             money: moneyCalibration)
    }
    var rate: Double { breakdown.personalHourlyRate }

    private let fileURL: URL
    private var saveTask: Task<Void, Never>?

    init(fileURL: URL? = nil) {
        let url = fileURL ?? Store.defaultURL()
        self.fileURL = url

        let data = try? Data(contentsOf: url)
        if let data, let state = try? JSONDecoder().decode(PersistedState.self, from: data) {
            self.profile = state.profile
            self.decisions = state.decisions
        } else {
            self.profile = Profile()
            self.decisions = []
            // The file was there and could not be read at all. Keep it: the next save
            // is about to write an empty state over the top, and a year of decisions is
            // not something to lose quietly because one byte went wrong.
            if let data, !data.isEmpty { Store.preserve(data, alongside: url) }
        }
        refreshAttention()
        refreshPortfolio()
    }

    private struct PersistedState: Codable {
        var profile: Profile
        var decisions: [Decision]

        init(profile: Profile, decisions: [Decision]) {
            self.profile = profile
            self.decisions = decisions
        }

        /// Decoded apart, so that one half failing doesn't take the other with it.
        ///
        /// Synthesised decoding throws on a key it doesn't find, defaults and all — so
        /// adding a single field to Profile in some later version would have failed the
        /// whole file, and the caller's `try?` would then have started the app with no
        /// history at all. A profile is fifteen questions; the decisions behind it are
        /// not replaceable.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            profile = (try? c.decode(Profile.self, forKey: .profile)) ?? Profile()
            decisions = (try? c.decode([Decision].self, forKey: .decisions)) ?? []
        }
    }

    /// Keeps an unreadable state file rather than letting the next save overwrite it.
    private static func preserve(_ data: Data, alongside url: URL) {
        let stamp = Int(Date().timeIntervalSince1970)
        let copy = url.deletingPathExtension()
            .appendingPathExtension("unreadable-\(stamp).json")
        try? data.write(to: copy)
    }

    private static func defaultURL() -> URL {
        let base = (try? FileManager.default.url(for: .applicationSupportDirectory,
                                                 in: .userDomainMask,
                                                 appropriateFor: nil,
                                                 create: true))
            ?? URL.temporaryDirectory
        let dir = base.appendingPathComponent("TimeMoney", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    /// Coalesce writes so dragging a slider doesn't hammer the disk.
    private func scheduleSave() {
        saveTask?.cancel()
        let state = PersistedState(profile: profile, decisions: decisions)
        let url = fileURL
        // Captured by value rather than through self: this runs concurrently, and
        // capturing the store would be an error under Swift 6 concurrency.
        let profileCopy = profile
        let decisionsCopy = decisions
        let breakdownCopy = breakdown

        saveTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            Store.write(state, to: url)
            // Debounced with the save, so a decision being edited does not rewrite
            // the shared file on every keystroke.
            TimeMoneyPublisher.publishIfLinked(profile: profileCopy,
                                               decisions: decisionsCopy,
                                               breakdown: breakdownCopy)
        }
    }

    private static func write(_ state: PersistedState, to url: URL) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(state) else { return }
        try? data.write(to: url, options: .atomic)
    }

    // MARK: - Backing it up

    /// The whole of it, as a file.
    func backup() -> TimeMoneyBackup {
        TimeMoneyBackup(profile: profile, decisions: decisions)
    }

    /// Writes a backup into the temporary directory and returns where, ready to hand
    /// to a share sheet. Temporary because the copy that matters is the one the user
    /// puts somewhere — iCloud Drive, a message to themselves, anywhere but here.
    func writeBackup() throws -> URL {
        let backup = self.backup()
        let url = URL.temporaryDirectory.appendingPathComponent(backup.suggestedFilename)
        try backup.encoded().write(to: url, options: .atomic)
        return url
    }

    /// Writes an unattended snapshot if one is due. Called on launch and on coming
    /// back to the app, which between them is often enough for something that happens
    /// every few days.
    @discardableResult
    func runAutoBackupIfDue() -> AutoBackup.Outcome {
        // Nothing before setup is finished. Otherwise the very first launch spends a
        // slot on an empty profile, and — worse — the oldest snapshot in the list is
        // one that puts you back into onboarding if you ever restore it.
        guard profile.hasCompletedSetup else { return .off }
        return AutoBackup.runIfDue(backup(), everyDays: profile.autoBackupEveryDays)
    }

    @discardableResult
    func snapshotNow() -> AutoBackup.Outcome {
        AutoBackup.write(backup())
    }

    var snapshots: [AutoBackup.Snapshot] { AutoBackup.snapshots() }
    var lastSnapshotDate: Date? { AutoBackup.lastBackupDate }

    /// Reads a file without changing anything, so a restore can be described before
    /// it happens. A destructive action the user hasn't seen the shape of is one they
    /// can't consent to.
    func inspectBackup(at url: URL) throws -> TimeMoneyBackup {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        guard let data = try? Data(contentsOf: url) else { throw BackupError.unreadable }
        do {
            return try TimeMoneyBackup.decode(data)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.unreadable
        }
    }

    /// Replaces everything. Destructive on purpose — a restore that merged would
    /// leave you unable to say what state you were in afterwards.
    func restore(from backup: TimeMoneyBackup) {
        profile = backup.profile
        decisions = backup.decisions
        settleSavingsBaseline()
        saveNow()
    }

    // MARK: - Keeping savings in step with pay

    /// A rise in take-home that savings haven't followed yet, or nil.
    var pendingSavingsRaise: SavingsRatchet.Raise? {
        SavingsRatchet.pending(
            for: profile,
            netMonthly: RateEngine.netMonthlyIncome(for: profile),
            money: moneyCalibration
        )
    }

    /// Moves the reference point when it should move. Called on launch and on coming
    /// back to the app rather than from a property observer, so it can't recurse
    /// through a save.
    func settleSavingsBaseline() {
        SavingsRatchet.settle(&profile, netMonthly: RateEngine.netMonthlyIncome(for: profile))
    }

    func applySavingsRaise(_ amount: Double, raise: SavingsRatchet.Raise, includingGoal: Bool) {
        SavingsRatchet.apply(amount, raise: raise, to: &profile, includingGoal: includingGoal)
    }

    func declineSavingsRaise(_ raise: SavingsRatchet.Raise) {
        SavingsRatchet.decline(raise, in: &profile)
    }

    func saveNow() {
        saveTask?.cancel()
        Store.write(PersistedState(profile: profile, decisions: decisions), to: fileURL)
        publishForPortfolio()
        WidgetBridge.refresh(store: self)
    }

    // MARK: - Recording

    @discardableResult
    func record(_ decision: Decision, evaluation: Evaluation) -> Decision {
        var d = decision
        d.isSaved = true
        d.recordedRate = evaluation.rate
        d.recordedVerdict = VerdictText.recap(for: evaluation, decision: decision)
        d.recommendedSide = evaluation.winner.rawValue
        upsert(d)
        return d
    }

    /// What the user actually did. More informative than any rating, because it's
    /// behaviour rather than opinion.
    func setChoice(_ side: Side, for decision: Decision) {
        var d = decision
        d.chosenSide = side.rawValue
        d.isSaved = true
        // One occurrence's worth — the cooldown is about the thing you're about to
        // go and do, not the whole horizon.
        if side != .tooClose {
            let option = side == .a ? decision.optionA : decision.optionB
            let minutes = option.setupMinutes + option.minutes
            d.committedMinutes = minutes > 0 ? minutes : nil
        }
        // What this ties up over the coming month, recorded now so it can tighten
        // the decisions that follow it.
        d.committedMoney = DecisionEngine.monthlyCommitment(of: side, in: decision)
        d.committedAt = Date()
        upsert(d)
    }

    /// Something you've said you'd do that ought to be happening right now.
    ///
    /// Deliberately a suggestion and never a block. Deciding is easier than doing,
    /// and an app that makes deciding frictionless while you have three unstarted
    /// commitments is helping with the wrong problem.
    struct Cooldown: Equatable {
        let name: String
        let endsAt: Date
        let totalMinutes: Double

        var remaining: TimeInterval { max(0, endsAt.timeIntervalSinceNow) }
        var remainingMinutes: Int { Int((remaining / 60).rounded()) }
    }

    var activeCooldown: Cooldown? {
        let now = Date()
        return decisions.compactMap { decision -> Cooldown? in
            guard let at = decision.committedAt,
                  let minutes = decision.committedMinutes, minutes > 0 else { return nil }
            let ends = at.addingTimeInterval(minutes * 60)
            guard ends > now else { return nil }
            let name = decision.title.isEmpty
                ? decision.scenario.template.title
                : decision.title
            return Cooldown(name: name, endsAt: ends, totalMinutes: minutes)
        }
        .max { $0.endsAt < $1.endsAt }
    }

    /// Whether something you've committed to actually fits the evening it's meant to
    /// happen in, according to what's already booked.
    func fitNote(forMinutes minutes: Double) -> String? {
        AttentionNotes.fit(minutes: minutes, summary: attention,
                           enabled: profile.attentionLinkEnabled)
    }

    /// What the time being bought back is actually for.
    func freedTimeNote(for evaluation: Evaluation) -> String? {
        AttentionNotes.freedTime(for: evaluation, summary: attention,
                                 enabled: profile.attentionLinkEnabled)
    }

    /// Decisions still inside the window, most recent first.
    var activeCommitments: [Decision] {
        let cutoff = Date().addingTimeInterval(-Store.commitmentWindowDays * 86_400)
        return decisions
            .filter { ($0.committedAt ?? .distantPast) >= cutoff && ($0.committedMoney ?? 0) != 0 }
            .sorted { ($0.committedAt ?? .distantPast) > ($1.committedAt ?? .distantPast) }
    }

    /// Folds a standing cost into the monthly bills, and takes the same money back out
    /// of the thirty-day ledger — otherwise the first month would count it twice, once
    /// as a bill and once as something just taken on.
    func addToMonthlyBills(_ amount: Double, forDecision id: UUID) {
        guard amount > 0 else { return }
        profile.monthlyBills += amount
        guard var d = decisions.first(where: { $0.id == id }) else { return }
        let remaining = (d.committedMoney ?? 0) - amount
        if abs(remaining) < 0.01 {
            d.committedMoney = nil
            d.committedAt = nil
        } else {
            d.committedMoney = remaining
        }
        upsert(d)
    }

    func clearCommitment(_ decision: Decision) {
        var d = decision
        d.committedMoney = nil
        d.committedAt = nil
        upsert(d)
    }

    func setReview(_ outcome: ReviewOutcome, for decision: Decision) {
        var d = decision
        d.review = outcome
        d.reviewedAt = Date()
        upsert(d)
    }

    func upsert(_ decision: Decision) {
        if let index = decisions.firstIndex(where: { $0.id == decision.id }) {
            decisions[index] = decision
        } else {
            decisions.insert(decision, at: 0)
        }
    }

    func delete(_ decision: Decision) {
        decisions.removeAll { $0.id == decision.id }
    }

    // MARK: - Review queue

    /// Decisions worth looking back at: saved, at least a day old, not yet reviewed.
    var awaitingReview: [Decision] {
        let cutoff = Date().addingTimeInterval(-60 * 60 * 24)
        return decisions
            .filter { $0.isSaved && $0.review == nil && $0.createdAt < cutoff }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Past purchases, amortised and set against what you had spare.
    var spendingInContext: SpendingInContext {
        Retrospect.context(for: decisions, profile: profile, breakdown: breakdown,
                           money: moneyCalibration)
    }

    /// How the money figures typed into decisions here compare with what Portfolio
    /// actually booked. Empty unless the link is on and decisions have been settled.
    var estimateAccuracy: EstimateAccuracy {
        EstimateAccuracy.measure(moneyCalibration.settled)
    }

    var calibration: Calibration {
        Calibrator.calibration(for: decisions, profile: profile, currentRate: rate)
    }

    /// Money and hours the winning side avoided, across every saved decision.
    var lifetimeSaved: (money: Double, hours: Double) {
        var money: Double = 0
        var hours: Double = 0
        let currentRate = rate
        let calibration = timeCalibration
        for d in decisions where d.isSaved {
            let e = DecisionEngine.core(d, profile: profile, rate: currentRate,
                                        calibration: calibration)
            guard e.winner != .tooClose else { continue }
            let winner = e.winner == .a ? e.a : e.b
            let loser = e.winner == .a ? e.b : e.a
            money += max(0, loser.money - winner.money)
            hours += max(0, loser.rawHours - winner.rawHours)
        }
        return (money, hours)
    }

    var overrideCount: Int {
        decisions.filter {
            guard let chosen = $0.chosenSide, let recommended = $0.recommendedSide else { return false }
            return chosen != recommended && recommended != Side.tooClose.rawValue
        }.count
    }

    // MARK: - Which presets to put in front of you

    /// Ranked by recency and frequency, so the handful you actually use float to
    /// the top and the other thirty-odd stay out of the way.
    var suggestedScenarios: [ScenarioKind] {
        var score: [ScenarioKind: Double] = [:]
        let now = Date()
        for d in decisions where d.scenario != .custom {
            let ageDays = max(1, now.timeIntervalSince(d.createdAt) / 86_400)
            score[d.scenario, default: 0] += 1 / sqrt(ageDays)
        }
        let ranked = score.sorted { $0.value > $1.value }.map(\.key)
        let padding = Store.defaultSuggestions.filter { !ranked.contains($0) }
        return Array((ranked + padding).filter { !isHidden($0) }.prefix(6))
    }

    // MARK: - Hiding situations you never use

    func isHidden(_ kind: ScenarioKind) -> Bool {
        profile.hiddenScenarios?.contains(kind.rawValue) ?? false
    }

    /// In declaration order, so the settings list doesn't reshuffle itself.
    var hiddenScenarios: [ScenarioKind] {
        let hidden = Set(profile.hiddenScenarios ?? [])
        return ScenarioKind.allCases.filter { hidden.contains($0.rawValue) }
    }

    func setHidden(_ hidden: Bool, for kind: ScenarioKind) {
        // "Something else" is the way in to a blank decision. Hiding it would leave
        // someone with no route to the thing the whole app is a convenience for.
        guard kind != .custom else { return }
        var set = Set(profile.hiddenScenarios ?? [])
        if hidden { set.insert(kind.rawValue) } else { set.remove(kind.rawValue) }
        profile.hiddenScenarios = set.isEmpty ? nil : Array(set).sorted()
    }

    func showAllScenarios() { profile.hiddenScenarios = nil }

    /// The browse list, minus anything shelved. Search deliberately ignores this.
    func visibleScenarios(in family: ScenarioTemplate.Family) -> [ScenarioKind] {
        ScenarioTemplate.scenarios(in: family).filter { !isHidden($0) }
    }

    var visibleScenarioCount: Int {
        ScenarioKind.allCases.filter { $0 != .custom && !isHidden($0) }.count
    }

    static let defaultSuggestions: [ScenarioKind] = [
        .fasterVsCheaper, .eatOutVsCook, .paySomeoneElse,
        .subscription, .experience, .switchProvider
    ]

    // MARK: - Weekly nudge

    func applyWeeklyReminderSetting() {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [Store.reminderID])
        guard profile.weeklyReviewEnabled else { return }

        centre.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "How did last week go?"
            content.body = "A couple of taps each and the app can check its own maths against how things turned out."
            content.sound = .default

            var when = DateComponents()
            when.weekday = 1        // Sunday
            when.hour = 19
            when.minute = 0

            let request = UNNotificationRequest(
                identifier: Store.reminderID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
            centre.add(request)
        }
    }

    private static let reminderID = "timemoney.weekly.review"
}
