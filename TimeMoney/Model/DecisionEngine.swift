import Foundation

struct OptionTotals: Equatable {
    let money: Double         // signed over the whole horizon; positive means it costs you
    let rawHours: Double      // clock time, as entered
    let hours: Double         // what that time actually costs, after usable/drain/people
    /// What the money would have turned into had it stayed where it was.
    let opportunityCost: Double
    let joy: Double           // pounds-equivalent, positive is good
    /// What it's worth to everyone else. Kept apart from your own enjoyment,
    /// because they're different things and they often point different ways.
    let social: Double
    let health: Double        // pounds-equivalent, positive is good
    let growth: Double        // pounds-equivalent, positive is good
    let riskCost: Double      // expected cost of it going wrong
    let netCost: Double       // money + growth forgone + time - joy - social - health - learning + risk
    /// How many times this option really happens, after any doubt about the usage.
    let uses: Double

    /// What each use actually costs, once everything is counted. The number that
    /// decides clothes, tools and anything else bought to be used repeatedly.
    var costPerUse: Double? {
        guard uses >= 1.5, money > 0 else { return nil }
        return money / uses
    }
}

enum Side: String, Codable, Equatable {
    case a, b, tooClose

    var other: Side {
        switch self {
        case .a: return .b
        case .b: return .a
        case .tooClose: return .tooClose
        }
    }
}

/// Why an answer was given when the arithmetic couldn't separate the two.
///
/// Saying "too close to call" hands the decision straight back, which is the one
/// thing the app exists not to do. When the modelled difference is inside the noise,
/// there is almost always a plainer fact to fall back on — and taking the cheaper of
/// two equivalent options costs nothing.
enum Tiebreak: String, Equatable {
    /// Within the noise on everything, but one costs less actual money.
    case cheaper
    /// Within the noise on everything including money, but one takes less time.
    case quicker
    /// Genuinely nothing between them.
    case nothingInIt

    var summary: String {
        switch self {
        case .cheaper: return "Nothing in it, so take the cheaper one."
        case .quicker: return "Nothing in it, so take the quicker one."
        case .nothingInIt: return "There is genuinely nothing between these."
        }
    }
}

/// Everything the totals need that isn't on the option itself.
struct EvalContext {
    let occurrences: Double
    /// How many times the one-off fields actually land.
    let setupOccurrences: Double
    let rate: Double
    let joyAnchor: Double
    let healthAnchor: Double
    let growthAnchor: Double
    /// What being ahead or behind does to enjoyment.
    let standingMultiplier: Double
    /// What a pound spent today would have become by the end of the horizon —
    /// one factor for money paid up front, one for money spread across it.
    let setupOpportunity: Double
    let recurringOpportunity: Double
    /// Per-period growth in recurring amounts, from the annual inflation figure.
    let inflationPerPeriod: Double
    let inflationPerSetupPeriod: Double
    /// Needed per option: a lifespan belongs to the option, so the number of
    /// replacements and the gap between them do too.
    let horizonMonths: Double
    let inflationPercent: Double
    /// Whether the one-off fields already recur on the decision's own schedule.
    /// Rent every month and a pass bought every year are their own answer to how
    /// often the thing is paid for, and an option's lifespan must not overrule them.
    let setupRecurs: Bool
    let scarcity: Scarcity
    let peopleCount: Int
    let stakes: Stakes
    let referenceMoney: Double
    /// Corrections drawn from the user's own recorded days. `.none` when they haven't
    /// linked anything, which is the state every existing decision was evaluated in.
    let calibration: TimeCalibration
}

/// When an up-front investment starts being worth it.
enum Payback: Equatable {
    /// Nothing was paid up front, or nothing accrues over time.
    case notApplicable
    /// Worth it from the very first month.
    case immediate
    case months(Double)
    /// Still hasn't caught up after fifty years.
    case never

    var isWorthShowing: Bool { self != .notApplicable }
}

/// A way the answer could be wrong. Worth more than asking people how confident they are,
/// because they always say "quite".
struct Sensitivity: Equatable, Identifiable {
    let id: String
    let text: String
}

