import Foundation

enum Fmt {

    /// Two formatters, built once.
    ///
    /// Building a NumberFormatter costs about 40µs. That sounds like nothing until you
    /// notice a verdict screen formats sixty-odd sums, and that the whole decision
    /// engine — every occurrence, the sensitivity sweep, two hundred probes for the
    /// payback month — runs in two. Formatting the answer cost a thousand times more
    /// than working it out. Configured once and then only read from, which
    /// NumberFormatter has been safe for since iOS 7.
    private static let pencePrecision: NumberFormatter = currencyFormatter(pence: true)
    private static let poundsOnly: NumberFormatter = currencyFormatter(pence: false)

    private static func currencyFormatter(pence: Bool) -> NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "GBP"
        f.currencySymbol = "£"
        f.locale = Locale(identifier: "en_GB")
        // Money rounds the way people do, not to the nearest even digit: £1,234.50 is £1,235.
        f.roundingMode = .halfUp
        f.minimumFractionDigits = pence ? 2 : 0
        f.maximumFractionDigits = pence ? 2 : 0
        return f
    }

    static func money(_ value: Double, decimals: Bool? = nil) -> String {
        let magnitude = abs(value)
        let showPence = decimals ?? (magnitude < 100 && magnitude.truncatingRemainder(dividingBy: 1) != 0)
        let f = showPence ? pencePrecision : poundsOnly
        return f.string(from: NSNumber(value: value)) ?? "£0"
    }

    /// Money with no pence, for headline figures.
    static func moneyRounded(_ value: Double) -> String { money(value, decimals: false) }

    static func rate(_ value: Double) -> String {
        money(value, decimals: value < 100) + "/hr"
    }

    /// Human durations: "35 min", "1h 20m", "6 hours", "3.5 days"
    static func duration(hours: Double) -> String {
        let h = abs(hours)
        if h < 0.008 { return "no time" }
        if h < 1 {
            return "\(Int((h * 60).rounded())) min"
        }
        if h < 10 {
            let whole = Int(h)
            let mins = Int(((h - Double(whole)) * 60).rounded())
            if mins == 0 { return whole == 1 ? "1 hour" : "\(whole) hours" }
            if mins == 60 { return "\(whole + 1) hours" }
            return "\(whole)h \(mins)m"
        }
        if h < 48 { return String(format: "%.0f hours", h) }
        return String(format: "%.1f days", h / 24)
    }

    static func minutes(_ mins: Double) -> String { duration(hours: mins / 60) }

    static func days(_ value: Double) -> String {
        if value < 1 { return String(format: "%.1f days", value) }
        if value < 14 { return value < 1.5 ? "1 day" : String(format: "%.0f days", value.rounded()) }
        if value < 60 { return String(format: "%.0f weeks", (value / 7).rounded()) }
        return String(format: "%.1f months", value / 30.44)
    }

    /// A span of months, said the way people say it.
    static func months(_ value: Double) -> String {
        let m = max(0, value)
        if m < 12 { return plural(Int(m.rounded()), "month") }
        let years = m / 12
        return abs(years.rounded() - years) < 0.05
            ? plural(Int(years.rounded()), "year")
            : String(format: "%.1f years", years)
    }

    static func plural(_ n: Int, _ singular: String, _ pluralForm: String? = nil) -> String {
        n == 1 ? "1 \(singular)" : "\(n) \(pluralForm ?? singular + "s")"
    }

    /// Capitalises a derived descriptor for use at the start of a sentence or as a heading.
    static func sentenceStart(_ name: String) -> String {
        guard let first = name.first else { return name }
        return first.uppercased() + name.dropFirst()
    }
}

/// Sentences shared between the live verdict bar, the full verdict sheet and history.
enum VerdictText {

    static func headline(for e: Evaluation, decision: Decision) -> String {
        guard let winner = winnerName(for: e, decision: decision) else { return "Too close to call" }
        return "\(winner) — by \(Fmt.money(e.advantage))"
    }

    static func winnerName(for e: Evaluation, decision: Decision) -> String? {
        switch e.winner {
        case .a: return Fmt.sentenceStart(displayName(for: .a, decision: decision, evaluation: e))
        case .b: return Fmt.sentenceStart(displayName(for: .b, decision: decision, evaluation: e))
        case .tooClose: return nil
        }
    }

    static func name(_ option: DecisionOption, fallback: String) -> String {
        option.name.trimmingCharacters(in: .whitespaces).isEmpty ? fallback : option.name
    }

