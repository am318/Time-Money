import Foundation

/// Which term did the most to produce a verdict.
///
/// Attribution is what makes learning from reviews possible at all. Knowing that a
/// decision turned out badly tells you nothing on its own; knowing that it was
/// decided by the enjoyment term, and that enjoyment-led decisions keep turning out
/// badly, tells you the enjoyment anchor is too high.
enum DecidingFactor: String, Codable, CaseIterable, Identifiable, Equatable {
    case money, time, joy, social, health, growth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .money: return "the money"
        case .time: return "the time"
        case .joy: return "how much you'd enjoy it"
        case .social: return "what it meant to other people"
        case .health: return "what it does for your health"
        case .growth: return "what you'd learn"
        }
    }

    /// Which anchor this factor would adjust, if any. Money and time are handled
    /// by the rate rather than by an anchor.
    var isAnchor: Bool { self != .money }
}

/// A conservative suggestion, or none at all.
struct AnchorSuggestion: Identifiable, Equatable {
    let factor: DecidingFactor
    let current: Double
    let suggested: Double
    /// Reviews that said something either way.
    let signals: Int
    /// Reviews where you couldn't call it, which are deliberately ignored.
    let setAside: Int
    let detail: String

    var id: String { factor.rawValue }
    var isRaise: Bool { suggested > current }
}

struct Calibration: Equatable {
    let signals: Int
    let towardsMoreTime: Int
    let towardsMoreMoney: Int
    let suggestedRate: Double?

    /// Anchor suggestions, only where the evidence supports one.
    let anchorSuggestions: [AnchorSuggestion]
    /// Reviews you couldn't call either way. These change nothing, by design.
    let setAside: Int

    let headline: String
    let detail: String

    static let minimumSignals = 10
    static let leanThreshold = 0.7

    /// How much evidence it takes before a suggestion carries full weight.
    ///
    /// With this at twelve, ten reviews count for less than half of what the raw
    /// lean would suggest. That is the point: a handful of reviews is a hint, not
    /// a finding, and an app that lurches on six data points is worse than one
    /// that never moves at all.
    static let shrinkageConstant: Double = 12

    /// The most any anchor can move on a single suggestion.
    static let maximumTilt: Double = 0.35

    /// Below this, the evidence isn't worth acting on and nothing is offered.
    static let minimumMeaningfulChange: Double = 0.05

    static let empty = Calibration(signals: 0, towardsMoreTime: 0, towardsMoreMoney: 0,
                                   suggestedRate: nil, anchorSuggestions: [], setAside: 0,
                                   headline: "Nothing to go on yet",
                                   detail: "Reviews build up here.")
}

enum Calibrator {

    // MARK: - Attribution

    /// The term that did the most work, or nil when no single term clearly decided it.
    ///
    /// The threshold matters: attributing a close-run decision to whichever term
    /// happened to edge it would feed the anchors mostly noise.
    static func decidingFactor(for decision: Decision, profile: Profile, rate: Double) -> DecidingFactor? {
        let c = DecisionEngine.core(decision, profile: profile, rate: rate)
        let contributions: [(DecidingFactor, Double)] = [
            (.money, abs((c.a.money + c.a.opportunityCost) - (c.b.money + c.b.opportunityCost))),
            (.time, abs(c.a.hours - c.b.hours) * rate),
            (.joy, abs(c.a.joy - c.b.joy)),
            (.social, abs(c.a.social - c.b.social)),
            (.health, abs(c.a.health - c.b.health)),
            (.growth, abs(c.a.growth - c.b.growth))
        ]
        let total = contributions.reduce(0) { $0 + $1.1 }
        guard total > 0.01, let top = contributions.max(by: { $0.1 < $1.1 }) else { return nil }
        return top.1 / total >= 0.4 ? top.0 : nil
    }

