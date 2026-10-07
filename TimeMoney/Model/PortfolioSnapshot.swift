import Foundation

/// The file Portfolio, an optional companion app, exports for this one to read.
///
/// Written the way Attention and Time / Money write theirs: pretty-printed, keys
/// sorted, dates as ISO 8601, so a person can read it and a tool can diff it.
///
/// Doubles rather than Decimals throughout. Decimal encodes to JSON in a shape that
/// is awkward to consume, and every reader works in Double — a
/// wire format should meet its readers where they are.
///
/// Additive only. Readers decode field by field with `decodeIfPresent`, so a newer
/// Portfolio never breaks an older reader; `formatVersion` exists for the day
/// something genuinely has to change meaning rather than just appear.
///
/// **Nothing here is a guess about an event.** Portfolio will happily show its owner
/// a forecast that includes a promotion they are hoping for and a house they have not
/// offered on; every figure in this file is built with those left out, whichever mode
/// the app itself is displaying. A reader prices a real decision against these
/// numbers today, and a budget widened by an unconfirmed raise is a budget that says
/// yes on the strength of a wish.
///
/// What is *not* stripped is the return and inflation the user has set. Those are
/// stated assumptions rather than guesses about events, they are published here as
/// `realReturnPercent` and `inflationPercent` for a reader to use or ignore, and
/// zeroing them would turn every figure below into a floor nobody asked for.
struct PortfolioSnapshot: Codable, Equatable {
    static let currentVersion = 1

    var formatVersion: Int = PortfolioSnapshot.currentVersion
    var exportedAt: Date = Date()

    // MARK: Committed outgoings

    /// Essential bills, monthly-equivalent. Excludes day-to-day spending.
    var monthlyEssentialBills: Double = 0
    /// The single largest essential housing cost, where one is identifiable. Readers
    /// that split rent from bills can use it; others can ignore it and use the total.
    var monthlyRent: Double?
    /// This month's share of costs that arrive in a lump.
    var monthlySinkingAccruals: Double = 0

    // MARK: Saving and spending

    /// What the plan actually puts away each month, from the allocation waterfall.
    var monthlySavingsTarget: Double = 0
    /// What day-to-day spending normally comes to, measured rather than typed.
    var typicalMonthlySpend: Double = 0
    /// What is genuinely safe to spend this month once the goal is served.
    ///
    /// Measured against a projection that counts only confirmed changes, so a raise
    /// somebody is hoping for cannot widen it.
    var monthlyDiscretionary: Double = 0
    /// A level of discretionary spending measured as one you have lived on, held back
    /// even when the goal would take every penny. Zero where there is too little
    /// history to measure one.
    ///
    /// A reader has to be able to tell free money from money the budget is protecting.
    /// "You have £300 spare" and "£150 of that is your floor and the rest is genuinely
    /// free" lead to different advice, and only the second is true.
    var monthlyDiscretionaryFloor: Double = 0
    /// How much of `monthlyDiscretionary` is the floor rather than what the plan
    /// allows — money being held back from the goal to keep the budget liveable.
    var discretionaryHeldBackByFloor: Double = 0

    // MARK: The living-wage line

    /// What a London life is calculated to cost each month, after tax: the London
    /// real Living Wage over a full-time year, per adult in the household.
    ///
    /// The third kind of floor a reader has to be able to tell apart.
    /// `monthlyDiscretionaryFloor` is protected by evidence — you have lived on it.
    /// This is protected by a calculation somebody else did, which knows nothing about
    /// your habits and cannot be talked down by a year of getting used to less. A
    /// reader deciding whether a commitment is affordable wants both, and they are not
    /// interchangeable.
    ///
    /// Zero when the line is switched off in Portfolio.
    var livingWageFloorMonthly: Double = 0
    /// What is left to live on, less that line. Negative means the plan is already
    /// saving past it.
    ///
    /// Published rather than left to be derived, because deriving it means redoing the
    /// tax arithmetic at the far end against a different set of thresholds, and two
    /// apps disagreeing about where the floor is would be worse than neither knowing.
    var headroomAboveLivingWage: Double = 0

    // MARK: The marginal pound

    /// The bonus a pound saved *right now* would attract — 25 while Lifetime ISA
    /// headroom remains and you are eligible, 0 once it is used.
    ///
    /// The marginal figure rather than a standing preference, because a bonus that
    /// has already been claimed flatters every decision not to spend.
    var marginalSavingsBonusPercent: Double = 0
    /// Why that figure is what it is, for a reader that shows its working.
    var marginalBonusReason: String = ""
    /// Expected return after inflation.
    var realReturnPercent: Double = 0
    var inflationPercent: Double = 0

    // MARK: The goal

    var goalName: String?
    var goalTargetYear: Int?
    /// In today's money, after tax on the way out. A target rather than a forecast:
    /// it falls out of the goal's own figures and today's mix of pots, so nothing
    /// unconfirmed goes into it.
    var goalRequiredPot: Double?
    /// Where the pot lands counting confirmed changes only.
    var goalProjectedPot: Double?
    var isOnTrack: Bool = false
    /// Share of simulated markets reaching the goal, where a range was computed.
    var successProbability: Double?

