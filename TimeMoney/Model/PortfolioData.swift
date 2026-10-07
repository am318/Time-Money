import Foundation

// `PortfolioSnapshot` lives in PortfolioSnapshot.swift, copied verbatim from the
// Portfolio app. It is the shared interface between the two and should be replaced
// wholesale rather than edited here.

/// Corrections to apply to the money side of a decision, from Portfolio's own figures.
///
/// The exact shape of `TimeCalibration`, and for the same reason: the profile the
/// user typed is never overwritten. Everything here is derived at read time, so
/// turning the link off puts the app back precisely where it was.
struct MoneyCalibration: Equatable {
    static let none = MoneyCalibration()

    /// Committed monthly outgoings — bills plus sinking-fund accruals.
    var committedOutgoings: Double?
    var monthlyRent: Double?
    var monthlySavingsTarget: Double?
    /// What Portfolio says is genuinely safe to spend, before recent decisions.
    var discretionary: Double?
    /// A level of spending the budget protects whatever the goal would take, measured
    /// from months actually lived on.
    ///
    /// The difference between "you have £300 spare" and "£150 of that is your floor
    /// and the rest is genuinely free" is the difference between two pieces of advice,
    /// and only the second is true.
    var discretionaryFloor: Double?
    /// How much of `discretionary` is that floor rather than money the plan can spare.
    var heldBackByFloor: Double?

    /// What a London life is calculated to cost each month, after tax, and the room
    /// left above it once the plan has taken its saving.
    ///
    /// The third floor, and the only one that is not about this particular person.
    /// `discretionaryFloor` is evidence — you have lived on it. This is arithmetic
    /// somebody else did about what living takes, which is why a decision can be
    /// weighed against it without the answer depending on how frugal the last year
    /// happened to be. Negative headroom means Portfolio's plan is already saving
    /// past the line.
    var livingWageFloorMonthly: Double?
    var headroomAboveLivingWage: Double?

    /// The line in the shape this app reasons with, or nil when Portfolio has it
    /// switched off.
    var livingWage: LivingWageLine? {
        guard let livingWageFloorMonthly, livingWageFloorMonthly > 0 else { return nil }
        return LivingWageLine(monthlyNet: livingWageFloorMonthly,
                              headroom: headroomAboveLivingWage ?? 0)
    }

    /// The bonus on the *next* pound saved, which is not the same as the bonus on
    /// pounds already saved. Zero once this year's Lifetime ISA allowance is used.
    var savingsBonusPercent: Double?
    var bonusReason: String?
    var savingsReturnPercent: Double?

    /// Whether there is genuinely spare money. Only the financial half of standing —
    /// whether you *feel* ahead takes in work and everything else, and stays yours.
    var hasSlack: Bool?

    /// Sinking funds, to be merged with commitments rather than replacing them.
    var commitments: [Commitment] = []

    // Income. Portfolio keeps the actual pay and the actual pension percentage, so
    // maintaining them in two places is how they end up disagreeing.
    var netMonthlyIncome: Double?
    var grossAnnualSalary: Double?
    var pensionPercent: Double?
    var studentLoanPlan: StudentLoanPlan?
    var inflationPercent: Double?

    /// The last recorded change in take-home, and what it was called.
    ///
    /// The ratchet's whole difficulty is telling a raise from a number that has
    /// always been that size. Its own baseline can only notice that a stored figure
    /// moved, which also happens when a typo is corrected. Portfolio keeps the dated
    /// record of what actually changed, so when it is linked this is the better
    /// answer to the same question.
    var previousNetMonthlyIncome: Double?
    var incomeChangedAt: Date?
    var incomeChangeName: String?

    /// Purchases that actually happened, for putting past spending in context.
    var purchases: [PortfolioPurchase] = []

    /// What became of the decisions sent over, so the estimates behind them can be
    /// checked against what was really charged.
    var settled: [PortfolioSettlement] = []

    var exportedAt: Date?
    var goalName: String?
    var goalTargetYear: Int?
    /// What the goal actually needs, in today's money. A target rather than a
    /// forecast, which is why it is safe to lean on.
    var savingsGoalAmount: Double?
    var isOnTrack: Bool?

