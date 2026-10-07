import Foundation

/// The follow-up questions the app can ask after the core numbers are in.
enum QuestionKind: String, Codable, CaseIterable, Identifiable {
    case feel, joyOdds, social, health, growth, usage, howOften, usableTime, flexibility, repeats, scarcity, risk, people, drain, canItWait, displaces

    var id: String { rawValue }

    var prompt: String {
        switch self {
        case .feel: return "How would each one feel?"
        case .joyOdds: return "How likely is it to actually be good?"
        case .social: return "Does it matter to anyone else?"
        case .canItWait: return "If you skipped it, would you do it tomorrow?"
        case .displaces: return "What does the time come out of?"
        case .health: return "What does each do to your health?"
        case .growth: return "Would you learn anything worth knowing?"
        case .usage: return "Will you really use it that much?"
        case .howOften: return "How many times each, though?"
        case .flexibility: return "Can you come and go as you like?"
        case .usableTime: return "Can you use that time?"
        case .repeats: return "Will you do this again?"
        case .scarcity: return "Does this chance come round again?"
        case .risk: return "What if it goes wrong?"
        case .people: return "Whose time does this take?"
        case .drain: return "Will it take it out of you?"
        }
    }

    var note: String {
        switch self {
        case .feel: return "These are close enough on the numbers that how you feel about them decides it."
        case .joyOdds: return "A night out is a gamble in a way a coat isn't. Saying so is more honest than quietly marking down how much you'd enjoy it."
        case .displaces: return "Hours spent on one thing are hours taken from another. Work you push back doesn't disappear — it comes back later, in less time than it needed."
        case .canItWait: return "Most things that feel urgent aren't. Something you'd genuinely do tomorrow gains you very little by being squeezed in tonight — and tomorrow costs you no sleep."
        case .social: return "Not your enjoyment — theirs. An evening you'd call mildly pleasant can be the one somebody else remembers."
        case .health: return "Not the same question as how it feels. And unlike enjoyment, this compounds — the fiftieth time counts as much as the first."
        case .growth: return "A capability you keep is worth more than an afternoon you enjoyed — but only if it's taking you somewhere. Getting good at something you don't need is just a longer way of being busy."
        case .usage: return "The honest answer here decides more purchases than the price does."
        case .howOften: return "These two may not happen at the same rate — one delivery a week against three trips to the shop."
        case .flexibility: return "Being tied to a timetable costs you time you'd never think to write down."
        case .usableTime: return "Time you can read, work or rest through isn't time lost."
        case .repeats: return "One of these is fine occasionally and expensive as a habit."
        case .scarcity: return "A rare chance is worth more. It doesn't cost less."
        case .risk: return "Reliability is usually the real reason people pay more."
        case .people: return "Count only people who'd actually spend the time."
        case .drain: return "An hour that wrecks your evening costs more than an hour."
        }
    }
}

struct PlannedQuestion: Identifiable, Equatable {
    let kind: QuestionKind
    /// True when some answer to this question changes who wins.
    let flips: Bool
    /// How much the margin moves across the answer range, as a share of the decision
    /// rather than in pounds. Only ever a sort key — nothing shows this to anybody.
    let spread: Double

    var id: String { kind.rawValue }
}

/// Decides what to ask next, on one rule: **ask a question only if its answer
/// could change the verdict.** Every candidate is tried at both ends of its
/// plausible range; if the winner never moves, the question is never put.
enum QuestionPlanner {

    static let maximumFollowUps = 3