struct Evaluation: Equatable {

    let rate: Double
    let occurrences: Double
    let frequency: Frequency
    let horizonMonths: Double

    let a: OptionTotals
    let b: OptionTotals

    let winner: Side
    /// Set when the numbers couldn't separate them and a plainer fact decided it.
    let tiebreak: Tiebreak?
    let advantage: Double

    // Differences, always A minus B.
    let deltaMoney: Double
    let deltaHours: Double     // effective hours, the ones that drive the answer
    let deltaRawHours: Double  // clock time, for showing the user what they typed
    let deltaJoy: Double
    let deltaSocial: Double
    let deltaHealth: Double
    let deltaGrowth: Double
    let deltaOpportunity: Double
    let deltaRisk: Double

    /// The rate at which the two tie. The number that survives a wrong rate.
    let breakEvenRate: Double?
    let fasterSide: Side?

    let isDominant: Bool
    let pricePerHourSaved: Double?
    let breakEvenFeelPoints: Double?
    let workHoursForMoneyGap: Double
    let savingsDelayDays: Double?
    let ifWeeklyForAYear: (money: Double, hours: Double)?

    /// Ways this answer could be wrong.
    let sensitivities: [Sensitivity]

    /// When the thing you invest in up front comes out ahead. For anything bought
    /// once that then keeps giving — curtains, a dishwasher, a tool, an automation —
    /// this is the number that actually answers the question, because the verdict at
    /// whatever horizon you happened to pick does not.
    let payback: Payback

    static func == (l: Evaluation, r: Evaluation) -> Bool {
        l.rate == r.rate && l.a == r.a && l.b == r.b && l.winner == r.winner
            && l.sensitivities == r.sensitivities
    }
}

enum DecisionEngine {

    /// Repeated pleasures fade. A weekly treat is not fifty-two times as good as one,
    /// so joy is counted with diminishing returns rather than multiplied straight out.
    static let joyDiminishingExponent: Double = 0.6

    /// Learning fades faster still. You get most of a skill in the first few goes,
    /// and the hundredth repetition teaches you almost nothing new.
    static let growthDiminishingExponent: Double = 0.3

    /// The sum of `periods` payments that start at `amount` and grow each period.
    ///
    /// A subscription you'll hold for five years does not cost today's price sixty
    /// times over, and pretending it does quietly flatters every subscription
    /// against every outright purchase.
    static func inflatedTotal(amount: Double, periods: Double, ratePerPeriod rate: Double) -> Double {
        guard abs(rate) > 1e-9 else { return amount * periods }
        return amount * (pow(1 + rate, periods) - 1) / rate
    }

    /// Converts an annual figure into the per-period rate for a given frequency.
    static func perPeriodRate(annualPercent: Double, frequency: Frequency) -> Double {
        guard frequency.isRecurring, annualPercent != 0 else { return 0 }
        return pow(1 + annualPercent / 100, 1 / frequency.perYear) - 1
    }

    static func occurrences(frequency: Frequency, horizonMonths: Double) -> Double {
        guard frequency.isRecurring else { return 1 }
        let years = max(0, horizonMonths) / 12
        return max(1, frequency.perYear * years)
    }

    static func totals(for option: DecisionOption, context c: EvalContext) -> OptionTotals {
        totals(for: option, context: c, scarcity: c.scarcity.multiplier)
    }