    /// Which side of a decision scored higher on a given factor.
    private static func strongerSide(for factor: DecidingFactor,
                                     decision: Decision, profile: Profile, rate: Double) -> Side? {
        let c = DecisionEngine.core(decision, profile: profile, rate: rate)
        let a: Double, b: Double
        switch factor {
        case .joy: (a, b) = (c.a.joy, c.b.joy)
        case .social: (a, b) = (c.a.social, c.b.social)
        case .health: (a, b) = (c.a.health, c.b.health)
        case .growth: (a, b) = (c.a.growth, c.b.growth)
        case .money: (a, b) = (-(c.a.money), -(c.b.money))
        case .time: (a, b) = (-c.a.hours, -c.b.hours)
        }
        guard abs(a - b) > 0.01 else { return nil }
        return a > b ? .a : .b
    }

    // MARK: - Reading a single review

    /// Whether a review says the factor was valued too high or too low.
    ///
    /// Returns nil for anything that says nothing: an unreviewed decision, one you
    /// couldn't call either way, or one no single term decided. Silence is treated
    /// as silence rather than as weak evidence for the status quo.
    static func verdict(on factor: DecidingFactor, decision: Decision,
                        profile: Profile, rate: Double) -> Bool? {
        guard let stronger = strongerSide(for: factor, decision: decision, profile: profile, rate: rate)
        else { return nil }

        let chosen = decision.chosenSide.flatMap(Side.init(rawValue:))
        let recommended = decision.recommendedSide.flatMap(Side.init(rawValue:))

        // Overriding the app is the strongest statement available: you did the thing
        // it advised against, which says the factor favouring that side was undersold.
        if let chosen, let recommended, chosen != recommended,
           chosen != .tooClose, recommended != .tooClose {
            return chosen == stronger
        }

        switch decision.review {
        case .wrongCall:
            // You regret what you did. If what you did was the factor-favoured side,
            // the factor was overvalued; if it wasn't, it was undervalued.
            guard let acted = chosen ?? recommended, acted != .tooClose else { return nil }
            return acted != stronger
        case .rightCall:
            // Weak confirmation. Counted so that a run of good calls resists a
            // handful of bad ones, rather than being ignored entirely.
            guard let acted = chosen ?? recommended, acted != .tooClose else { return nil }
            return acted == stronger ? nil : nil
        case .cantTell, nil:
            // Explicitly nothing. Saying you can't tell must never move an anchor,
            // or people stop saying it.
            return nil
        }
    }

    // MARK: - Turning a lean into a conservative factor

    /// Shrinks a raw lean towards no change, by how little evidence there is.
    ///
    /// A fifty-fifty split returns exactly 1.0 whatever the sample size, so a user
    /// with no strong opinions never drifts.
    static func adjustment(raisers: Int, loweres: Int) -> Double {
        let n = Double(raisers + loweres)
        guard n > 0 else { return 1 }
        let lean = Double(raisers) / n            // 0...1
        let tilt = (lean - 0.5) * 2               // -1...1
        let confidence = n / (n + Calibration.shrinkageConstant)
        return 1 + Calibration.maximumTilt * tilt * confidence
    }

    static func anchorValue(for factor: DecidingFactor, profile: Profile) -> Double? {
        switch factor {
        case .joy, .social: return profile.joyAnchor   // social is priced off the same anchor
        case .health: return profile.healthAnchor
        case .growth: return profile.growthAnchor
        case .money, .time: return nil
        }
    }

    // MARK: - The whole picture