    /// The decisions spanning the **plausible** answer range for a question — not the
    /// maximal one. Ranking on extremes let "what if it goes wrong" outrank everything,
    /// because its worst case ("I cannot miss this", "goes wrong often") is enormous and
    /// almost never true. Moderate ranges put the questions in the order that actually
    /// helps.
    static func variants(of decision: Decision, for kind: QuestionKind) -> [Decision] {
        switch kind {
        case .feel:
            var best = decision; best.optionA.feel = 2; best.optionB.feel = -2
            var worst = decision; worst.optionA.feel = -2; worst.optionB.feel = 2
            return [best, worst]

        case .joyOdds:
            var sure = decision
            sure.optionA.joyConfidence = .certain; sure.optionB.joyConfidence = .certain
            var unsure = decision
            unsure.optionA.joyConfidence = .couldGoEitherWay
            unsure.optionB.joyConfidence = .couldGoEitherWay
            return [sure, unsure]

        case .displaces:
            var aPushes = decision
            aPushes.optionA.displaces = .somethingFlexible; aPushes.optionB.displaces = .nothing
            var bPushes = decision
            bPushes.optionA.displaces = .nothing; bPushes.optionB.displaces = .somethingFlexible
            return [aPushes, bPushes]

        case .canItWait:
            var aWaits = decision
            aWaits.optionA.deferability = .wouldDoTomorrow; aWaits.optionB.deferability = .nowOrNever
            var bWaits = decision
            bWaits.optionA.deferability = .nowOrNever; bWaits.optionB.deferability = .wouldDoTomorrow
            return [aWaits, bWaits]

        case .social:
            // Moderate, not maximal: "they'd really want me there" is a strong answer
            // and a rare one, and ranking on it put this question ahead of how you'd
            // feel about a two-pound difference.
            var aMatters = decision
            aMatters.optionA.socialValue = .quiteAbit; aMatters.optionB.socialValue = .none
            var bMatters = decision
            bMatters.optionA.socialValue = .none; bMatters.optionB.socialValue = .quiteAbit
            return [aMatters, bMatters]

        case .health:
            var aGood = decision; aGood.optionA.health = .good; aGood.optionB.health = .bad
            var bGood = decision; bGood.optionA.health = .bad; bGood.optionB.health = .good
            return [aGood, bGood]

        case .growth:
            var aLearn = decision; aLearn.optionA.growth = .lots; aLearn.optionB.growth = .none
            var bLearn = decision; bLearn.optionA.growth = .none; bLearn.optionB.growth = .lots
            return [aLearn, bLearn]

        case .usage:
            var sure = decision
            sure.optionA.usageConfidence = .certain; sure.optionB.usageConfidence = .certain
            var doubtful = decision
            doubtful.optionA.usageConfidence = .maybe; doubtful.optionB.usageConfidence = .maybe
            return [sure, doubtful]

        case .howOften:
            var aMore = decision; aMore.optionA.timesEach = 3; aMore.optionB.timesEach = 1
            var bMore = decision; bMore.optionA.timesEach = 1; bMore.optionB.timesEach = 3
            return [aMore, bMore]

        case .flexibility:
            var aFixed = decision
            aFixed.optionA.flexibility = .tiedToTimetable; aFixed.optionB.flexibility = .free
            var bFixed = decision
            bFixed.optionA.flexibility = .free; bFixed.optionB.flexibility = .tiedToTimetable
            return [aFixed, bFixed]

        case .usableTime:
            var aFree = decision; aFree.optionA.usableTime = .most; aFree.optionB.usableTime = .none
            var bFree = decision; bFree.optionA.usableTime = .none; bFree.optionB.usableTime = .most
            return [aFree, bFree]

        case .repeats:
            var weekly = decision; weekly.frequency = .weekly; weekly.horizonMonths = 12
            var monthly = decision; monthly.frequency = .monthly; monthly.horizonMonths = 12
            var once = decision; once.frequency = .once
            return [once, weekly, monthly]

        case .scarcity:
            var common = decision; common.scarcity = .often
            var rare = decision; rare.scarcity = .everyFewYears
            return [common, rare]

        case .risk:
            var aRisky = decision
            aRisky.stakes = .costsMoney
            aRisky.optionA.reliability = .sometimes
            aRisky.optionB.reliability = .never
            var bRisky = decision
            bRisky.stakes = .costsMoney
            bRisky.optionA.reliability = .never
            bRisky.optionB.reliability = .sometimes
            return [aRisky, bRisky]

        case .people:
            var alone = decision; alone.peopleCount = 1
            var pair = decision; pair.peopleCount = 2
            return [alone, pair]

        case .drain:
            var aTiring = decision; aTiring.optionA.drain = .tiring; aTiring.optionB.drain = .restoring
            var bTiring = decision; bTiring.optionA.drain = .restoring; bTiring.optionB.drain = .tiring
            return [aTiring, bTiring]
        }
    }

    /// The time an option really takes in a period, rather than in one occurrence.
    ///
    /// Three shop trips a week is two hours of shopping, not forty minutes, and a
    /// threshold that can't tell those apart stops asking about the decisions where
    /// the time is most worth asking about.
    private static func minutes(of option: DecisionOption) -> Double {
        option.setupMinutes + option.minutes * max(1, option.timesEach)
    }