    static func totals(for option: DecisionOption, context c: EvalContext, scarcity: Double) -> OptionTotals {
        let sign = option.direction.sign
        // The one-off leg can point the other way: fees out now, a rise in every month after.
        let setupSign = option.effectiveSetupDirection.sign

        // How many times you actually do it over the horizon. The clock, the enjoyment,
        // the health and the learning all follow this, because they all happen per go.
        let goes = c.occurrences * max(0, option.timesEach)

        // Doubt about how much you'll really use it shrinks the uses, not the price —
        // which is the whole reason an impulse buy and a staple at the same price are
        // not the same purchase.
        //
        // It has to leave the bill strictly alone. Billing the doubt as well as the
        // benefit made a subscription cheaper the less you expected to use it, which
        // is precisely backwards: a direct debit does not ask whether you opened the
        // app, and the subscription you don't use is the most expensive kind there is.
        let uses = goes * option.usageConfidence.multiplier

        // Money does not follow the goes, and treating it as though it did was wrong
        // twice over. A membership is billed monthly however often you turn up, so
        // multiplying it by the visits invented eight subscriptions. And the rate is
        // inflation per *period*, so compounding it once per go charged a single year
        // at eight years' worth. One period's charge, inflated over the periods.
        let recurringMoney = inflatedTotal(amount: option.moneyPerPeriod,
                                           periods: c.occurrences,
                                           ratePerPeriod: c.inflationPerPeriod)
        // How many times this one gets bought. An option that wears out on its own
        // schedule replaces the decision-wide answer with its own.
        let setupOccurrences = c.setupRecurs
            ? c.setupOccurrences
            : option.purchases(over: c.horizonMonths, fallback: c.setupOccurrences)
        let setupInflation = c.setupRecurs
            ? c.inflationPerSetupPeriod
            : option.lifespanMonths.map { pow(1 + c.inflationPercent / 100, $0 / 12) - 1 }
                ?? c.inflationPerSetupPeriod
        let setupMoneyTotal = inflatedTotal(amount: option.setupMoney,
                                            periods: setupOccurrences,
                                            ratePerPeriod: setupInflation)
        let money = setupSign * setupMoneyTotal + sign * recurringMoney

        // Spending a pound doesn't only cost the pound: it costs what the pound
        // would have become. Per pound, money paid up front forgoes the most,
        // because it's gone for longer — though in total whichever side spends
        // more forgoes more, which is the point.
        let opportunity = setupSign * setupMoneyTotal * (c.setupOpportunity - 1)
            + sign * recurringMoney * (c.recurringOpportunity - 1)

        // Hours don't inflate. Waiting for a timetable is real time, so it goes in
        // before the discounts — you can read on a platform.
        //
        // Setup time is corrected by how this person's estimates have actually run.
        // It's the half of a decision that is always a guess — the getting ready, the
        // going to fetch it — where the main duration is as often looked up as guessed.
        let setupMinutes = option.setupMinutes * c.calibration.estimateMultiplier
        let perOccurrenceMinutes = option.minutes + option.flexibility.slackMinutes
        let rawHours = (setupMinutes * setupOccurrences + perOccurrenceMinutes * uses) / 60
        // Time you can use isn't time lost; time that wrecks you costs more than the clock
        // says; and time spent by several people is spent several times over.
        // The discount is floored by what this person's hours have actually yielded:
        // claiming four fifths of a journey back is optimistic if two thirds of an
        // ordinary working hour never becomes work.
        let usable = max(option.usableTime.multiplier, c.calibration.usableFloor)
        let hours = rawHours
            * usable
            * option.drain.multiplier
            * option.displaces.multiplier
            * Double(max(1, c.peopleCount))
            // The flat cost of having to decide and organise, paid once per go.
            + option.drain.overheadMinutes / 60 * uses

        // Enjoyment you're not sure of is enjoyment you should count less of.
        let perOccurrenceJoy = Double(option.feel) / 3.0 * c.joyAnchor
            * option.joyConfidence.multiplier
        let joy = perOccurrenceJoy
            * pow(uses, joyDiminishingExponent)
            * scarcity
            * c.standingMultiplier

        // What it's worth to other people. Damped like enjoyment, and lifted the
        // same way by a rare occasion — a wedding is not a weekly pub night.
        let social = option.socialValue.share * c.joyAnchor
            * pow(uses, joyDiminishingExponent)
            * scarcity

        // Health compounds where pleasure fades. The fiftieth walk is as good for
        // you as the first, so this is counted straight out rather than damped.
        let health = option.health.points / 2.0 * c.healthAnchor * uses

        // Learning is front-loaded: most of it arrives in the first few goes.
        let growth = option.growth.points / 2.0
            * c.growthAnchor
            * pow(uses, growthDiminishingExponent)

        // The chance of being let down, times what one letting-down costs, times the
        // number of chances it gets. The middle figure is deliberately per-occurrence
        // — see `referenceMoney` — and that only makes sense if something then counts
        // the occurrences. Nothing did, so this was the expected cost of exactly one
        // mishap sitting in a total made of whole-horizon sums: the same £46 whether
        // the train let you down twelve times or twelve hundred.
        let risk = option.reliability.chance
            * c.stakes.cost(joyAnchor: c.joyAnchor, rate: c.rate, referenceMoney: c.referenceMoney)
            * uses

        // Benefit you'd get anyway tomorrow isn't benefit you gain by doing it tonight.
        let kept = option.deferability.share

        return OptionTotals(money: money,
                            rawHours: rawHours,
                            hours: hours,
                            opportunityCost: opportunity,
                            joy: joy * kept,
                            social: social * kept,
                            health: health * kept,
                            growth: growth * kept,
                            riskCost: risk,
                            netCost: money + opportunity + hours * c.rate
                                     - (joy + social + health + growth) * kept + risk,
                            uses: uses)
    }

