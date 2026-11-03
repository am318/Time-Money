import Foundation

/// Adjustments to the time side of a decision, learned from this person's own records
/// rather than assumed about people in general.
struct TimeCalibration: Equatable {

    /// How their estimates of their own effort run.
    ///
    /// Applied to setup time only — the getting ready, the going to fetch it, the
    /// working out where the thing is — and deliberately not to the main duration,
    /// which is as often a looked-up fact as a guess. Correcting a train timetable by
    /// twenty per cent would be inventing a delay.
    ///
    /// Note this is not neutral across a comparison even though it scales both sides:
    /// it scales the *difference* too, which is what the verdict turns on.
    var estimateMultiplier: Double = 1

    /// What Attention's "under an hour" bucket is worth before anything is learned.
    static let nominalShortMinutes: Double = 40

    /// The range a learned estimate correction may take.
    ///
    /// The upper bound is not a taste: Attention clamps that bucket at its own label
    /// of sixty minutes, so sixty over a nominal forty is the most it can ever
    /// report. Stated once, here, rather than as a pair of literals at each end.
    static let multiplierRange: ClosedRange<Double> = 0.5...1.5

    /// The least an hour may be discounted to, measured.
    ///
    /// `usableTime` lets an hour on a train count for a fifth of a lost hour. If only
    /// seventy per cent of this person's free working time has ever turned into timed
    /// work, a fifth is optimistic about the other seventy minutes of the journey.
    /// Never allowed past `.some`, because the measurement is about focused work and
    /// some usable time is reading a novel.
    var usableFloor: Double = 0

    static let none = TimeCalibration()

    init(estimateMultiplier: Double = 1, usableFloor: Double = 0) {
        self.estimateMultiplier = min(Self.multiplierRange.upperBound,
                                      max(Self.multiplierRange.lowerBound, estimateMultiplier))
        self.usableFloor = max(0, min(0.4, usableFloor))
    }

    /// Nothing is taken from a summary the user hasn't linked, and nothing is taken
    /// from a figure that isn't there. Both halves fail safe to no correction at all.
    init(summary: AttentionSummary?) {
        guard let summary else { self = .none; return }
        let floor = summary.realisedShare.map { 1 - $0 } ?? 0
        self.init(estimateMultiplier: summary.estimateMultiplier ?? 1,
                  usableFloor: floor)
    }

    var isActive: Bool { estimateMultiplier != 1 || usableFloor > 0 }
}

// MARK: - Things the records can answer so the app doesn't have to ask

enum AttentionAutomation {

    /// The longest an option can run and still sensibly be assumed to be happening
    /// this evening. Past this it's a project, not a plan for tonight.
    static let sameEveningHours: Double = 8

    /// Whether doing this now would run past the point the evening is meant to start
    /// winding down.
    ///
    /// The assumption is that a decision is about now, which is true of nearly every
    /// decision anyone opens this app for. Where it isn't, the answer is one tap away.
    static func crossesWindDown(durationMinutes: Double,
                                windDownStartMinutes: Int?,
                                now: Date = Date(),
                                calendar: Calendar = .current) -> Bool {
        guard let line = windDownStartMinutes, line > 0 else { return false }
        guard durationMinutes > 0, durationMinutes <= sameEveningHours * 60 else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let minutesNow = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        // Already past the line and about to start something: that is the clearest
        // case of all, not an edge one.
        return minutesNow + durationMinutes > Double(line)
    }

    /// The wind-down line as a clock time, for saying so out loud.
    static func clockLabel(minutesFromMidnight: Int) -> String {
        let hour = (minutesFromMidnight / 60) % 24
        let minute = minutesFromMidnight % 60
        return String(format: "%d:%02d", hour, minute)
    }
}

extension AttentionAutomation {

