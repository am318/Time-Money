import Foundation

/// The London real Living Wage as a floor under decisions.
///
/// Every other test in this app is relative to you. The rate is your rate, the
/// discretionary money is your discretionary money, and the stance multiplier moves
/// both of them according to how you have said you feel about money this month. That
/// is the right way round for pricing an hour and the wrong way round for asking
/// whether something is affordable, because a squeezed plan and a demanding stance
/// make everything look expensive, and a comfortable one makes everything look cheap.
///
/// This does not move. It is what an independent body calculates a London life costs,
/// and it is the same number whatever mood the app is in.
///
/// The figures come from Portfolio, which has the actual bills and the actual saving
/// and does the tax arithmetic once. Deriving them here would mean a second set of
/// thresholds that could quietly disagree with the first.
struct LivingWageLine: Equatable {
    /// What a London life is calculated to cost each month, after tax.
    let monthlyNet: Double
    /// What is left above that line once the plan has taken its saving. Negative
    /// means the plan is already past it.
    let headroom: Double

    /// The published hourly rate, from the table both apps carry.
    var hourly: Double { LivingWage.current().hourly }
    var rate: LivingWageRate { LivingWage.current() }

    var isAlreadyBelow: Bool { headroom < 0 }

    // MARK: What a commitment does to it

    /// A decision weighed against the line rather than against your feelings about
    /// money this month.
    struct Crossing: Equatable {
        let monthlyCost: Double
        let headroomBefore: Double
        var headroomAfter: Double { headroomBefore - monthlyCost }

        /// True when this commitment is what takes you under.
        var crosses: Bool { headroomBefore >= 0 && headroomAfter < 0 }
        /// True when you were already under before it.
        var deepens: Bool { headroomBefore < 0 && monthlyCost > 0 }
        /// The most that would fit while staying on the line.
        var mostThatFits: Double { max(0, headroomBefore) }

        var isFinding: Bool { crosses || deepens }

        /// What to say about it.
        ///
        /// Never "you cannot afford this", which would be false — the money exists,
        /// and saying otherwise about somebody's own money is both wrong and easy to
        /// dismiss. The true version is more useful anyway: affording it means living
        /// below what a London life is calculated to take, and that is a thing to
        /// decide rather than a thing to be told.
        var note: String? {
            guard isFinding else { return nil }
            if deepens {
                return "What is left to live on is already \(Fmt.money(-headroomBefore)) a month under the "
                    + "London Living Wage. This would take it \(Fmt.money(monthlyCost)) further under."
            }
            return "This fits the money. It also takes what is left to live on "
                + "\(Fmt.money(-headroomAfter)) a month below the London Living Wage — what an independent "
                + "calculation says a London life costs. \(Fmt.money(mostThatFits)) a month is the most that stays above it."
        }
    }

    func crossing(monthlyCost: Double) -> Crossing {
        Crossing(monthlyCost: max(0, monthlyCost), headroomBefore: headroom)
    }

    /// A decision's cost as a monthly figure.
    ///
    /// A one-off is deliberately *not* spread. The line is about what a month has to
    /// cover, and a one-off month is a month you chose — the thing that quietly
    /// changes a standard of living is the commitment that turns up every month
    /// without being decided again. Amortising a sofa across five years would let
    /// every sofa pass a test that exists to catch subscriptions.
    static func monthlyEquivalent(of amount: Double, frequency: Frequency) -> Double? {
        guard frequency.isRecurring, amount > 0 else { return nil }
        return amount * frequency.perYear / 12
    }

    // MARK: What it says about an hour

    /// How a derived personal rate compares with the line.
    ///
    /// Not a floor on the rate: an hour genuinely can be worth less than this to
    /// somebody time-rich and cash-poor, and clamping it would hide the very thing
    /// worth seeing. It is a reading — and a rate below the line usually means the
    /// pressure and load multipliers have been squeezing, rather than that an hour of
    /// somebody's life is cheap.
    struct HourStanding: Equatable {
        let personalRate: Double
        let lineRate: Double

        var isBelow: Bool { personalRate < lineRate }
        var multiple: Double { lineRate > 0 ? personalRate / lineRate : 0 }

        var note: String? {
            guard lineRate > 0 else { return nil }
            if isBelow {
                return "An hour of yours is pricing at \(Fmt.money(personalRate)) — under the "
                    + "\(Fmt.money(lineRate)) an hour a London life is calculated to need. That usually means the "
                    + "plan is squeezed rather than that your time is cheap."
            }
            return "An hour of yours prices at \(String(format: "%.1f", multiple))× the "
                + "\(Fmt.money(lineRate)) an hour a London life is calculated to need."
        }
    }

    func standing(ofHourlyRate rate: Double) -> HourStanding {
        HourStanding(personalRate: rate, lineRate: hourly)
    }

    // MARK: Indexing pay

    /// What a rise is worth once the line is taken off it.
    ///
    /// Standing still costs money: holding the same standard of living through a 6.9%
    /// rise in the line takes 6.9% more take-home. A ratchet that treats the whole of
    /// a rise as spare is one that raises saving on money the world had already spent.
    static func newMoney(from previousNet: Double, to currentNet: Double, since: Date) -> Double? {
        guard previousNet > 0, LivingWage.covers(since) else { return nil }
        let before = LivingWage.london(on: since)
        let now = LivingWage.current()
        guard before.announcedIn != now.announcedIn else { return currentNet - previousNet }
        return currentNet - previousNet * (1 + LivingWage.change(from: before, to: now))
    }

    /// What the same saving has to become to stay worth what it was, once the line
    /// has moved under it.
    static func indexed(_ amount: Double, since: Date) -> Double {
        guard amount > 0, LivingWage.covers(since) else { return amount }
        let before = LivingWage.london(on: since)
        return amount * (1 + LivingWage.change(from: before, to: LivingWage.current()))
    }
}
