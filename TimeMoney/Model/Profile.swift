import Foundation

// MARK: - Enumerations describing how the user earns and how they feel about the balance

/// How the user prefers to tell the app what they earn.
enum IncomeMode: String, Codable, CaseIterable, Identifiable {
    case netMonthly
    case grossAnnual

    var id: String { rawValue }

    var label: String {
        switch self {
        case .netMonthly: return "Take-home"
        case .grossAnnual: return "Salary"
        }
    }

    var explanation: String {
        switch self {
        case .netMonthly: return "What actually lands in your account each month."
        case .grossAnnual: return "Your gross salary. Tax, National Insurance, pension and student loan are estimated for you."
        }
    }
}

/// The user's felt position on the time/money seesaw. This is deliberately subjective:
/// two people with identical finances can value an hour very differently.
enum Stance: String, Codable, CaseIterable, Identifiable {
    case moreTimeThanMoney
    case neither
    case moreMoneyThanTime

    var id: String { rawValue }

    var label: String {
        switch self {
        case .moreTimeThanMoney: return "More time than money"
        case .neither: return "Roughly balanced"
        case .moreMoneyThanTime: return "More money than time"
        }
    }

    var shortLabel: String {
        switch self {
        case .moreTimeThanMoney: return "Time-rich"
        case .neither: return "Balanced"
        case .moreMoneyThanTime: return "Time-poor"
        }
    }

    /// Scarcity adjustment. If hours are the scarce resource they are worth more;
    /// if money is scarce, an hour buys less.
    var multiplier: Double {
        switch self {
        case .moreTimeThanMoney: return 0.7
        case .neither: return 1.0
        case .moreMoneyThanTime: return 1.4
        }
    }

    var explanation: String {
        switch self {
        case .moreTimeThanMoney: return "Spare hours are easy to come by, so they're valued at a discount. Saving money wins more often."
        case .neither: return "No adjustment. Your rate comes straight from your numbers."
        case .moreMoneyThanTime: return "Hours are the scarce thing, so they're valued at a premium. Paying to save time wins more often."
        }
    }
}

/// Whether the user can actually turn an extra hour into money. This matters enormously:
/// a salaried employee who saves an hour does not get paid for it, so their hour is worth
/// what that hour is worth to them, not what their employer pays.
enum EarningFlexibility: String, Codable, CaseIterable, Identifiable {
    case fixed
    case occasional
    case flexible

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fixed: return "Fixed salary"
        case .occasional: return "Some overtime or side work"
        case .flexible: return "I bill by the hour"
        }
    }

    var explanation: String {
        switch self {
        case .fixed: return "An extra hour can't be sold, so your rate is based on what an hour is worth to you, not what work pays."
        case .occasional: return "You can sometimes convert hours into money, so your rate blends both."
        case .flexible: return "Almost any hour can be billed, so your billing rate anchors your time value."
        }
    }

    var usesMarginalRate: Bool { self != .fixed }
}

/// UK student loan repayment plans. Thresholds are 2025/26.
enum StudentLoanPlan: String, Codable, CaseIterable, Identifiable {
    case none, plan1, plan2, plan4, plan5, postgraduate

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .plan1: return "Plan 1"
        case .plan2: return "Plan 2"
        case .plan4: return "Plan 4 (Scotland)"
        case .plan5: return "Plan 5"
        case .postgraduate: return "Postgraduate"
        }
    }

    var threshold: Double {
        switch self {
        case .none: return .infinity
        case .plan1: return 26_065
        case .plan2: return 28_470
        case .plan4: return 32_745
        case .plan5: return 25_000
        case .postgraduate: return 21_000
        }
    }

    var rate: Double {
        switch self {
        case .postgraduate: return 0.06
        case .none: return 0
        default: return 0.09
        }
    }
}

enum TaxRegion: String, Codable, CaseIterable, Identifiable {
    case englandWalesNI
    case scotland

    var id: String { rawValue }

    var label: String {
        switch self {
        case .englandWalesNI: return "England, Wales & NI"
        case .scotland: return "Scotland"
        }
    }
}