    /// Applies the wind-down line to a decision, so the app can stop asking a question
    /// it already knows the answer to.
    ///
    /// Only ever moves an option from "I'll be fine" to "it'll cost me sleep". A user
    /// who has said something is restorative, or has already answered the question,
    /// is not overruled by a clock — the point is to skip an obvious question, not to
    /// win an argument.
    ///
    /// - Returns: what changed, in words, or nil if nothing did.
    @discardableResult
    static func applySleepBoundary(to decision: inout Decision,
                                   summary: AttentionSummary?,
                                   enabled: Bool,
                                   now: Date = Date(),
                                   calendar: Calendar = .current) -> String? {
        guard enabled, let summary, let line = summary.windDownStartMinutes else { return nil }
        guard !decision.answeredQuestions.contains(QuestionKind.drain.rawValue) else { return nil }

        func crosses(_ option: DecisionOption) -> Bool {
            option.drain == .fine
                && crossesWindDown(durationMinutes: option.setupMinutes + option.minutes,
                                   windDownStartMinutes: line, now: now, calendar: calendar)
        }

        let a = crosses(decision.optionA)
        let b = crosses(decision.optionB)
        guard a || b else { return nil }

        if a { decision.optionA.drain = .costsSleep }
        if b { decision.optionB.drain = .costsSleep }
        // Marked answered so the flow doesn't then ask what it has just concluded.
        decision.answeredQuestions.append(QuestionKind.drain.rawValue)

        let clock = clockLabel(minutesFromMidnight: line)
        let note: String
        switch (a, b) {
        case (true, true):
            note = "Both of these would run past \(clock), when you wind down. Counted as costing sleep."
        case (true, false):
            note = "\(name(decision.optionA, fallback: "The first")) would run past \(clock), when you wind down. Counted as costing sleep."
        default:
            note = "\(name(decision.optionB, fallback: "The second")) would run past \(clock), when you wind down. Counted as costing sleep."
        }
        decision.sleepBoundaryNote = note
        return note
    }

    /// Puts it back the way it was, and lets the question be asked properly.
    static func undoSleepBoundary(on decision: inout Decision) {
        if decision.optionA.drain == .costsSleep { decision.optionA.drain = .fine }
        if decision.optionB.drain == .costsSleep { decision.optionB.drain = .fine }
        decision.answeredQuestions.removeAll { $0 == QuestionKind.drain.rawValue }
        decision.sleepBoundaryNote = nil
    }

    private static func name(_ option: DecisionOption, fallback: String) -> String {
        option.name.isEmpty ? fallback : option.name
    }
}

// MARK: - Things worth saying out loud

enum AttentionNotes {

    /// Whether something fits the evening it's meant to happen in.
    ///
    /// The principle the app is trying to hold onto: don't squeeze in tonight what can
    /// be done tomorrow. Stated as a fact about the diary rather than as advice, and
    /// only ever when the diary was genuinely read — an unknown evening reports itself
    /// as entirely free, which is the one answer that would push the wrong way.
    static func fit(minutes: Double, summary: AttentionSummary?, enabled: Bool) -> String? {
        guard enabled, minutes > 0,
              let summary, let tonight = summary.freeTodayMinutes else { return nil }
        // A quarter of an hour of slack, so a plan that just about fits isn't nagged at.
        guard minutes > Double(tonight) + 15 else { return nil }

        let needed = Fmt.minutes(minutes)
        let free = Fmt.minutes(Double(tonight))
        if let tomorrow = summary.freeTomorrowMinutes, Double(tomorrow) >= minutes {
            return "This needs \(needed) and tonight has \(free) free. Tomorrow evening has \(Fmt.minutes(Double(tomorrow))) — it doesn't have to be tonight."
        }
        return "This needs \(needed) and tonight has \(free) free before you wind down."
    }

    /// What the time being bought back is actually for.
    ///
    /// The leisure rate quietly assumes freed time gets used well. Where there's
    /// nothing waiting for it, that assumption is worth saying out loud rather than
    /// silently discounting — the user knows things the shortlist doesn't.
    static func freedTime(for evaluation: Evaluation, summary: AttentionSummary?, enabled: Bool) -> String? {
        guard enabled, let summary, summary.hasDigest else { return nil }
        guard evaluation.winner == .a || evaluation.winner == .b else { return nil }

        let winner = evaluation.winner == .a ? evaluation.a : evaluation.b
        let loser = evaluation.winner == .a ? evaluation.b : evaluation.a
        let hoursSaved = loser.rawHours - winner.rawHours
        let moneySpent = winner.money - loser.money
        // Only where time is genuinely being bought, and enough of it to plan around.
        guard hoursSaved >= 1, moneySpent > 0 else { return nil }

        if summary.outstandingEveningIdeas > 0 {
            let ideas = summary.outstandingEveningIdeas
            return ideas == 1
                ? "One thing on your shortlist is waiting for the \(Fmt.duration(hours: hoursSaved)) this buys back."
                : "\(ideas) things on your shortlist are waiting for the \(Fmt.duration(hours: hoursSaved)) this buys back."
        }
        return "Nothing on your shortlist is waiting for the \(Fmt.duration(hours: hoursSaved)) this buys back. Worth knowing before paying for it."
    }
}
