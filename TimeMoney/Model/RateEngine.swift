import Foundation

/// The derivation of a single number: what an hour of your life is worth in pounds.
///
/// Every intermediate value is kept so the app can show its working. A number the
/// user doesn't believe is a number they won't act on.
struct RateBreakdown: Equatable {

    // Income
    let netMonthlyIncome: Double

    // Hours given to work
    let paidHoursWeekly: Double
    let commuteHoursWeekly: Double
    let paidHoursMonthly: Double
    let totalWorkHoursMonthly: Double

    /// Take-home divided by paid hours. What your employer nominally pays per hour.
    let earnedRate: Double

    /// Take-home divided by every hour work actually takes, commute included.
    /// This is the honest one — a commuting hour is an hour of your life gone.
    let effectiveEarnedRate: Double

    /// The hours actually pricing an hour of life: the measured conventional week
    /// where there is one worth believing, the typed figure where there isn't, and
    /// a weighted mix of the two in between.
    let workHoursWeekly: Double

    /// The working week as Attention measured it, converted from strictly timed deep
    /// work into conventional hours, and the recorded weeks behind it. Nil when the
    /// link is off or the conversion was refused.
    let measuredWorkHoursWeekly: Double?
    let measuredWorkWeeks: Int
    /// How much of that measurement is in `workHoursWeekly`, from 0 to 1. Below one
    /// the days behind the multiplier scattered enough to be worth discounting for;
    /// at zero they scattered past the point Attention itself will quote a week.
    let measuredWorkConfidence: Double
    /// Why there is no measured figure at all, where there is a file but no conversion.
    let workHoursRefusal: ConventionalWeek.Refusal?

    /// What to say about where the working week came from, or nil when it came
    /// wholly from the diary and needs no explaining.
    ///
    /// Prose in a value type, as `Refusal.note` already is, and for the same reason:
    /// two screens ask this question and a rate whose provenance is phrased
    /// differently in each is a rate that looks like two different numbers.
    var workHoursNote: String? {
        guard let measured = measuredWorkHoursWeekly else { return workHoursRefusal?.note }
        guard measuredWorkConfidence < 1 else { return nil }
        let diary = String(format: "%.0f", measured)
        let used = String(format: "%.0f", workHoursWeekly)
        if measuredWorkConfidence <= 0 {
            return "Your days have been varying too much for one multiplier to describe them — some ran several times longer around the same deep work than others. Your diary would make this \(diary) hours a week, but it isn't deciding your rate; the figure you typed is."
        }
        let share = Int((measuredWorkConfidence * 100).rounded())
        return "Your diary makes this \(diary) hours a week, but your days have been varying enough lately to take it only \(share)% of the way. Your rate is being priced against \(used) hours."
    }

    // Money that's genuinely in play
    let committedMonthly: Double
    /// Money already spoken for by decisions you've made in the last month.
    let recentlyCommitted: Double
    let discretionaryMonthly: Double

    // Hours that are genuinely yours
    let freeHoursWeekly: Double
    let freeHoursMonthly: Double

    /// Free evening hours a week as Attention measured them, against what was
    /// actually booked, and how many days of diary that rests on. Nil when the
    /// link is off or the file has nothing to say.
    let measuredFreeHoursWeekly: Double?
    let measuredDays: Int
    /// Timed work that escaped into evenings and weekends. Counted as work, and
    /// taken back out of free time, because it is both.
    let overspillHoursWeekly: Double
    /// Whether the week's load was read from the diary rather than set by hand.
    let loadIsMeasured: Bool

    /// Discretionary money spread over free hours. The substitution rate: buying back
    /// an hour costs money you would otherwise have spent enjoying an hour.
    let leisureRate: Double

    /// Leisure rate anchored partly to the earned rate, because most people's intuition
    /// about an hour sits between "what work pays" and "what my spare money buys".
    let leisureBlend: Double

    let marginalRate: Double
    let earningFlexibility: EarningFlexibility

    /// The rate before the time-rich / time-poor adjustment.
    let baseRate: Double

    let stance: Stance
    let stanceMultiplier: Double