    /// Structural preconditions — questions that make no sense for this decision
    /// are never asked, however much leverage they might have.
    static func isRelevant(_ kind: QuestionKind, to decision: Decision) -> Bool {
        let totalMinutes = minutes(of: decision.optionA) + minutes(of: decision.optionB)

        switch kind {
        case .feel:
            return true
        case .joyOdds:
            // Only worth asking once there's enjoyment in play to be unsure about.
            return max(decision.optionA.feel, decision.optionB.feel) > 0
        case .displaces:
            // Only where enough time is at stake to displace anything.
            return max(minutes(of: decision.optionA), minutes(of: decision.optionB)) >= 60
        case .canItWait:
            // Only meaningful when something good is on the table to be postponed.
            return max(decision.optionA.feel, decision.optionB.feel) > 0
                || decision.optionA.health.points > 0 || decision.optionB.health.points > 0
                || decision.optionA.growth.points > 0 || decision.optionB.growth.points > 0
        case .social:
            // Only where there are other people in the picture at all.
            return decision.scenario.template.involvesOthers || decision.scenario == .custom
        case .health:
            return true
        case .growth:
            // You learn by doing the long thing yourself. Asking whether a taxi ride
            // or a party teaches you anything is the kind of question that makes
            // people stop trusting an app, so this needs a task to get better at,
            // a real stretch of time on one side, and a real gap between the two.
            guard decision.scenario.template.involvesEffort || decision.scenario == .custom else {
                return false
            }
            let longest = max(minutes(of: decision.optionA), minutes(of: decision.optionB))
            let gap = abs(minutes(of: decision.optionA) - minutes(of: decision.optionB))
            return longest >= 60 && gap >= 30
        case .howOften:
            // Multiplying an option's money and time together is right for three trips
            // to the shop and wrong for a standing charge: answering "three times each"
            // on the spare room turned £7,907 of rent into £24,439 of it.
            guard decision.scenario.template.isCountable || decision.scenario == .custom else {
                return false
            }
            // Already said on the entry form. Asking "how many times each, though?" of
            // somebody who has just typed 1 and 4 is arguing with an answer they gave.
            guard decision.optionA.timesEach == 1 && decision.optionB.timesEach == 1 else {
                return false
            }
            return decision.frequency.isRecurring
        case .flexibility:
            // Timetables are a going-somewhere problem. Asking whether a dishwasher
            // lets you come and go as you please is not a question worth putting.
            guard decision.scenario.template.involvesTravel || decision.scenario == .custom else {
                return false
            }
            return min(decision.optionA.minutes, decision.optionB.minutes) >= 15
        case .usage:
            // Only meaningful once something is bought up front and used repeatedly.
            let bought = decision.optionA.setupMoney + decision.optionB.setupMoney
            return bought > 0 && decision.frequency.isRecurring && decision.setupFrequency == .once
        case .usableTime:
            // Only worth asking when there's a meaningful stretch of time to use.
            return totalMinutes >= 20
        case .repeats:
            return decision.frequency == .once
        case .scarcity:
            // An occasion, not an errand. "Does this chance come round again?" is a
            // question about a gig or a wedding; asked about a parking space or a
            // grocery delivery it is faintly absurd, and the multiplier behind it is
            // strong enough — two and a half times — that it has no business being
            // applied to either.
            guard decision.scenario.template.isAnOccasion || decision.scenario == .custom else {
                return false
            }
            // Scarcity multiplies enjoyment, so it's meaningless until there is some.
            return max(decision.optionA.feel, decision.optionB.feel) > 0
        case .risk:
            // Needs something that can actually fail to be delivered. Without that
            // test this asked how often a birthday party lets you down — which is
            // both a category error and a poaching of `joyOdds`, whose whole job is
            // that a night out is a gamble in a way a coat isn't.
            guard decision.scenario.template.canGoWrong || decision.scenario == .custom else {
                return false
            }
            let atStake = decision.optionA.money + decision.optionA.setupMoney
                + decision.optionB.money + decision.optionB.setupMoney
            return decision.stakes == .none && (atStake > 0 || totalMinutes >= 30)
        case .people:
            return totalMinutes >= 15
        case .drain:
            return totalMinutes >= 60
        }
    }