    /// What a pound becomes over `years`, including any bonus for putting it somewhere
    /// restricted. The bonus lands immediately; the return compounds.
    ///
    /// When Portfolio is linked the bonus is the *marginal* one — what the next pound
    /// saved would actually attract, which is 25% while Lifetime ISA allowance remains
    /// and nothing once it is used. A standing figure flatters every decision not to
    /// spend, which is exactly what the setting warns about.
    static func opportunityFactor(profile: Profile, years: Double,
                                  money: MoneyCalibration = .none) -> Double {
        let bonus = 1 + max(0, money.savingsBonusPercent ?? profile.savingsBonusPercent) / 100
        let rate = max(0, money.savingsReturnPercent ?? profile.savingsReturnPercent) / 100
        return bonus * pow(1 + rate, max(0, years))
    }

    static func context(for decision: Decision, profile: Profile, rate: Double,
                        calibration: TimeCalibration = .none,
                        money: MoneyCalibration = .none) -> EvalContext {
        let wearsOut = !decision.setupFrequency.isRecurring
            && (decision.optionA.lifespanMonths != nil || decision.optionB.lifespanMonths != nil)
        let horizonYears = decision.frequency.isRecurring || decision.setupFrequency.isRecurring || wearsOut
            ? max(0, decision.horizonMonths) / 12
            // A one-off has no natural horizon — you'd have held the money
            // indefinitely. A year is arbitrary but modest, and keeps the effect
            // on everyday decisions down to pennies where it belongs.
            : 1
        let n = occurrences(frequency: decision.frequency, horizonMonths: decision.horizonMonths)
        let setupN = occurrences(frequency: decision.setupFrequency, horizonMonths: decision.horizonMonths)

        // What one bad outcome costs, not what a decade of them would. Using the
        // whole-horizon total made the same mishap sixty times dearer over five years.
        func perOccurrence(_ o: DecisionOption) -> Double {
            abs(o.money) + (decision.setupFrequency == .once ? abs(o.setupMoney) : 0)
        }
        let moneyA = perOccurrence(decision.optionA)
        let moneyB = perOccurrence(decision.optionB)
        // What they said it would cost, if they said. The guess below is the biggest
        // figure on the screen, which is the cover price on a warranty and therefore
        // the one number a warranty is definitely not about.
        let atRisk = decision.costIfItGoesWrong.map { abs($0) } ?? max(moneyA, moneyB)

        return EvalContext(occurrences: n,
                           setupOccurrences: setupN,
                           rate: rate,
                           joyAnchor: max(0, profile.joyAnchor),
                           healthAnchor: max(0, profile.healthAnchor),
                           growthAnchor: max(0, profile.growthAnchor),
                           standingMultiplier: profile.effectiveJoyMultiplier(hasSlack: money.hasSlack),
                           setupOpportunity: opportunityFactor(profile: profile, years: horizonYears, money: money),
                           recurringOpportunity: opportunityFactor(
                               profile: profile,
                               years: decision.frequency.isRecurring ? horizonYears / 2 : horizonYears,
                               money: money),
                           inflationPerPeriod: perPeriodRate(annualPercent: money.inflationPercent ?? profile.inflationPercent,
                                                             frequency: decision.frequency),
                           inflationPerSetupPeriod: perPeriodRate(annualPercent: money.inflationPercent ?? profile.inflationPercent,
                                                                  frequency: decision.setupFrequency),
                           horizonMonths: max(0, decision.horizonMonths),
                           inflationPercent: money.inflationPercent ?? profile.inflationPercent,
                           setupRecurs: decision.setupFrequency.isRecurring,
                           scarcity: decision.scarcity,
                           peopleCount: max(1, decision.peopleCount),
                           stakes: decision.stakes,
                           referenceMoney: atRisk,
                           calibration: calibration)
    }