    /// How this particular week is going, and what that does to the rate.
    let load: LoadLevel
    let loadMultiplier: Double

    /// How badly you're on course to miss something you're saving for, 0 to 1.
    let goalPressure: Double
    /// The commitment you're furthest from meeting, if any.
    let tightestCommitment: Commitment?
    let tightestShortfall: Double
    /// What that pressure does to your rate. Being short of money makes an hour cheaper.
    let pressureMultiplier: Double

    /// The answer.
    let personalHourlyRate: Double

    let isOverridden: Bool

    /// The London Living Wage, when Portfolio is publishing it. An outside opinion
    /// about what an hour has to be worth, against a rate built entirely out of your
    /// own figures and your own mood about them.
    let livingWage: LivingWageLine?

    /// How the rate reads against that line. Nil when there is no line to read it
    /// against.
    ///
    /// Deliberately a reading rather than a floor. A rate below the line is allowed
    /// and is sometimes correct — somebody time-rich and cash-poor really does value
    /// an hour cheaply — but it is far more often the load and pressure multipliers
    /// having squeezed it, and that is worth seeing rather than clamping away.
    var livingWageStanding: LivingWageLine.HourStanding? {
        livingWage.map { $0.standing(ofHourlyRate: personalHourlyRate) }
    }

    /// How many hours of work a pound costs you, at the effective earned rate.
    func workHours(for money: Double) -> Double {
        guard effectiveEarnedRate > 0 else { return 0 }
        return money / effectiveEarnedRate
    }
}

enum RateEngine {

    /// Weight given to the earned rate when blending it with the leisure rate.
    /// Purely a judgement call, and the one dial most worth arguing about.
    static let earnedRateWeight: Double = 0.35

    static func netMonthlyIncome(for profile: Profile, money: MoneyCalibration = .none) -> Double {
        // Portfolio knows what actually lands, so it does not have to be estimated
        // from gross. The typed figure and the tax estimator both remain as fallbacks.
        if let measured = money.netMonthlyIncome, measured > 0 { return measured }
        switch profile.incomeMode {
        case .netMonthly:
            return max(0, profile.netMonthlyIncome)
        case .grossAnnual:
            return max(0, UKTax.takeHome(for: profile).netMonthly)
        }
    }

    static func breakdown(for profile: Profile) -> RateBreakdown {
        breakdown(for: profile, recentlyCommitted: 0)
    }

    /// `recentlyCommitted` is what recent decisions have already tied up. Spending it
    /// makes the rest of the month tighter, which is exactly what should happen: a
    /// decision has consequences for the decisions after it.
    static func breakdown(for profile: Profile, recentlyCommitted: Double) -> RateBreakdown {
        breakdown(for: profile, recentlyCommitted: recentlyCommitted, attention: nil)
    }