    var isUsable: Bool { exportedAt != nil }

    /// How stale the figures are, for a screen that shows its working.
    var ageInDays: Int? {
        guard let exportedAt else { return nil }
        return max(0, Int((Date().timeIntervalSince(exportedAt) / 86_400).rounded()))
    }

    var ageDescription: String? {
        guard let days = ageInDays else { return nil }
        if days <= 0 { return "today" }
        return days == 1 ? "yesterday" : "\(days) days ago"
    }

    init() {}

    init(snapshot: PortfolioSnapshot?) {
        guard let snapshot else { return }
        exportedAt = snapshot.exportedAt
        committedOutgoings = snapshot.monthlyEssentialBills + snapshot.monthlySinkingAccruals
        monthlyRent = snapshot.monthlyRent
        monthlySavingsTarget = snapshot.monthlySavingsTarget
        discretionary = snapshot.monthlyDiscretionary
        discretionaryFloor = snapshot.monthlyDiscretionaryFloor > 0 ? snapshot.monthlyDiscretionaryFloor : nil
        heldBackByFloor = snapshot.discretionaryHeldBackByFloor > 0 ? snapshot.discretionaryHeldBackByFloor : nil
        livingWageFloorMonthly = snapshot.livingWageFloorMonthly > 0 ? snapshot.livingWageFloorMonthly : nil
        // Taken as it comes, zero included: no headroom at all is a real answer, and
        // the nil-when-zero trick used above would turn "exactly on the line" into
        // "not measured".
        headroomAboveLivingWage = snapshot.livingWageFloorMonthly > 0 ? snapshot.headroomAboveLivingWage : nil
        savingsBonusPercent = snapshot.marginalSavingsBonusPercent
        bonusReason = snapshot.marginalBonusReason.isEmpty ? nil : snapshot.marginalBonusReason
        savingsReturnPercent = snapshot.realReturnPercent
        hasSlack = snapshot.hasSlack
        netMonthlyIncome = snapshot.netMonthlyIncome > 0 ? snapshot.netMonthlyIncome : nil
        grossAnnualSalary = snapshot.grossAnnualSalary
        pensionPercent = snapshot.pensionEmployeePercent
        inflationPercent = snapshot.inflationPercent
        studentLoanPlan = snapshot.studentLoanPlan.flatMap(StudentLoanPlan.init(rawValue:))
        previousNetMonthlyIncome = snapshot.previousNetMonthlyIncome
        incomeChangedAt = snapshot.incomeChangedAt
        incomeChangeName = snapshot.incomeChangeName
        purchases = snapshot.notablePurchases.map {
            PortfolioPurchase(id: $0.id, name: $0.name, amount: $0.amount,
                              boughtOn: $0.boughtOn, fromDecision: $0.fromDecision)
        }
        settled = snapshot.settledDecisions.map {
            PortfolioSettlement(id: $0.id, wasSpent: $0.outcome == "spent",
                                actualAmount: $0.actualAmount,
                                estimatedAmount: $0.estimatedAmount,
                                settledAt: $0.settledAt)
        }
        goalName = snapshot.goalName
        goalTargetYear = snapshot.goalTargetYear
        savingsGoalAmount = snapshot.goalRequiredPot
        isOnTrack = snapshot.isOnTrack
        commitments = snapshot.commitments.map {
            Commitment(id: $0.id, name: $0.name, amount: $0.amount,
                       dueDate: $0.dueDate, savedSoFar: $0.savedSoFar)
        }
    }

