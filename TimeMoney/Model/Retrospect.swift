import Foundation

/// A past purchase, seen from far enough away to judge it.
///
/// £420 on a chair is a number that means nothing on the day. £420 spread across
/// eighteen months of sitting in it, set against what you had spare over the same
/// period, means something — and it's the only honest way to tell whether the
/// expensive thing was the right call or the frugal one was.
struct PurchaseInContext: Identifiable, Equatable {
    let id: UUID
    let name: String
    let amount: Double
    /// What that sum would be in today's money.
    let amountToday: Double
    let boughtOn: Date
    let daysSince: Int
    let perDay: Double
    let perWeek: Double
    /// What share of everything you had spare over the same period this took.
    let shareOfDiscretionary: Double
    let hoursOfWork: Double
    /// True where this came from Portfolio's record of what was actually charged
    /// rather than from a decision recorded here.
    var fromPortfolio: Bool = false

    /// Rough plain-English sense of scale, so the number doesn't float free.
    var comparison: String {
        if perDay < 0.15 { return "less than a coffee a month" }
        if perDay < 0.5 { return "about a coffee a fortnight" }
        if perDay < 1.5 { return "about a coffee a week" }
        if perDay < 4 { return "about a takeaway coffee a day" }
        return "about a takeaway lunch a day"
    }
}

struct SpendingInContext: Equatable {
    let purchases: [PurchaseInContext]
    let totalCommitted: Double
    let discretionaryOverPeriod: Double
    let earliest: Date?

    var share: Double {
        guard discretionaryOverPeriod > 0 else { return 0 }
        return totalCommitted / discretionaryOverPeriod
    }

    var isEmpty: Bool { purchases.isEmpty }

    static let empty = SpendingInContext(purchases: [], totalCommitted: 0,
                                         discretionaryOverPeriod: 0, earliest: nil)
}

enum Retrospect {

    /// Everything bought outright, amortised.
    ///
    /// Decisions recorded here, plus — when Portfolio is linked — the purchases that
    /// actually happened. On its own this app can only look back at the handful of
    /// choices that went through it, which is a biased sample: the ones big enough to
    /// have agonised over. The real record is a much fairer mirror.
    static func context(for decisions: [Decision], profile: Profile, breakdown: RateBreakdown,
                        money: MoneyCalibration = .none) -> SpendingInContext {
        let now = Date()
        var purchases: [PurchaseInContext] = []

        for decision in decisions where decision.isSaved {
            // What was actually done, falling back to what was advised.
            let sideValue = decision.chosenSide ?? decision.recommendedSide
            guard let raw = sideValue, let side = Side(rawValue: raw), side != .tooClose else { continue }

            let option = side == .a ? decision.optionA : decision.optionB
            // A purchase is a one-off sum paid up front. Ongoing costs are a
            // different animal and belong in the bills, not here.
            guard decision.setupFrequency == .once,
                  option.effectiveSetupDirection == .cost,
                  option.setupMoney > 0 else { continue }

            let days = max(1, Int(now.timeIntervalSince(decision.createdAt) / 86_400))
            let months = Double(days) / 30.44
            let discretionary = max(0, breakdown.discretionaryMonthly) * months

            // Restated in today's money, so a purchase from three years ago can be
            // compared with one from last month without quietly flattering the old one.
            let years = Double(days) / 365.25
            let today = option.setupMoney * pow(1 + profile.inflationPercent / 100, years)

            purchases.append(PurchaseInContext(
                id: decision.id,
                name: decision.title.isEmpty
                    ? VerdictText.name(option, fallback: decision.scenario.template.title)
                    : decision.title,
                amount: option.setupMoney,
                amountToday: today,
                boughtOn: decision.createdAt,
                daysSince: days,
                perDay: today / Double(days),
                perWeek: today / Double(days) * 7,
                shareOfDiscretionary: discretionary > 0 ? today / discretionary : 0,
                hoursOfWork: breakdown.workHours(for: today)))
        }

        // Portfolio's own record. Anything it flags as having come from a decision
        // here is skipped: it is already in the list above, and counting it twice
        // would inflate the total against the same discretionary income.
        let known = Set(purchases.map(\.id))
        for purchase in money.purchases where !purchase.fromDecision && !known.contains(purchase.id) {
            let days = max(1, Int(now.timeIntervalSince(purchase.boughtOn) / 86_400))
            let months = Double(days) / 30.44
            let discretionary = max(0, breakdown.discretionaryMonthly) * months
            let years = Double(days) / 365.25
            let today = purchase.amount * pow(1 + profile.inflationPercent / 100, years)

            purchases.append(PurchaseInContext(
                id: purchase.id,
                name: purchase.name,
                amount: purchase.amount,
                amountToday: today,
                boughtOn: purchase.boughtOn,
                daysSince: days,
                perDay: today / Double(days),
                perWeek: today / Double(days) * 7,
                shareOfDiscretionary: discretionary > 0 ? today / discretionary : 0,
                hoursOfWork: breakdown.workHours(for: today),
                fromPortfolio: true))
        }

        purchases.sort { $0.amount > $1.amount }

        let total = purchases.reduce(0) { $0 + $1.amountToday }
        let earliest = purchases.map(\.boughtOn).min()
        let monthsSpanned = earliest.map { max(0.5, now.timeIntervalSince($0) / (86_400 * 30.44)) } ?? 0
        let discretionary = max(0, breakdown.discretionaryMonthly) * monthsSpanned

        return SpendingInContext(purchases: purchases,
                                 totalCommitted: total,
                                 discretionaryOverPeriod: discretionary,
                                 earliest: earliest)
    }
}