    /// What to call an option in prose.
    ///
    /// Most people arrive with two things, not with a "faster one" and a "cheaper one".
    /// So nothing is presupposed: if they've typed a name it's used, and otherwise the
    /// descriptor is *derived from the numbers they actually entered*. That way the
    /// wording can never contradict the data.
    static func displayName(for side: Side, decision: Decision, evaluation: Evaluation) -> String {
        let option = side == .a ? decision.optionA : decision.optionB
        let typed = option.name.trimmingCharacters(in: .whitespaces)
        if !typed.isEmpty { return typed }

        // Then what the scenario calls it. "The cheaper one" is true and unhelpful: it
        // describes the winner without identifying it, and somebody comparing £210 once
        // against £9 a month has to work out for themselves which of the two that was.
        // Nearly every scenario already has a plain name for each side — "Buy it
        // outright", "Subscribe" — and using it can't contradict the numbers, because
        // it is the label on the card they typed them into.
        let template = decision.scenario.template
        if template.optionsAreNamed {
            return side == .a ? template.optionA : template.optionB
        }

        let cheaper: Side? = abs(evaluation.deltaMoney) > 0.01
            ? (evaluation.deltaMoney < 0 ? .a : .b) : nil
        let quicker: Side? = abs(evaluation.deltaHours) > 0.005
            ? (evaluation.deltaHours < 0 ? .a : .b) : nil

        // "Cheaper" is the wrong word when the money is coming in. Netting thirty
        // pounds more is not costing less, and calling a side job "the cheaper one"
        // is the kind of sentence that makes someone stop believing the rest.
        let anyIncome = evaluation.a.money < 0 || evaluation.b.money < 0
        let better = anyIncome ? "better-paid" : "cheaper"
        let worse = anyIncome ? "worse-paid" : "dearer"

        switch (quicker == side, cheaper == side) {
        case (true, true): return "the quicker, \(better) one"
        case (true, false): return "the quicker one"
        case (false, true): return "the \(better) one"
        case (false, false): break
        }

        // Neither quicker nor cheaper. Name only the dimensions that genuinely
        // differ — calling something "slower" when the times are identical is
        // exactly the kind of assertion this function exists to avoid.
        let isSlower = quicker != nil && quicker != side
        let isDearer = cheaper != nil && cheaper != side
        switch (isSlower, isDearer) {
        case (true, true): return "the slower, \(worse) one"
        case (true, false): return "the slower one"
        case (false, true): return "the \(worse) one"
        case (false, false): return side == .a ? "Option A" : "Option B"
        }
    }

    /// Lowercases a leading article so a default name reads naturally mid-sentence.
    /// "Uber" is left alone; "The cheaper one" becomes "the cheaper one".
    static func midSentence(_ name: String) -> String {
        for article in ["The ", "A ", "An "] where name.hasPrefix(article) {
            return name.prefix(1).lowercased() + name.dropFirst()
        }
        return name
    }

    /// A factual way to point at an option: the numbers the person actually typed.
    ///
    /// "The quicker one" is clear while you're looking at the figures and useless a
    /// week later, so anything that has to survive — the answer, the history, the
    /// record of what you chose — identifies options by their numbers instead.
    static func fingerprint(_ option: DecisionOption, frequency: Frequency) -> String {
        var parts: [String] = []

        // A price charged per go and one charged per period are the same number and
        // very different sums, so the record has to say which it was. It also has to
        // say how many goes, or "£6 each time" is not a figure anybody can check.
        let repeats = option.timesEach > 1
        if option.money != 0 {
            let suffix: String
            if repeats && option.isChargedEachTime { suffix = " each time" }
            else if !frequency.isRecurring { suffix = "" }
            else { suffix = " a \(frequency.shortLabel)" }
            let prefix = option.direction == .receive ? "+" : ""
            parts.append(prefix + Fmt.money(option.money) + suffix)
        }
        if option.setupMoney != 0 {
            let prefix = option.effectiveSetupDirection == .receive ? "+" : ""
            parts.append(prefix + Fmt.money(option.setupMoney) + " up front")
        }
        if option.minutes > 0 {
            // "Each time" only says something when there's more than one time in the
            // period; otherwise it should match the cadence the money is quoted at.
            let suffix: String
            if repeats { suffix = " each time" }
            else if !frequency.isRecurring { suffix = "" }
            else { suffix = " a \(frequency.shortLabel)" }
            parts.append(Fmt.minutes(option.minutes) + suffix)
        }
        if repeats {
            let count = Fmt.plural(Int(option.timesEach.rounded()), "time")
            parts.append(frequency.isRecurring ? "\(count) a \(frequency.shortLabel)" : count)
        }
        if option.setupMinutes > 0 {
            parts.append(Fmt.minutes(option.setupMinutes) + " up front")
        }
        if let lifespan = option.lifespanMonths {
            parts.append("lasts \(Fmt.months(lifespan))")
        }

        return parts.isEmpty ? "nothing" : parts.joined(separator: ", ")
    }