    /// `attention` is a summary of the user's own recorded days. It is used only when
    /// they've switched the link on, and every figure in it is taken individually —
    /// a file that knows the sleep times but has no usable diary still contributes
    /// the sleep times.
    static func breakdown(for profile: Profile,
                          recentlyCommitted: Double,
                          attention: AttentionSummary?,
                          money: MoneyCalibration = .none) -> RateBreakdown {
        let weeks = Profile.weeksPerMonth
        let net = netMonthlyIncome(for: profile, money: money)
        let measured = profile.attentionLinkEnabled ? attention : nil

        let paidWeekly = max(0, profile.paidHoursPerWeek)
        let commuteWeekly = max(0, profile.commuteHoursPerWeek)
        // Work that landed in an evening or at a weekend. Not paid — so it doesn't
        // touch the nominal rate — but real, so it belongs in every hour work costs.
        let overspillWeekly = max(0, measured?.overspillHoursPerWeek ?? 0)
        let paidMonthly = paidWeekly * weeks

        // What work actually takes, in the units people speak in.
        //
        // A contract is a fiction for anyone who doesn't clock in, and this is the
        // figure both honest questions want: what an hour given to work yields, and
        // what a pound costs in hours of it. Measured where it can be, and where it
        // can't the reason is carried rather than the shortfall being hidden.
        //
        // Overspill is deliberately *not* added on top. Evening and weekend work is
        // already inside the timed minutes this is built from, so adding it again
        // would count those hours nearly twice — once converted and once raw. It
        // keeps its other job untouched: coming back off free time below, where it
        // is answering a different question entirely, about the evening it ate.
        // Blended rather than switched, because the quantity behind the choice is
        // continuous: nothing happens to a diary at a spread of 0.35 that does not
        // nearly happen at 0.34, and a cliff there would let two exports a day
        // apart move the price of an hour with nothing in the diary to explain it.
        // The typed figure is what it degrades *towards*, so the contract stays the
        // answer of last resort rather than being discarded and then missed.
        let measuredWorkWeekly = measured?.conventionalWorkHoursPerWeek
        let measuredConfidence = measuredWorkWeekly == nil ? 0 : (measured?.conventionalConfidence ?? 0)
        let typedWorkWeekly = paidWeekly + overspillWeekly
        let workWeekly = measuredWorkWeekly.map {
            measuredConfidence * $0 + (1 - measuredConfidence) * typedWorkWeekly
        } ?? typedWorkWeekly
        let totalWorkMonthly = (workWeekly + commuteWeekly) * weeks

        // Nominal stays nominal. This is what an employer pays for a contracted hour
        // and nothing measured should move it — the measurement belongs to the
        // effective rate, which is about the life given rather than the wage agreed.
        let earned = paidMonthly > 0 ? net / paidMonthly : 0
        let effectiveEarned = totalWorkMonthly > 0 ? net / totalWorkMonthly : 0

        // Committed outgoings and the savings target come from Portfolio when the
        // link is on, because it has the actual direct debits and the actual
        // allocation rather than a figure typed once and left. With the link off both
        // lines are exactly what they have always been.
        let typedCommitted = max(0, profile.monthlyRent)
            + max(0, profile.monthlyBills)
            + max(0, profile.monthlySavingsTarget)
        let savingsTarget = money.monthlySavingsTarget ?? max(0, profile.monthlySavingsTarget)
        let committed = money.committedOutgoings.map { $0 + savingsTarget } ?? typedCommitted

        // What Portfolio calls safe to spend is already net of bills and the goal, but
        // it cannot know about decisions made since it was written — so those still
        // come off here.
        let discretionary = (money.discretionary ?? (net - committed)) - max(0, recentlyCommitted)

        // 168 hours in a week, minus sleep, minus work, minus the unavoidable admin
        // of being a person. What's left is the time you actually get to spend.
        let sleepHours = measured?.sleepHoursPerNight ?? profile.sleepHoursPerNight
        let sleepWeekly = max(0, min(sleepHours, 16)) * 7
        let adminWeekly = max(0, profile.lifeAdminHoursPerWeek)

        // The measured version counts the evenings that were actually free rather than
        // the ones a subtraction says should have been. Admin still comes off it: the
        // diary knows what was booked, not that the washing needs doing. Evening work
        // comes off too — Attention counts an evening as free if nothing was *booked*
        // in it, and working through it doesn't book it.
        let measuredFreeWeekly = measured?.freeLifeHoursPerWeek
        let freeWeekly: Double
        if let measuredFreeWeekly {
            freeWeekly = max(0, measuredFreeWeekly - adminWeekly - overspillWeekly)
        } else {
            // `workWeekly` rather than the paid figure, and no separate overspill term:
            // whichever branch it came from, it already carries the evening work — the
            // measured conversion because it is built from those very minutes, the
            // fallback because overspill is added into it above.
            freeWeekly = max(0, 168 - sleepWeekly - workWeekly - commuteWeekly - adminWeekly)
        }
        let freeMonthly = freeWeekly * weeks

        // A negative discretionary balance means every spare pound is spoken for,
        // which pushes the value of an hour down, not up.
        let leisure = (discretionary > 0 && freeMonthly > 0) ? discretionary / freeMonthly : 0
        let blend = earnedRateWeight * effectiveEarned + (1 - earnedRateWeight) * leisure

        let marginal = max(0, profile.marginalHourlyRate)
        let base: Double
        switch profile.earningFlexibility {
        case .fixed:
            base = blend
        case .occasional:
            base = 0.4 * marginal + 0.6 * blend
        case .flexible:
            base = 0.7 * marginal + 0.3 * blend
        }

        let multiplier = profile.stance.multiplier

        // The acute kind of time pressure, as opposed to the chronic kind already
        // baked into the free-hours figure.
        //
        // Read from the week ahead where the diary reaches that far, which is better
        // than a setting in every way: it can't be forgotten, it can't go stale, and
        // it doesn't need the seven-day expiry that exists only because a pressure
        // flag you have to remember to turn off is worse than none at all.
        let measuredLoad = measured.flatMap { $0.forwardIsFresh ? $0.weekAhead : nil }
        let load = measuredLoad ?? profile.effectiveLoad
        let loadMultiplier = load.multiplier

        // Something specific coming up that you're short for makes money genuinely
        // scarce — not just subjectively. An hour is worth less when it's standing
        // between you and a thing you've already decided you want.
        var pressure: Double = 0
        var tightest: Commitment? = nil
        var tightestShort: Double = 0
        // Portfolio's sinking funds alongside anything typed here. Merged by id
        // rather than replacing, so a commitment that only ever existed in this app
        // survives the link being switched on.
        let allCommitments = money.mergedCommitments(with: profile.commitments)
        for commitment in allCommitments where commitment.isActive {
            let short = commitment.shortfall(discretionaryMonthly: discretionary)
            guard short > 0 else { continue }
            let severity = min(1, short / commitment.amount)
            // Damp anything more than six months out: a wedding in three years
            // shouldn't make you take the bus today.
            let urgency = min(1, 6 / max(1, commitment.monthsAway))
            let score = min(1, severity * urgency)
            if score > pressure {
                pressure = score
                tightest = commitment
                tightestShort = short
            }
        }
        let pressureMultiplier = 1 - 0.4 * pressure

        // The £1 is a guard against nonsense — a zero rate divides into every "how
        // many hours is this" figure in the app — and not a claim that an hour is
        // worth at least a pound. What the rate is worth *against* anything is the
        // living-wage reading below, which says so instead of quietly propping it up.
        let derived = max(1.0, base * multiplier * loadMultiplier * pressureMultiplier)
        let final = profile.rateOverride.map { max(0.5, $0) } ?? derived

        return RateBreakdown(
            netMonthlyIncome: net,
            paidHoursWeekly: paidWeekly,
            commuteHoursWeekly: commuteWeekly,
            paidHoursMonthly: paidMonthly,
            totalWorkHoursMonthly: totalWorkMonthly,
            earnedRate: earned,
            effectiveEarnedRate: effectiveEarned,
            workHoursWeekly: workWeekly,
            measuredWorkHoursWeekly: measuredWorkWeekly,
            measuredWorkWeeks: measured?.conventionalWeeks ?? 0,
            measuredWorkConfidence: measuredConfidence,
            workHoursRefusal: measured?.conventionalRefusal,
            committedMonthly: committed,
            recentlyCommitted: max(0, recentlyCommitted),
            discretionaryMonthly: discretionary,
            freeHoursWeekly: freeWeekly,
            freeHoursMonthly: freeMonthly,
            measuredFreeHoursWeekly: measuredFreeWeekly,
            measuredDays: measured?.knownDays ?? 0,
            overspillHoursWeekly: overspillWeekly,
            loadIsMeasured: measuredLoad != nil,
            leisureRate: leisure,
            leisureBlend: blend,
            marginalRate: marginal,
            earningFlexibility: profile.earningFlexibility,
            baseRate: base,
            stance: profile.stance,
            stanceMultiplier: multiplier,
            load: load,
            loadMultiplier: loadMultiplier,
            goalPressure: pressure,
            tightestCommitment: tightest,
            tightestShortfall: tightestShort,
            pressureMultiplier: pressureMultiplier,
            personalHourlyRate: final,
            isOverridden: profile.rateOverride != nil,
            livingWage: money.livingWage
        )
    }
}