    /// A month's worth of what this side goes on costing, where it goes on costing
    /// something. Nil for a one-off and nil for a side that pays you.
    ///
    /// The thirty-day ledger below is a record of what you have just taken on, which
    /// is the right shape for a purchase and the wrong one for a subscription: one
    /// month after saying yes to £9 a month the ledger forgets, and the £9 carries on
    /// leaving your account. A standing cost belongs in the standing costs.
    static func monthlyStandingCost(of side: Side, in decision: Decision) -> Double? {
        guard side != .tooClose, decision.frequency.isRecurring else { return nil }
        let option = side == .a ? decision.optionA : decision.optionB
        guard option.direction == .cost else { return nil }
        let monthly = option.moneyPerPeriod * (decision.frequency.perYear / 12)
        return monthly > 0.01 ? monthly : nil
    }

    /// What choosing this option ties up over the next month: anything one-off in
    /// full, plus a month's worth of anything recurring.
    static func monthlyCommitment(of side: Side, in decision: Decision) -> Double {
        guard side != .tooClose else { return 0 }
        let option = side == .a ? decision.optionA : decision.optionB
        let sign = option.direction.sign
        let setupSign = option.effectiveSetupDirection.sign

        let oneOff = decision.setupFrequency == .once
            ? option.setupMoney
            : option.setupMoney * (decision.setupFrequency.perYear / 12)
        let recurring = decision.frequency.isRecurring
            ? option.moneyPerPeriod * (decision.frequency.perYear / 12)
            : option.moneyPerPeriod

        return setupSign * oneOff + sign * recurring
    }

    static func evaluate(_ decision: Decision, profile: Profile) -> Evaluation {
        evaluate(decision, profile: profile, breakdown: RateEngine.breakdown(for: profile))
    }

    static func evaluate(_ decision: Decision, profile: Profile, breakdown: RateBreakdown,
                         calibration: TimeCalibration = .none,
                         money: MoneyCalibration = .none) -> Evaluation {
        let core = core(decision, profile: profile,
                        rate: breakdown.personalHourlyRate, calibration: calibration, money: money)
        return finish(core, decision: decision, profile: profile,
                      breakdown: breakdown, calibration: calibration, money: money)
    }

    // MARK: - The part that has to be cheap, because sensitivity analysis runs it many times

    struct Core: Equatable {
        let a: OptionTotals
        let b: OptionTotals
        let winner: Side
        let advantage: Double
        let occurrences: Double
        /// Set when the arithmetic couldn't separate them and a plainer fact decided it.
        let tiebreak: Tiebreak?

        /// Whether the answer came from the arithmetic rather than from a tiebreak.
        var isDecisive: Bool { tiebreak == nil }
    }