    /// Name and numbers together, so an option is recognisable however it was entered.
    static func fullLabel(for side: Side, decision: Decision, evaluation: Evaluation) -> String {
        let option = side == .a ? decision.optionA : decision.optionB
        let typed = option.name.trimmingCharacters(in: .whitespaces)
        let numbers = fingerprint(option, frequency: decision.frequency)
        return typed.isEmpty ? numbers : "\(typed) (\(numbers))"
    }

    /// What gets stored in history: identifiable months later, with no naming required.
    static func recap(for e: Evaluation, decision: Decision) -> String {
        let a = fullLabel(for: .a, decision: decision, evaluation: e)
        let b = fullLabel(for: .b, decision: decision, evaluation: e)

        guard e.winner != .tooClose else {
            return decision.isYesNo ? "Too close to call — \(a)" : "Too close to call — \(a) or \(b)"
        }
        if decision.isYesNo {
            return e.winner == .a ? "Yes — \(a)" : "No — \(a)"
        }
        let winner = e.winner == .a ? a : b
        let loser = e.winner == .a ? b : a
        return "\(winner) over \(loser)"
    }

    /// How to describe a money tiebreak. "Cheaper" is wrong when the decision is
    /// about being paid — netting thirty pounds more is not costing less.
    static func moneyEdge(for e: Evaluation) -> String {
        let gap = Fmt.money(abs(e.deltaMoney))
        let anyIncome = e.a.money < 0 || e.b.money < 0
        return anyIncome ? "leaves you \(gap) better off" : "costs \(gap) less"
    }

    /// The most useful sentence in the app: the rate at which the answer flips.
    static func breakEven(for e: Evaluation, decision: Decision) -> String? {
        guard let rate = e.breakEvenRate, let side = e.fasterSide else { return nil }
        let other: Side = side == .a ? .b : .a
        let faster = displayName(for: side, decision: decision, evaluation: e)
        let slower = displayName(for: other, decision: decision, evaluation: e)

        if rate <= 0 {
            return "\(Fmt.sentenceStart(faster)) is quicker and no worse on money or feel. There's no trade-off to make here."
        }
        let lead = "\(Fmt.sentenceStart(faster)) is worth it only if an hour of your time is worth more than \(Fmt.rate(rate)). Yours is \(Fmt.rate(e.rate))"
        // Name whichever side the verdict actually chose. Inside the noise band that is
        // the tiebreak's choice, which can be the opposite side to the one the rate
        // alone points at, and the sentence must not contradict the headline.
        let chosen: Side = e.winner == .tooClose ? (e.rate >= rate ? side : other) : e.winner
        let winner = midSentence(chosen == side ? faster : slower)
        if e.tiebreak != nil {
            return "\(lead), which is close enough that it barely matters, so \(winner) wins."
        }
        return "\(lead), so \(winner) wins."
    }

    static func feelNudge(for e: Evaluation, decision: Decision) -> String? {
        guard e.breakEvenRate == nil, let points = e.breakEvenFeelPoints, abs(points) > 0.05 else { return nil }
        let loser = midSentence(displayName(for: points > 0 ? .a : .b, decision: decision, evaluation: e))
        let magnitude = abs(points)
        let descriptor: String
        switch magnitude {
        case ..<0.75: return "The feel slider decides this one — even a slight preference tips it."
        case ..<1.75: descriptor = "mildly better"
        case ..<2.75: descriptor = "clearly better"
        case ..<3.25: descriptor = "as good as your best evening out"
        default: return "\(Fmt.sentenceStart(loser)) would have to feel better than anything on the scale to be worth it."
        }
        return "\(Fmt.sentenceStart(loser)) only makes sense if it feels \(descriptor) — about \(String(format: "%+.1f", points)) on the slider."
    }
}