/// Where you stand on the things you're trying to get ahead of.
///
/// The app is otherwise all downside pressure: short of a goal, busy week, money
/// committed. None of that has an opposite, and it should — being genuinely ahead
/// on work, on saving, on whatever you're building towards is a reason to loosen
/// up and take the thing that would make you happy.
///
/// It only ever loosens when it can be afforded. Feeling ahead at work while the
/// rent is a stretch is not a licence to spend, and the app won't pretend otherwise.
enum Standing: String, Codable, CaseIterable, Identifiable {
    case behind, onTrack, ahead

    var id: String { rawValue }

    var label: String {
        switch self {
        case .behind: return "Behind where I want to be"
        case .onTrack: return "About where I should be"
        case .ahead: return "Ahead of where I need to be"
        }
    }

    /// What it does to enjoyment. Being behind doesn't make pleasure worthless —
    /// it just stops it winning arguments it shouldn't.
    var joyMultiplier: Double {
        switch self {
        case .behind: return 0.8
        case .onTrack: return 1.0
        case .ahead: return 1.3
        }
    }

    var explanation: String {
        switch self {
        case .behind: return "Enjoyment counts for a bit less until you've caught up."
        case .onTrack: return "No adjustment."
        case .ahead: return "Enjoyment counts for more — you've earned the right to spend some of it. Applies only while you can actually afford to."
        }
    }
}

/// How much is on at the moment.
///
/// Chronic time pressure is already in the numbers — fewer free hours raises what
/// an hour is worth. This is for the acute kind: the week where everything lands
/// at once. It expires by itself after seven days, because a pressure setting you
/// have to remember to turn off is worse than no setting at all.
enum LoadLevel: String, Codable, CaseIterable, Identifiable {
    case quieter, normal, busier

    var id: String { rawValue }

    var label: String {
        switch self {
        case .quieter: return "Quieter than usual"
        case .normal: return "A normal week"
        case .busier: return "Busier than usual"
        }
    }

    var shortLabel: String {
        switch self {
        case .quieter: return "Quiet week"
        case .normal: return "Normal week"
        case .busier: return "Busy week"
        }
    }

    /// The same three, without the word they all share. For text sizes where
    /// "Normal week" doesn't fit across a third of the screen and truncates to
    /// "Normal w…" — at which point the shared word is costing more than it says.
    var tightLabel: String {
        switch self {
        case .quieter: return "Quiet"
        case .normal: return "Normal"
        case .busier: return "Busy"
        }
    }

    var multiplier: Double {
        switch self {
        case .quieter: return 0.8
        case .normal: return 1.0
        case .busier: return 1.25
        }
    }

    var explanation: String {
        switch self {
        case .quieter: return "Hours are easier to come by this week, so saving money wins more often."
        case .normal: return "No adjustment."
        case .busier: return "Everything's landed at once, so an hour is worth more than usual. Lifts on its own in a week."
        }
    }
}

// MARK: - Things coming up

/// A specific thing you're putting money towards, with a deadline.
///
/// This is deliberately not the same as the monthly savings target. Savings is a
/// standing commitment you top up forever; this is a **threshold with a date** —
/// being eighty pounds short of a ticket doesn't cost you eighty pounds of
/// happiness, it costs you the gig.
struct Commitment: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var amount: Double = 0
    var dueDate: Date = Date().addingTimeInterval(60 * 60 * 24 * 30)
    var savedSoFar: Double = 0

    var isActive: Bool { dueDate > Date() && amount > 0 }

    var monthsAway: Double {
        max(0.25, dueDate.timeIntervalSinceNow / (60 * 60 * 24 * 30.44))
    }

    var daysAway: Int {
        max(0, Int((dueDate.timeIntervalSinceNow / 86_400).rounded()))
    }

    /// What's still to find, given what you can put aside each month between now and then.
    func shortfall(discretionaryMonthly: Double) -> Double {
        let available = max(0, discretionaryMonthly) * monthsAway + savedSoFar
        return max(0, amount - available)
    }
}

// MARK: - Profile

/// Everything the app needs to know about the user, configured once and then left alone.
struct Profile: Codable, Equatable {

    // Income
    var incomeMode: IncomeMode = .netMonthly
    var netMonthlyIncome: Double = 2_400
    var grossAnnualSalary: Double = 38_000
    var pensionPercent: Double = 5
    var studentLoanPlan: StudentLoanPlan = .none
    var taxRegion: TaxRegion = .englandWalesNI