    /// True when the two options are so alike there is nothing worth asking about.
    ///
    /// Note this is about the options being *similar*, not about the verdict being
    /// close. Cheap-and-slow against dear-and-quick can come out level while still
    /// being a real trade-off worth a question or two; two shops eighty pence apart
    /// are not.
    static func isEffectivelyIdentical(_ decision: Decision, profile: Profile, rate: Double,
                                       calibration: TimeCalibration = .none) -> Bool {
        let c = DecisionEngine.core(decision, profile: profile, rate: rate, calibration: calibration)
        let moneyGap = abs(c.a.money - c.b.money)
        let hoursGap = abs(c.a.rawHours - c.b.rawHours)
        let scale = max(abs(c.a.money), abs(c.b.money), 10)
        return moneyGap <= max(1, 0.02 * scale) && hoursGap <= 10.0 / 60
    }

    /// The margin as a share of the decision it belongs to — signed, so a swing from
    /// "A by a tenth" to "B by a tenth" reads as a fifth of movement.
    ///
    /// Measured in pounds this was not a fair comparison. Two questions multiply the
    /// whole decision — will you do this again, how many times each — and the rest add
    /// a bounded amount to one side of it. So the multiplying ones won the ordering on
    /// arithmetic rather than on information: "will you do this again" beat "would you
    /// do it tomorrow anyway" by a median of seven times, for the sole reason that
    /// fifty-two pints cost fifty-two times one pint. As a share, pure scaling cancels
    /// and only a real change in the balance counts — which is what the ordering was
    /// always trying to ask.
    ///
    /// Nothing is lost by asking it less: the verdict already says what this becomes as
    /// a weekly habit, for every one-off, without spending a question to find out.
    static func relativeMargin(_ core: DecisionEngine.Core) -> Double {
        let signed = core.winner == .b ? -core.advantage : core.advantage
        return signed / max(abs(core.a.netCost), abs(core.b.netCost), 10)
    }

    static func rank(for decision: Decision, profile: Profile, rate: Double,
                     calibration: TimeCalibration = .none) -> [PlannedQuestion] {
        // Nothing has been entered, so nothing can change. Ask nothing.
        guard !(decision.optionA.isEmpty && decision.optionB.isEmpty) else { return [] }

        // The options are near enough the same thing. Interrogating someone about a
        // choice that barely matters is exactly the friction this is meant to avoid —
        // the answer is "take the cheaper one", and it can be given straight away.
        guard !isEffectivelyIdentical(decision, profile: profile, rate: rate,
                                      calibration: calibration) else { return [] }

        let baseline = DecisionEngine.core(decision, profile: profile, rate: rate,
                                           calibration: calibration)

        var results: [PlannedQuestion] = []
        for kind in QuestionKind.allCases {
            guard isRelevant(kind, to: decision) else { continue }
            guard !decision.answeredQuestions.contains(kind.rawValue) else { continue }

            var flips = false
            var low = relativeMargin(baseline)
            var high = low

            for variant in variants(of: decision, for: kind) {
                let result = DecisionEngine.core(variant, profile: profile, rate: rate,
                                                 calibration: calibration)
                // A different answer only counts if at least one side of the comparison
                // was decided by the arithmetic. Two coin tosses landing differently is
                // not a reason to ask anybody anything.
                if result.winner != baseline.winner && (result.isDecisive || baseline.isDecisive) {
                    flips = true
                }
                let signed = relativeMargin(result)
                low = min(low, signed)
                high = max(high, signed)
            }

            results.append(PlannedQuestion(kind: kind, flips: flips, spread: high - low))
        }

        // Questions that can change the answer come first; within those, the ones
        // that move it most.
        return results.sorted {
            if $0.flips != $1.flips { return $0.flips }
            return $0.spread > $1.spread
        }
    }

    /// The next question worth putting, or nil when nothing left could change the answer.
    ///
    /// Anything the scenario declares essential comes first. Those are the questions
    /// whose absence makes the answer meaningless rather than merely rougher — the odds
    /// on a warranty, how many times you'd really use the thing you're buying — and the
    /// flip rule can never reach them, because a decision that is lopsided without them
    /// stays lopsided under every answer they could take.
    static func next(for decision: Decision, profile: Profile, rate: Double,
                     calibration: TimeCalibration = .none) -> QuestionKind? {
        guard decision.answeredQuestions.count < maximumFollowUps else { return nil }
        guard !(decision.optionA.isEmpty && decision.optionB.isEmpty) else { return nil }

        if let essential = decision.scenario.template.essentialQuestions.first(where: {
            !decision.answeredQuestions.contains($0.rawValue) && isRelevant($0, to: decision)
        }) {
            return essential
        }

        return rank(for: decision, profile: profile, rate: rate, calibration: calibration)
            .first(where: { $0.flips })?.kind
    }
}