    static func calibration(for decisions: [Decision], profile: Profile, currentRate: Double) -> Calibration {
        let reviewed = decisions.filter { $0.review != nil || $0.chosenSide != nil }
        let setAside = decisions.filter { $0.review == .cantTell }.count

        // --- the rate, from money-versus-time regrets
        var towardsTime = 0
        var towardsMoney = 0
        for decision in reviewed {
            switch direction(for: decision, profile: profile) {
            case .shouldHaveSpent: towardsTime += 1
            case .shouldHaveSaved: towardsMoney += 1
            case .unclear, nil: continue
            }
        }
        let rateSignals = towardsTime + towardsMoney
        var suggestedRate: Double? = nil
        if rateSignals >= Calibration.minimumSignals {
            let factor = adjustment(raisers: towardsTime, loweres: towardsMoney)
            if abs(factor - 1) >= Calibration.minimumMeaningfulChange {
                suggestedRate = max(1, (currentRate * factor * 2).rounded() / 2)
            }
        }

        // --- the anchors, from whichever term decided each decision
        var suggestions: [AnchorSuggestion] = []
        for factor in DecidingFactor.allCases where factor.isAnchor {
            guard let current = anchorValue(for: factor, profile: profile), current > 0 else { continue }

            var raise = 0, lower = 0
            for decision in reviewed {
                guard decidingFactor(for: decision, profile: profile, rate: currentRate) == factor,
                      let undervalued = verdict(on: factor, decision: decision,
                                                profile: profile, rate: currentRate)
                else { continue }
                if undervalued { raise += 1 } else { lower += 1 }
            }

            let signals = raise + lower
            guard signals >= Calibration.minimumSignals else { continue }

            let adjust = adjustment(raisers: raise, loweres: lower)
            guard abs(adjust - 1) >= Calibration.minimumMeaningfulChange else { continue }

            let suggested = max(0.5, (current * adjust * 4).rounded() / 4)
            guard abs(suggested - current) > 0.01 else { continue }

            let direction = suggested > current ? "more" : "less"
            suggestions.append(AnchorSuggestion(
                factor: factor,
                current: current,
                suggested: suggested,
                signals: signals,
                setAside: setAside,
                detail: "Of the \(signals) decisions that came down to \(factor.label), \(max(raise, lower)) went the same way — you've been valuing it \(direction) than the app does. That's a small sample, so this is a nudge rather than a correction."))
        }

        // --- the headline
        let headline: String
        let detail: String
        if rateSignals < Calibration.minimumSignals && suggestions.isEmpty {
            headline = rateSignals == 0 && setAside == 0
                ? "Nothing to go on yet"
                : "\(rateSignals) of \(Calibration.minimumSignals) so far"
            detail = setAside > 0
                ? "Once there are \(Calibration.minimumSignals) decisions with a clear verdict behind them, the app will start checking its own numbers. The \(setAside) you couldn't call either way are set aside and count for nothing — which is the point of having that option."
                : "Once there are \(Calibration.minimumSignals) decisions with a review or an override behind them, the app will start checking its own numbers against how they turned out."
        } else if suggestedRate == nil && suggestions.isEmpty {
            headline = "Your numbers look about right"
            detail = "Across \(rateSignals) decisions your regrets and overrides point both ways in roughly equal measure, which is what you'd expect from numbers that aren't badly wrong."
        } else if let suggestedRate {
            headline = suggestedRate > currentRate
                ? "Your time looks worth a little more than \(Fmt.rate(currentRate))"
                : "Your time looks worth a little less than \(Fmt.rate(currentRate))"
            detail = "\(max(towardsTime, towardsMoney)) of your last \(rateSignals) went the same way. That points at about \(Fmt.rate(suggestedRate)) — a deliberately small step, because \(rateSignals) decisions is a hint rather than a finding."
        } else {
            headline = "One of the numbers looks off"
            detail = "Your rate looks about right, but something below doesn't."
        }

        return Calibration(signals: rateSignals,
                           towardsMoreTime: towardsTime,
                           towardsMoreMoney: towardsMoney,
                           suggestedRate: suggestedRate,
                           anchorSuggestions: suggestions,
                           setAside: setAside,
                           headline: headline,
                           detail: detail)
    }

    // MARK: - Money versus time, which drives the rate

    static func direction(for decision: Decision, profile: Profile) -> RegretDirection? {
        let e = DecisionEngine.core(decision, profile: profile,
                                    rate: RateEngine.breakdown(for: profile).personalHourlyRate)
        let deltaMoney = e.a.money - e.b.money
        guard abs(deltaMoney) > 0.01 else { return nil }

        let dearer: Side = deltaMoney > 0 ? .a : .b
        let chosen = decision.chosenSide.flatMap(Side.init(rawValue:))
        let recommended = decision.recommendedSide.flatMap(Side.init(rawValue:))

        if let chosen, let recommended,
           chosen != recommended, chosen != .tooClose, recommended != .tooClose {
            return chosen == dearer ? .shouldHaveSpent : .shouldHaveSaved
        }
        if decision.review == .wrongCall, let acted = chosen ?? recommended, acted != .tooClose {
            return acted.other == dearer ? .shouldHaveSpent : .shouldHaveSaved
        }
        return nil
    }
}