    static func core(_ decision: Decision, profile: Profile, rate: Double,
                     calibration: TimeCalibration = .none,
                     money: MoneyCalibration = .none) -> Core {
        let c = context(for: decision, profile: profile, rate: rate, calibration: calibration, money: money)

        // A rare chance belongs to the option that is the chance. Staying in is not
        // once in a lifetime just because the thing you'd be missing is, and giving
        // both sides the premium quietly cancels it out.
        let plainA = totals(for: decision.optionA, context: c, scarcity: 1)
        let plainB = totals(for: decision.optionB, context: c, scarcity: 1)

        let a: OptionTotals, b: OptionTotals
        let multiplier = c.scarcity.multiplier
        if multiplier == 1 {
            (a, b) = (plainA, plainB)
        } else if plainA.joy + plainA.social >= plainB.joy + plainB.social {
            a = totals(for: decision.optionA, context: c, scarcity: multiplier)
            b = plainB
        } else {
            a = plainA
            b = totals(for: decision.optionB, context: c, scarcity: multiplier)
        }

        let gap = b.netCost - a.netCost          // positive means A is better
        let scale = max(abs(a.netCost), abs(b.netCost), abs(a.money - b.money), 10)
        let deadZone = max(1.5, 0.6 * sqrt(scale))

        guard abs(gap) < deadZone else {
            return Core(a: a, b: b, winner: gap > 0 ? .a : .b,
                        advantage: abs(gap), occurrences: c.occurrences, tiebreak: nil)
        }

        // Inside the noise. Rather than handing it back, fall back on the plainest
        // facts there are — money first, because a price is a fact where a duration
        // is an estimate, and an estimate is the thing most likely to be wrong.
        let moneyGap = a.money - b.money
        let hoursGap = a.rawHours - b.rawHours

        let winner: Side
        let tiebreak: Tiebreak
        if abs(moneyGap) >= 0.5 {
            winner = moneyGap < 0 ? .a : .b
            tiebreak = .cheaper
        } else if abs(hoursGap) >= 1.0 / 60 {
            winner = hoursGap < 0 ? .a : .b
            tiebreak = .quicker
        } else {
            winner = .tooClose
            tiebreak = .nothingInIt
        }

        return Core(a: a, b: b, winner: winner,
                    advantage: abs(gap), occurrences: c.occurrences, tiebreak: tiebreak)
    }

