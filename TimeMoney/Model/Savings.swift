import Foundation

/// What you were earning and saving the last time the two were in step.
///
/// Kept so a pay rise can be measured against something. Without it the app has no
/// way of telling a raise from a number that has always been that size.
struct IncomeBaseline: Codable, Equatable {
    var netMonthly: Double
    var savingsTarget: Double
    var goalAmount: Double
    var setAt: Date = Date()

    /// Savings as a share of take-home. The thing the ratchet actually protects.
    var share: Double {
        netMonthly > 0 ? savingsTarget / netMonthly : 0
    }
}

/// Keeping savings at least in step with pay.
///
/// A raise that changes nothing about what you put aside is a raise that quietly
/// becomes spending — the share saved falls every time you earn more, which is the
/// most ordinary way people end up no better off on twice the money.
///
/// The rule is a floor, not a target: when take-home goes up, savings should go up
/// by at least the same proportion. Since rent and bills haven't moved, rather more
/// than that is usually affordable, and the app says so without insisting.
enum SavingsRatchet {

    /// Changes smaller than this are rounding, a one-off bonus, or a tax-code
    /// correction — not a raise, and not worth a card on the home screen.
    static let minimumIncrease: Double = 10
    static let minimumRelativeIncrease: Double = 0.01

    struct Raise: Equatable {
        let previousIncome: Double
        let currentIncome: Double
        let previousSavings: Double
        /// What the same share of take-home comes to now. The floor.
        let proportionalSavings: Double
        /// Half the increase on top of what you already save. Affordable in a way
        /// the proportional figure isn't required to be, because none of your
        /// committed outgoings went up with the raise.
        let halfTheRiseSavings: Double
        let previousGoal: Double
        let proportionalGoal: Double
        /// When the baseline was set — the date the line is measured from.
        let since: Date
        /// The London Living Wage, when Portfolio is publishing it.
        let livingWage: LivingWageLine?

        var incomeIncrease: Double { currentIncome - previousIncome }
        var savingsIncrease: Double { proportionalSavings - previousSavings }
        var share: Double { currentIncome > 0 ? previousSavings / previousIncome : 0 }
        var hasGoal: Bool { previousGoal > 0 }

        // MARK: The rise, against the line

        /// How much of the rise is genuinely new money rather than the world getting
        /// more expensive. Nil when there is no line to measure against.
        var newMoneyMonthly: Double? {
            LivingWageLine.newMoney(from: previousIncome, to: currentIncome, since: since)
        }

        /// False when the rise did not keep up with the cost of living — a rise on
        /// the payslip and a cut in real terms.
        var keptUpWithTheLine: Bool { (newMoneyMonthly ?? 0) >= 0 }

        /// The most that could be saved while what is left still clears the line.
        ///
        /// Kept out of the income rather than out of Portfolio's headroom on purpose:
        /// headroom is measured against *Portfolio's* savings target, and this app is
        /// about to set a different one. Income less the line is the same answer
        /// without needing the two targets to agree first.
        var ceiling: Double? {
            livingWage.map { max(0, currentIncome - $0.monthlyNet) }
        }

        /// The third suggestion, and the one that survives an inflationary year.
        ///
        /// The proportional figure has a flaw that only shows up when the cost of
        /// living is moving: if pay rose 7% and the line rose 7%, keeping the same
        /// *share* saved means saving 7% more out of money that buys 7% less — so the
        /// standard of living falls to hold a share constant. This indexes the old
        /// target to the line instead, which keeps the saving worth what it was, and
        /// then adds half of whatever was genuinely new on top.
        ///
        /// When the line has not moved it comes out at exactly `halfTheRiseSavings`,
        /// which is the right thing for it to degrade to.
        var indexedSavings: Double {
            let held = LivingWageLine.indexed(previousSavings, since: since)
            let suggested = held + max(0, newMoneyMonthly ?? incomeIncrease) / 2
            guard let ceiling else { return suggested }
            return min(suggested, ceiling)
        }

        /// True when the line, rather than the arithmetic, decided the figure above.
        var indexedIsCapped: Bool {
            guard let ceiling else { return false }
            let held = LivingWageLine.indexed(previousSavings, since: since)
            return held + max(0, newMoneyMonthly ?? incomeIncrease) / 2 > ceiling + 0.5
        }
    }