    /// Fills the typed fields in, once, on request.
    ///
    /// The only place anything here writes to the profile — and it is user-initiated,
    /// one-time, and every field stays editable afterwards. That is a different thing
    /// from the overlay, which never writes: seeding a setup screen is help, whereas
    /// continuously overwriting what someone typed is taking the pen out of their hand.
    func seed(into profile: inout Profile) {
        if let netMonthlyIncome { profile.netMonthlyIncome = netMonthlyIncome }
        if let grossAnnualSalary, grossAnnualSalary > 0 {
            profile.grossAnnualSalary = grossAnnualSalary
            profile.incomeMode = .grossAnnual
        }
        if let pensionPercent { profile.pensionPercent = pensionPercent }
        if let studentLoanPlan { profile.studentLoanPlan = studentLoanPlan }
        if let inflationPercent { profile.inflationPercent = inflationPercent }
        if let savingsReturnPercent { profile.savingsReturnPercent = savingsReturnPercent }
        if let savingsBonusPercent { profile.savingsBonusPercent = savingsBonusPercent }
        if let monthlyRent { profile.monthlyRent = monthlyRent }
        if let committedOutgoings, let monthlyRent {
            profile.monthlyBills = max(0, committedOutgoings - monthlyRent)
        } else if let committedOutgoings {
            profile.monthlyBills = committedOutgoings
        }
        if let monthlySavingsTarget { profile.monthlySavingsTarget = monthlySavingsTarget }
        // What the saving is *for*. Portfolio keeps the goal and what it needs, and
        // both were being asked for again here — the name so a verdict can say "three
        // weeks off your house deposit" rather than "your savings goal", and the
        // amount so it can say how far back a purchase sets it.
        if let goalName, !goalName.isEmpty { profile.savingsGoalName = goalName }
        if let savingsGoalAmount, savingsGoalAmount > 0 {
            profile.savingsGoalAmount = savingsGoalAmount.rounded()
        }
    }

    /// Portfolio's sinking funds alongside anything typed here.
    ///
    /// Merged by id rather than replacing, so a commitment that only ever existed in
    /// this app survives the link being switched on. Portfolio's ids come from its
    /// own sinking funds and will not collide.
    func mergedCommitments(with typed: [Commitment]) -> [Commitment] {
        guard !commitments.isEmpty else { return typed }
        let fromPortfolio = Set(commitments.map(\.id))
        return commitments + typed.filter { !fromPortfolio.contains($0.id) }
    }
}


/// A purchase Portfolio recorded. Named separately from the wire format so the two
/// can drift without a decode breaking.
struct PortfolioPurchase: Identifiable, Equatable {
    let id: UUID
    let name: String
    let amount: Double
    let boughtOn: Date
    /// True where this purchase started life as a decision here, so it is not
    /// counted twice alongside the decision it came from.
    let fromDecision: Bool
}

/// What Portfolio did with a decision that was handed to it.
struct PortfolioSettlement: Identifiable, Equatable {
    let id: UUID
    let wasSpent: Bool
    let actualAmount: Double
    let estimatedAmount: Double
    let settledAt: Date

    /// Positive when the real cost came in above the estimate.
    var difference: Double { actualAmount - estimatedAmount }

    var isMeaningfullyDifferent: Bool {
        estimatedAmount > 0 && abs(difference) > max(5, estimatedAmount * 0.1)
    }
}

/// How well the money figures put into decisions here match what was actually
/// charged, once Portfolio has booked them.
///
/// Every verdict this app reaches rests on two numbers somebody typed into a form.
/// Nothing has ever checked them. This is the only feedback the estimates get.
struct EstimateAccuracy: Equatable {
    let counted: Int
    let spent: Int
    let dismissed: Int
    let totalEstimated: Double
    let totalActual: Double

    /// Below this there is nothing to learn: two purchases is not a tendency.
    static let minimumCounted = 4

    var isUsable: Bool { counted >= EstimateAccuracy.minimumCounted && totalEstimated > 0 }

    /// Above 1 means things cost more than expected.
    var ratio: Double { totalEstimated > 0 ? totalActual / totalEstimated : 1 }

    var overspendShare: Double { ratio - 1 }

    var isNoteworthy: Bool { isUsable && abs(overspendShare) >= 0.1 }

    static func measure(_ settlements: [PortfolioSettlement]) -> EstimateAccuracy {
        // Only decisions that turned into a real purchase can say anything about the
        // estimate. A dismissed one is counted, because "it never happened" is also
        // something worth knowing, but it contributes no money to the comparison.
        let spent = settlements.filter(\.wasSpent)
        return EstimateAccuracy(
            counted: settlements.count,
            spent: spent.count,
            dismissed: settlements.count - spent.count,
            totalEstimated: spent.reduce(0) { $0 + $1.estimatedAmount },
            totalActual: spent.reduce(0) { $0 + $1.actualAmount }
        )
    }
}