    // Time given to work
    var paidHoursPerWeek: Double = 37.5
    var commuteHoursPerWeek: Double = 5

    // Committed outgoings
    var monthlyRent: Double = 900
    var monthlyBills: Double = 350
    var monthlySavingsTarget: Double = 300

    /// Optional: what you are saving *towards*, so spending can be expressed as a delay.
    var savingsGoalAmount: Double = 0
    /// Empty by default so the field shows its placeholder rather than the word
    /// "savings goal" sitting in it looking like something you typed. Prose falls
    /// back to that wording where it needs a noun.
    var savingsGoalName: String = ""

    /// What to call the savings goal in a sentence.
    var savingsGoalLabel: String {
        savingsGoalName.isEmpty ? "savings goal" : savingsGoalName
    }

    /// Specific things coming up, over and above the standing savings plan.
    var commitments: [Commitment] = []

    // Felt position
    var stance: Stance = .neither
    var earningFlexibility: EarningFlexibility = .fixed
    var marginalHourlyRate: Double = 35

    // Time budget
    var sleepHoursPerNight: Double = 8
    var lifeAdminHoursPerWeek: Double = 14

    /// Calibration for the feel slider: the most you'd happily pay for a genuinely
    /// memorable evening with someone you care about. A +3 "feel" is worth exactly this.
    var joyAnchor: Double = 60

    /// Calibration for health: what one genuinely good-for-you choice is worth, once.
    ///
    /// Small on purpose, so health stays quiet on one-off decisions and becomes
    /// decisive on daily ones — £4 a time is a bit under £1,500 a year for a habit.
    ///
    /// Worth knowing where this sits: UK health economics values a quality-adjusted
    /// life year at roughly £20,000–£30,000, and working back from that to a single
    /// walk lands nearer £1 than £4. The higher figure is deliberate, because the
    /// clinical gain isn't the whole of it — energy, sleep and mood are real and
    /// show up the same day. It errs towards valuing health, which is the direction
    /// worth erring in, and it's adjustable.
    var healthAnchor: Double = 4

    /// Flat annual inflation, used to grow future recurring amounts and to restate
    /// past spending in today's money. Kept as one number on purpose: anything more
    /// elaborate would be false precision on top of estimates you've eyeballed anyway.
    var inflationPercent: Double = 3

    /// What money left alone would really earn, after inflation. Nominal five per
    /// cent against three per cent inflation is two per cent real, and real is the
    /// right figure here because future costs are already being inflated.
    var savingsReturnPercent: Double = 2

    /// An immediate uplift on money paid into a restricted account — 25 for a
    /// Lifetime ISA. Only worth setting if you'd genuinely be putting this money
    /// there and are under the annual cap; otherwise it flatters every decision
    /// not to spend.
    var savingsBonusPercent: Double = 0

    /// Calibration for learning and capability. What it's worth to come out of
    /// something knowing how to do it — a skill you keep, rather than an evening
    /// you enjoyed. Front-loaded: most of the value is in the first few goes.
    var growthAnchor: Double = 40

    /// Whether you're ahead or behind on the things you're working towards.
    var standing: Standing = .onTrack

    /// How this particular week is going, and when that was last said.
    var loadLevel: LoadLevel = .normal
    var loadSetAt: Date? = nil

    /// The week's pressure, ignored once it's more than seven days old.
    var effectiveLoad: LoadLevel {
        guard loadLevel != .normal, let setAt = loadSetAt else { return .normal }
        return Date().timeIntervalSince(setAt) < 7 * 24 * 60 * 60 ? loadLevel : .normal
    }

    /// Whether to take the shape of the week from Attention's own records rather
    /// than from what was typed in here.
    ///
    /// One switch rather than a field-by-field import, because the figures only make
    /// sense together: measured free evenings against self-reported sleep would count
    /// some hours twice and lose others entirely. While it's on, the app shows every
    /// measured figure with the number of days behind it, so the arithmetic stays
    /// checkable — a rate you can't interrogate is a rate you won't act on.
    var attentionLinkEnabled: Bool = false

    /// Whether to take committed costs, the savings target and the bonus on the next
    /// pound from Portfolio rather than from what was typed here.
    ///
    /// Same shape as the Attention link, and for the same reason: nothing is
    /// overwritten, so switching it off puts every figure back exactly as it was.
    var portfolioLinkEnabled: Bool = false