    /// Whether there is genuinely spare money once bills, saving and commitments are
    /// served. The financial gate on loosening, kept separate from any subjective
    /// sense of standing, which is not Portfolio's to judge.
    ///
    /// Confirmed changes only, which is the whole point of it: being ahead because of
    /// a promotion nobody has offered is not being ahead.
    var hasSlack: Bool = false
    /// How far ahead of the plan the projection is, per month. Negative is behind.
    var monthlySlack: Double = 0

    // MARK: Income

    var netMonthlyIncome: Double = 0
    /// Take-home before the most recent recorded change, and when that change landed.
    ///
    /// A reader that keeps savings in step with pay has to tell a raise from a figure
    /// that has always been that size. Its own copy of your income can only notice
    /// that a number it stores has changed — which also happens when you correct a
    /// typo. Portfolio has the dated record of what actually moved, so it says so.
    ///
    /// Confirmed steps only. A promotion recorded as expected still has its date go
    /// by, and a reader ratcheting saving up to meet it would be chasing a raise that
    /// never arrived.
    var previousNetMonthlyIncome: Double?
    var incomeChangedAt: Date?
    /// What the change was called: "Promotion", "Nursery ends".
    var incomeChangeName: String?
    var grossAnnualSalary: Double?
    var pensionEmployeePercent: Double?
    var pensionEmployerPercent: Double?
    /// Raw value of the UK repayment plan, or nil where there is no loan.
    var studentLoanPlan: String?

    // MARK: Commitments

    /// Sinking funds, in the shape a reader's own commitments already take.
    var commitments: [SnapshotCommitment] = []

    // MARK: What was actually bought

    /// One-off purchases of real size, for a reader that puts a past decision in
    /// context by spreading it over the time since.
    ///
    /// A reader can only amortise what it recorded itself, which is the handful of
    /// choices that went through it. These are the purchases that actually happened,
    /// with the date and the amount that was really charged.
    var notablePurchases: [SnapshotPurchase] = []

    /// What became of the decisions this app was handed.
    ///
    /// The other half of the loop: a decision arrives here as an amount somebody
    /// estimated, and leaves as an amount that was actually spent — or as one that
    /// never was. A reader that only sees what it sent can never check its own
    /// estimates against anything.
    var settledDecisions: [SettledDecision] = []

    // MARK: Context

    var netWorth: Double = 0
    var liquidCash: Double = 0
    var investablePot: Double = 0
    /// "forecast" or "guaranteed" — a reader should say which it is looking at.
    var projectionMode: String = "forecast"

    // MARK: Coding

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    func encoded() throws -> Data {
        try PortfolioSnapshot.encoder().encode(self)
    }

    static func decode(_ data: Data) throws -> PortfolioSnapshot {
        let snapshot = try decoder().decode(PortfolioSnapshot.self, from: data)
        guard snapshot.formatVersion <= currentVersion else { throw PortfolioSnapshotError.tooNew }
        return snapshot
    }

    /// A filename with the date in it, because a folder of files all called
    /// "portfolio.json" is not a history.
    var suggestedFilename: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_GB")
        formatter.dateFormat = "yyyy-MM-dd"
        return "Portfolio-\(formatter.string(from: exportedAt)).json"
    }
}

/// One dated amount being saved towards. Deliberately the same shape as the
/// commitments a reader already keeps, so no translation is needed at the far end.
struct SnapshotCommitment: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var dueDate: Date = Date()
    var savedSoFar: Double = 0
}

/// A purchase that actually happened, big enough to be worth looking back at.
struct SnapshotPurchase: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var boughtOn: Date = Date()
    /// The app's own spending category, as a plain string a reader can ignore.
    var category: String = ""
    /// True where the purchase came from a decision the reader itself sent over, so
    /// it is not counted twice by a reader that already knows about it.
    var fromDecision: Bool = false
}

/// What happened to a decision that was handed over.
struct SettledDecision: Codable, Equatable, Identifiable {
    /// The decision's id in the app that recorded it, not a new one.
    var id: UUID = UUID()
    /// "spent" when it turned into a real transaction, "dismissed" when it never did.
    var outcome: String = "spent"
    /// What was actually charged. Zero for a decision that was dismissed.
    var actualAmount: Double = 0
    /// What the sending app said it would cost.
    var estimatedAmount: Double = 0
    var settledAt: Date = Date()

    /// Positive when it cost more than the estimate.
    var difference: Double { actualAmount - estimatedAmount }
}

enum PortfolioSnapshotError: LocalizedError, Equatable {
    case tooNew
    case unreadable

    var errorDescription: String? {
        switch self {
        case .tooNew: "This file was written by a newer version of Portfolio than the one reading it."
        case .unreadable: "That doesn't look like a Portfolio snapshot."
        }
    }
}

// MARK: - Decoding that survives a newer writer