    private static func finish(_ core: Core, decision: Decision, profile: Profile,
                               breakdown: RateBreakdown,
                               calibration: TimeCalibration = .none,
                         money: MoneyCalibration = .none) -> Evaluation {
        let rate = breakdown.personalHourlyRate
        let a = core.a, b = core.b
        let n = core.occurrences

        let dMoney = a.money - b.money
        let dHours = a.hours - b.hours
        let dRawHours = a.rawHours - b.rawHours
        let dJoy = a.joy - b.joy
        let dSocial = a.social - b.social
        let dHealth = a.health - b.health
        let dGrowth = a.growth - b.growth
        let dOpportunity = a.opportunityCost - b.opportunityCost
        let dRisk = a.riskCost - b.riskCost

        // Tie when dMoney + dHours * r - dJoy - dHealth - dGrowth + dRisk == 0.
        var breakEven: Double? = nil
        var fasterSide: Side? = nil
        if abs(dHours) > 0.005 {
            breakEven = (dJoy + dSocial + dHealth + dGrowth - dMoney - dOpportunity - dRisk) / dHours
            fasterSide = dHours < 0 ? .a : .b
        }

        let aDominates = dMoney <= 0 && dHours <= 0 && dJoy >= 0 && dSocial >= 0
            && dHealth >= 0 && dGrowth >= 0 && dRisk <= 0
            && (dMoney < 0 || dHours < 0 || dJoy > 0 || dSocial > 0 || dHealth > 0 || dGrowth > 0 || dRisk < 0)
        let bDominates = dMoney >= 0 && dHours >= 0 && dJoy <= 0 && dSocial <= 0
            && dHealth <= 0 && dGrowth <= 0 && dRisk >= 0
            && (dMoney > 0 || dHours > 0 || dJoy < 0 || dSocial < 0 || dHealth < 0 || dGrowth < 0 || dRisk > 0)

        var pricePerHour: Double? = nil
        if abs(dHours) > 0.005 {
            let premium = dHours < 0 ? dMoney : -dMoney
            if premium > 0 { pricePerHour = premium / abs(dHours) }
        }

        var feelPoints: Double? = nil
        let anchor = max(0, profile.joyAnchor)
        if anchor > 0 {
            let joyNeeded = dMoney + dOpportunity + dHours * rate + dRisk - dSocial - dHealth - dGrowth
            let perOccurrence = joyNeeded
                / max(pow(n, joyDiminishingExponent) * decision.scarcity.multiplier, 0.0001)
            let points = perOccurrence / anchor * 3
            if abs(points) <= 12 { feelPoints = points }
        }

        var savingsDelay: Double? = nil
        if profile.monthlySavingsTarget > 0, abs(dMoney) > 0.01 {
            savingsDelay = abs(dMoney) / profile.monthlySavingsTarget * Profile.daysPerMonth
        }

        var weeklyProjection: (money: Double, hours: Double)? = nil
        if decision.frequency == .once, abs(dMoney) > 0.01 || abs(dHours) > 0.005 {
            weeklyProjection = (dMoney * 52, dHours * 52)
        }

        return Evaluation(
            rate: rate,
            occurrences: n,
            frequency: decision.frequency,
            horizonMonths: decision.horizonMonths,
            a: a, b: b,
            winner: core.winner,
            tiebreak: core.tiebreak,
            advantage: core.advantage,
            deltaMoney: dMoney,
            deltaHours: dHours,
            deltaRawHours: dRawHours,
            deltaJoy: dJoy,
            deltaSocial: dSocial,
            deltaHealth: dHealth,
            deltaGrowth: dGrowth,
            deltaOpportunity: dOpportunity,
            deltaRisk: dRisk,
            breakEvenRate: breakEven,
            fasterSide: fasterSide,
            isDominant: aDominates || bDominates,
            pricePerHourSaved: pricePerHour,
            breakEvenFeelPoints: feelPoints,
            workHoursForMoneyGap: breakdown.workHours(for: abs(dMoney)),
            savingsDelayDays: savingsDelay,
            ifWeeklyForAYear: weeklyProjection,
            sensitivities: sensitivities(for: decision, profile: profile, rate: rate,
                                         baseline: core, calibration: calibration),
            payback: payback(for: decision, profile: profile, rate: rate,
                             calibration: calibration)
        )
    }

    /// Finds when the up-front investment overtakes carrying on as you are.
    static func payback(for decision: Decision, profile: Profile, rate: Double,
                        calibration: TimeCalibration = .none,
                        money: MoneyCalibration = .none) -> Payback {
        // The investment can be money, hours, or both — automating something costs
        // a day of your time and no money at all, and that still has a payback.
        func upFrontCost(_ o: DecisionOption) -> Double {
            o.effectiveSetupDirection.sign * o.setupMoney + o.setupMinutes / 60 * rate
        }
        let costA = upFrontCost(decision.optionA)
        let costB = upFrontCost(decision.optionB)

        let invested: Side
        if costA > costB + 0.01 { invested = .a }
        else if costB > costA + 0.01 { invested = .b }
        else { return .notApplicable }

        // Something has to accrue over time for there to be a payback at all — a
        // recurring amount, or a cheaper thing that keeps having to be bought again.
        guard decision.frequency.isRecurring || decision.setupFrequency.isRecurring
                || decision.optionA.lifespanMonths != nil
                || decision.optionB.lifespanMonths != nil else {
            return .notApplicable
        }

        /// How far ahead the invested side is at a given horizon.
        func lead(at months: Double) -> Double {
            var probe = decision
            probe.horizonMonths = months
            let c = core(probe, profile: profile, rate: rate, calibration: calibration, money: money)
            return invested == .a ? c.b.netCost - c.a.netCost : c.a.netCost - c.b.netCost
        }

        // Worth it from the first month: there is nothing to pay back.
        if lead(at: 1) >= 0 { return .immediate }

        var month = 2.0
        while month <= 120 {
            if lead(at: month) >= 0 { return .months(month) }
            month += 1
        }
        while month <= 600 {
            if lead(at: month) >= 0 { return .months(month) }
            month += 6
        }
        return .never
    }