    /// If set, replaces the derived rate entirely.
    var rateOverride: Double? = nil

    /// What you earned and saved when the two were last in step, so a rise in pay
    /// can be measured against something rather than passing unnoticed.
    var incomeBaseline: IncomeBaseline? = nil

    /// The take-home at which a suggested rise in savings was turned down. Stops the
    /// same raise being raised again every time the app opens.
    var savingsRaiseDeclinedAtIncome: Double? = nil

    /// How often to write an unattended snapshot. Zero is off.
    ///
    /// Every few days by default rather than weekly, so a reinstall rarely costs more
    /// than a few days of decisions.
    var autoBackupEveryDays: Int = 3

    /// Situations taken off the browse list.
    ///
    /// Optional on purpose: synthesised decoding throws on a key it can't find, so a
    /// plain `Set` here would have failed every profile saved before this existed.
    /// Hidden is a shelf, not a bin — search still finds them, and settings brings
    /// them back, because the one you hid in March is the one you need in June.
    var hiddenScenarios: [String]? = nil

    var hasCompletedSetup: Bool = false

    /// Ask for Face ID before showing anything. Off by default: it is a real cost in
    /// friction and the app should not decide for you that your pay is a secret.
    var requireBiometricUnlock: Bool = false

    /// Sunday-evening nudge to look back at the week's decisions.
    var weeklyReviewEnabled: Bool = false

    /// Whether there is genuinely slack to loosen with. Deliberately computed from
    /// the profile alone so it stays cheap — the evaluation runs this many times over.
    var hasSlack: Bool {
        let net = incomeMode == .netMonthly
            ? max(0, netMonthlyIncome)
            : max(0, UKTax.takeHome(for: self).netMonthly)
        let spare = net - max(0, monthlyRent) - max(0, monthlyBills) - max(0, monthlySavingsTarget)
        guard spare > 0 else { return false }
        return !commitments.contains { $0.isActive && $0.shortfall(discretionaryMonthly: spare) > 0 }
    }

    /// Standing only ever loosens things when there's slack to loosen with.
    var effectiveJoyMultiplier: Double {
        effectiveJoyMultiplier(hasSlack: nil)
    }

    /// Standing only ever loosens things when there's slack to loosen with.
    ///
    /// Portfolio can answer the financial half of that question far better than a
    /// profile snapshot can — it has the balances and the projection. `standing`
    /// itself stays yours: its scope is work, saving "and whatever you're building
    /// towards", which is not a thing any spreadsheet gets to decide.
    func effectiveJoyMultiplier(hasSlack override: Bool?) -> Double {
        let slack = override ?? hasSlack
        return standing == .ahead && !slack ? 1.0 : standing.joyMultiplier
    }

    static let weeksPerMonth: Double = 52.0 / 12.0
    static let daysPerMonth: Double = 365.25 / 12.0
}

// As on Decision: in an extension, so the no-argument initialiser survives.
extension Profile {