    /// A raise that hasn't been answered yet, or nil.
    ///
    /// Pure: it never writes anything, so it can be read from a view body as often
    /// as the view redraws.
    static func pending(for profile: Profile, netMonthly: Double,
                        money: MoneyCalibration = .none) -> Raise? {
        guard let base = baseline(for: profile, money: money), base.netMonthly > 0, netMonthly > 0 else { return nil }
        guard netMonthly > base.netMonthly + minimumIncrease,
              netMonthly > base.netMonthly * (1 + minimumRelativeIncrease) else { return nil }
        // Asked once per raise. Saying no to one shouldn't mean being asked again
        // every time the app opens.
        if let declined = profile.savingsRaiseDeclinedAtIncome,
           netMonthly <= declined + minimumIncrease { return nil }

        let proportional = base.savingsTarget * netMonthly / base.netMonthly
        guard profile.monthlySavingsTarget < proportional - 0.5 else { return nil }

        let rise = netMonthly - base.netMonthly
        return Raise(previousIncome: base.netMonthly,
                     currentIncome: netMonthly,
                     previousSavings: base.savingsTarget,
                     proportionalSavings: proportional,
                     halfTheRiseSavings: base.savingsTarget + rise / 2,
                     previousGoal: base.goalAmount,
                     proportionalGoal: base.goalAmount * netMonthly / base.netMonthly,
                     since: base.setAt,
                     livingWage: money.livingWage)
    }

    /// The reference point to measure a raise against.
    ///
    /// Portfolio's, where it has one, because it is a record of a change that
    /// actually happened on a date rather than an inference from a stored number
    /// having moved. Its share is taken from what this app was saving at the time,
    /// which is the only part Portfolio does not know.
    ///
    /// Falls back to the local baseline the moment the link is off or the file is
    /// silent, so nothing here depends on the other app being installed.
    static func baseline(for profile: Profile, money: MoneyCalibration) -> IncomeBaseline? {
        guard let previous = money.previousNetMonthlyIncome, previous > 0,
              let changedAt = money.incomeChangedAt else { return profile.incomeBaseline }

        // A local baseline set after the change already knows about it; using the
        // older external one would re-ask a question that has been answered.
        if let local = profile.incomeBaseline, local.setAt > changedAt { return local }

        return IncomeBaseline(
            netMonthly: previous,
            savingsTarget: profile.incomeBaseline?.savingsTarget ?? profile.monthlySavingsTarget,
            goalAmount: profile.incomeBaseline?.goalAmount ?? profile.savingsGoalAmount,
            setAt: changedAt
        )
    }

    /// Raises the target and re-anchors, so the next raise is measured from here
    /// rather than stacking a second demand on top of the first.
    static func apply(_ amount: Double, raise: Raise, to profile: inout Profile,
                      includingGoal: Bool) {
        profile.monthlySavingsTarget = max(0, amount.rounded())
        if includingGoal, raise.hasGoal {
            profile.savingsGoalAmount = max(0, raise.proportionalGoal.rounded())
        }
        profile.savingsRaiseDeclinedAtIncome = nil
        rebaseline(&profile, netMonthly: raise.currentIncome)
    }

    /// Leaves everything alone and stops asking about this raise.
    ///
    /// Deliberately does not move the baseline: the share you were saving is still
    /// the share you were saving, so the next raise is measured from the last point
    /// you were actually in step rather than from the point you let it slip.
    static func decline(_ raise: Raise, in profile: inout Profile) {
        profile.savingsRaiseDeclinedAtIncome = raise.currentIncome
    }

    /// Sets or moves the reference point. Called when the app opens rather than from
    /// a property observer, so nothing here can recurse through a save.
    ///
    /// A pay cut deliberately moves nothing. It's tempting to re-anchor on the way
    /// down too, but that punishes exactly the right behaviour: absorb a cut without
    /// touching your savings and your share goes up, and re-anchoring would then
    /// hold you to that raised share for ever, demanding more on the way back to a
    /// salary you already had. Leaving the baseline alone means recovering to your
    /// old pay asks nothing, and only pay above it asks for more.
    static func settle(_ profile: inout Profile, netMonthly: Double) {
        guard netMonthly > 0 else { return }
        guard let base = profile.incomeBaseline, base.netMonthly > 0 else {
            rebaseline(&profile, netMonthly: netMonthly)
            return
        }
        guard netMonthly >= base.netMonthly else { return }

        // Already keeping pace — either because the raise was accepted or because the
        // figure was raised by hand. Either way this is the honest new reference.
        let proportional = base.savingsTarget * netMonthly / base.netMonthly
        if profile.monthlySavingsTarget >= proportional - 0.5 {
            rebaseline(&profile, netMonthly: netMonthly)
        }
    }

    private static func rebaseline(_ profile: inout Profile, netMonthly: Double) {
        profile.incomeBaseline = IncomeBaseline(
            netMonthly: netMonthly,
            savingsTarget: max(0, profile.monthlySavingsTarget),
            goalAmount: max(0, profile.savingsGoalAmount))
    }
}