    // MARK: - Ways the answer could be wrong

    /// Rather than asking people how confident they are in their estimates — they always
    /// say "quite" — push the numbers around and report what actually breaks.
    static func sensitivities(for decision: Decision, profile: Profile, rate: Double,
                              baseline: Core,
                              calibration: TimeCalibration = .none,
                              money: MoneyCalibration = .none) -> [Sensitivity] {
        // A tie-broken answer has nothing to be fragile about: it was already a
        // coin toss, and saying so twice helps nobody.
        guard baseline.isDecisive, baseline.winner != .tooClose else { return [] }
        let baselineWinner = baseline.winner

        func flips(_ transform: (inout Decision) -> Void, rate overrideRate: Double? = nil) -> Bool {
            var copy = decision
            transform(&copy)
            let result = core(copy, profile: profile, rate: overrideRate ?? rate,
                              calibration: calibration, money: money)
            return result.winner != baselineWinner && result.isDecisive
        }

        var found: [Sensitivity] = []
        let hasTime = decision.optionA.minutes + decision.optionA.setupMinutes
            + decision.optionB.minutes + decision.optionB.setupMinutes > 0
        let hasMoney = abs(decision.optionA.money) + abs(decision.optionA.setupMoney)
            + abs(decision.optionB.money) + abs(decision.optionB.setupMoney) > 0

        if hasTime, flips({ d in
            d.optionA.minutes *= 2; d.optionA.setupMinutes *= 2
            d.optionB.minutes *= 2; d.optionB.setupMinutes *= 2
        }) {
            found.append(Sensitivity(id: "time2x",
                text: calibration.estimateMultiplier > 1
                    ? "If both take twice as long as you think, the answer flips — and that's on top of the correction already applied to your estimates."
                    : "If both take twice as long as you think, the answer flips. Time estimates are usually optimistic."))
        }

        if hasMoney, flips({ d in
            d.optionA.money *= 1.25; d.optionA.setupMoney *= 1.25
            d.optionB.money *= 1.25; d.optionB.setupMoney *= 1.25
        }) {
            found.append(Sensitivity(id: "money125",
                text: "A quarter more on the prices and the answer flips. Worth checking the real figures."))
        }

        if flips({ _ in }, rate: rate * 0.6) || flips({ _ in }, rate: rate * 1.6) {
            found.append(Sensitivity(id: "rate",
                text: "This hangs on your hourly rate being about right. Move it much either way and the answer changes."))
        }

        // Busy, or effective? If the winning side eats hours to save money, and the
        // money works out below what an hour of yours is worth, then it is winning
        // on something other than the arithmetic — and that is worth saying out loud,
        // because doing it yourself always feels productive whether or not it is.
        let winnerHours = baselineWinner == .a ? baseline.a.hours : baseline.b.hours
        let loserHours = baselineWinner == .a ? baseline.b.hours : baseline.a.hours
        let winnerMoney = baselineWinner == .a ? baseline.a.money : baseline.b.money
        let loserMoney = baselineWinner == .a ? baseline.b.money : baseline.a.money
        let extraHours = winnerHours - loserHours
        let moneySaved = loserMoney - winnerMoney
        if extraHours >= 2, moneySaved > 0 {
            let impliedRate = moneySaved / extraHours
            if impliedRate < rate * 0.9 {
                found.append(Sensitivity(id: "busy",
                    text: "On money alone you'd be working for \(Fmt.rate(impliedRate)) here, which is less than an hour of yours is worth. It's winning on other grounds — worth checking those are grounds you actually care about, and not just that doing it yourself feels productive."))
            }
        }

        if decision.frequency == .once, flips({ d in
            d.frequency = .weekly; d.horizonMonths = 12
        }) {
            found.append(Sensitivity(id: "repeat",
                text: "Fine as a one-off, but the wrong habit. Do this weekly for a year and the answer flips."))
        }

        return found
    }
}