    /// Decoded field by field, so a profile written by an older version still opens.
    ///
    /// Every one of these was fatal if absent — all thirty-one of them — which made
    /// each new setting a trapdoor under the answers already given. Anything missing
    /// falls back to what a fresh profile would have had.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = Profile()
        incomeMode = try c.decodeIfPresent(IncomeMode.self, forKey: .incomeMode) ?? fresh.incomeMode
        netMonthlyIncome = try c.decodeIfPresent(Double.self, forKey: .netMonthlyIncome) ?? fresh.netMonthlyIncome
        grossAnnualSalary = try c.decodeIfPresent(Double.self, forKey: .grossAnnualSalary) ?? fresh.grossAnnualSalary
        pensionPercent = try c.decodeIfPresent(Double.self, forKey: .pensionPercent) ?? fresh.pensionPercent
        studentLoanPlan = try c.decodeIfPresent(StudentLoanPlan.self, forKey: .studentLoanPlan) ?? fresh.studentLoanPlan
        taxRegion = try c.decodeIfPresent(TaxRegion.self, forKey: .taxRegion) ?? fresh.taxRegion
        paidHoursPerWeek = try c.decodeIfPresent(Double.self, forKey: .paidHoursPerWeek) ?? fresh.paidHoursPerWeek
        commuteHoursPerWeek = try c.decodeIfPresent(Double.self, forKey: .commuteHoursPerWeek) ?? fresh.commuteHoursPerWeek
        monthlyRent = try c.decodeIfPresent(Double.self, forKey: .monthlyRent) ?? fresh.monthlyRent
        monthlyBills = try c.decodeIfPresent(Double.self, forKey: .monthlyBills) ?? fresh.monthlyBills
        monthlySavingsTarget = try c.decodeIfPresent(Double.self, forKey: .monthlySavingsTarget) ?? fresh.monthlySavingsTarget
        savingsGoalAmount = try c.decodeIfPresent(Double.self, forKey: .savingsGoalAmount) ?? fresh.savingsGoalAmount
        savingsGoalName = try c.decodeIfPresent(String.self, forKey: .savingsGoalName) ?? fresh.savingsGoalName
        commitments = try c.decodeIfPresent([Commitment].self, forKey: .commitments) ?? fresh.commitments
        stance = try c.decodeIfPresent(Stance.self, forKey: .stance) ?? fresh.stance
        earningFlexibility = try c.decodeIfPresent(EarningFlexibility.self, forKey: .earningFlexibility) ?? fresh.earningFlexibility
        marginalHourlyRate = try c.decodeIfPresent(Double.self, forKey: .marginalHourlyRate) ?? fresh.marginalHourlyRate
        sleepHoursPerNight = try c.decodeIfPresent(Double.self, forKey: .sleepHoursPerNight) ?? fresh.sleepHoursPerNight
        lifeAdminHoursPerWeek = try c.decodeIfPresent(Double.self, forKey: .lifeAdminHoursPerWeek) ?? fresh.lifeAdminHoursPerWeek
        joyAnchor = try c.decodeIfPresent(Double.self, forKey: .joyAnchor) ?? fresh.joyAnchor
        healthAnchor = try c.decodeIfPresent(Double.self, forKey: .healthAnchor) ?? fresh.healthAnchor
        inflationPercent = try c.decodeIfPresent(Double.self, forKey: .inflationPercent) ?? fresh.inflationPercent
        savingsReturnPercent = try c.decodeIfPresent(Double.self, forKey: .savingsReturnPercent) ?? fresh.savingsReturnPercent
        savingsBonusPercent = try c.decodeIfPresent(Double.self, forKey: .savingsBonusPercent) ?? fresh.savingsBonusPercent
        growthAnchor = try c.decodeIfPresent(Double.self, forKey: .growthAnchor) ?? fresh.growthAnchor
        standing = try c.decodeIfPresent(Standing.self, forKey: .standing) ?? fresh.standing
        loadLevel = try c.decodeIfPresent(LoadLevel.self, forKey: .loadLevel) ?? fresh.loadLevel
        loadSetAt = try c.decodeIfPresent(Date.self, forKey: .loadSetAt)
        attentionLinkEnabled = try c.decodeIfPresent(Bool.self, forKey: .attentionLinkEnabled) ?? fresh.attentionLinkEnabled
        portfolioLinkEnabled = try c.decodeIfPresent(Bool.self, forKey: .portfolioLinkEnabled) ?? fresh.portfolioLinkEnabled
        rateOverride = try c.decodeIfPresent(Double.self, forKey: .rateOverride)
        incomeBaseline = try c.decodeIfPresent(IncomeBaseline.self, forKey: .incomeBaseline)
        savingsRaiseDeclinedAtIncome = try c.decodeIfPresent(Double.self, forKey: .savingsRaiseDeclinedAtIncome)
        autoBackupEveryDays = try c.decodeIfPresent(Int.self, forKey: .autoBackupEveryDays) ?? fresh.autoBackupEveryDays
        hiddenScenarios = try c.decodeIfPresent([String].self, forKey: .hiddenScenarios)
        hasCompletedSetup = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedSetup) ?? fresh.hasCompletedSetup
        requireBiometricUnlock = try c.decodeIfPresent(Bool.self, forKey: .requireBiometricUnlock) ?? fresh.requireBiometricUnlock
        weeklyReviewEnabled = try c.decodeIfPresent(Bool.self, forKey: .weeklyReviewEnabled) ?? fresh.weeklyReviewEnabled
    }
}