extension PortfolioSnapshot {
    /// Field by field, so a snapshot written before a field existed still opens.
    /// The same discipline Time / Money applies to its own profile, and for the same
    /// reason: every required key is a trapdoor under the files already written.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = PortfolioSnapshot()
        formatVersion = try c.decodeIfPresent(Int.self, forKey: .formatVersion) ?? fresh.formatVersion
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? fresh.exportedAt
        monthlyEssentialBills = try c.decodeIfPresent(Double.self, forKey: .monthlyEssentialBills) ?? fresh.monthlyEssentialBills
        monthlyRent = try c.decodeIfPresent(Double.self, forKey: .monthlyRent)
        monthlySinkingAccruals = try c.decodeIfPresent(Double.self, forKey: .monthlySinkingAccruals) ?? fresh.monthlySinkingAccruals
        monthlySavingsTarget = try c.decodeIfPresent(Double.self, forKey: .monthlySavingsTarget) ?? fresh.monthlySavingsTarget
        typicalMonthlySpend = try c.decodeIfPresent(Double.self, forKey: .typicalMonthlySpend) ?? fresh.typicalMonthlySpend
        monthlyDiscretionary = try c.decodeIfPresent(Double.self, forKey: .monthlyDiscretionary) ?? fresh.monthlyDiscretionary
        monthlyDiscretionaryFloor = try c.decodeIfPresent(Double.self, forKey: .monthlyDiscretionaryFloor) ?? fresh.monthlyDiscretionaryFloor
        discretionaryHeldBackByFloor = try c.decodeIfPresent(Double.self, forKey: .discretionaryHeldBackByFloor) ?? fresh.discretionaryHeldBackByFloor
        livingWageFloorMonthly = try c.decodeIfPresent(Double.self, forKey: .livingWageFloorMonthly) ?? fresh.livingWageFloorMonthly
        headroomAboveLivingWage = try c.decodeIfPresent(Double.self, forKey: .headroomAboveLivingWage) ?? fresh.headroomAboveLivingWage
        marginalSavingsBonusPercent = try c.decodeIfPresent(Double.self, forKey: .marginalSavingsBonusPercent) ?? fresh.marginalSavingsBonusPercent
        marginalBonusReason = try c.decodeIfPresent(String.self, forKey: .marginalBonusReason) ?? fresh.marginalBonusReason
        realReturnPercent = try c.decodeIfPresent(Double.self, forKey: .realReturnPercent) ?? fresh.realReturnPercent
        inflationPercent = try c.decodeIfPresent(Double.self, forKey: .inflationPercent) ?? fresh.inflationPercent
        goalName = try c.decodeIfPresent(String.self, forKey: .goalName)
        goalTargetYear = try c.decodeIfPresent(Int.self, forKey: .goalTargetYear)
        goalRequiredPot = try c.decodeIfPresent(Double.self, forKey: .goalRequiredPot)
        goalProjectedPot = try c.decodeIfPresent(Double.self, forKey: .goalProjectedPot)
        isOnTrack = try c.decodeIfPresent(Bool.self, forKey: .isOnTrack) ?? fresh.isOnTrack
        successProbability = try c.decodeIfPresent(Double.self, forKey: .successProbability)
        hasSlack = try c.decodeIfPresent(Bool.self, forKey: .hasSlack) ?? fresh.hasSlack
        monthlySlack = try c.decodeIfPresent(Double.self, forKey: .monthlySlack) ?? fresh.monthlySlack
        netMonthlyIncome = try c.decodeIfPresent(Double.self, forKey: .netMonthlyIncome) ?? fresh.netMonthlyIncome
        previousNetMonthlyIncome = try c.decodeIfPresent(Double.self, forKey: .previousNetMonthlyIncome)
        incomeChangedAt = try c.decodeIfPresent(Date.self, forKey: .incomeChangedAt)
        incomeChangeName = try c.decodeIfPresent(String.self, forKey: .incomeChangeName)
        grossAnnualSalary = try c.decodeIfPresent(Double.self, forKey: .grossAnnualSalary)
        pensionEmployeePercent = try c.decodeIfPresent(Double.self, forKey: .pensionEmployeePercent)
        pensionEmployerPercent = try c.decodeIfPresent(Double.self, forKey: .pensionEmployerPercent)
        studentLoanPlan = try c.decodeIfPresent(String.self, forKey: .studentLoanPlan)
        commitments = try c.decodeIfPresent([SnapshotCommitment].self, forKey: .commitments) ?? fresh.commitments
        notablePurchases = try c.decodeIfPresent([SnapshotPurchase].self, forKey: .notablePurchases) ?? fresh.notablePurchases
        settledDecisions = try c.decodeIfPresent([SettledDecision].self, forKey: .settledDecisions) ?? fresh.settledDecisions
        netWorth = try c.decodeIfPresent(Double.self, forKey: .netWorth) ?? fresh.netWorth
        liquidCash = try c.decodeIfPresent(Double.self, forKey: .liquidCash) ?? fresh.liquidCash
        investablePot = try c.decodeIfPresent(Double.self, forKey: .investablePot) ?? fresh.investablePot
        projectionMode = try c.decodeIfPresent(String.self, forKey: .projectionMode) ?? fresh.projectionMode
    }
}
