import Foundation

enum MoneyDirection: String, Codable, Equatable {
    case cost      // money leaves you
    case receive   // money comes to you

    var sign: Double { self == .cost ? 1 : -1 }
    var label: String { self == .cost ? "Cost" : "You get" }

    /// The same label, said in the cadence the decision actually runs at.
    ///
    /// An unlabelled box on a card called "Buy it outright" is an invitation to type
    /// the purchase price into the field that then charges it every month — and the
    /// app has no way of telling £210 once from £210 a month apart from where it was
    /// typed. Saying "Cost a month" on the field itself is the only place the
    /// distinction can be made before the arithmetic is already wrong.
    func label(every frequency: Frequency) -> String {
        frequency.isRecurring ? "\(label) a \(frequency.shortLabel)" : label
    }

    /// The same again, for a side that is charged per go rather than per period.
    ///
    /// A gym membership is billed monthly however often you turn up; a pay-as-you-go
    /// swim is charged per swim. Calling both of them "Cost a month" while multiplying
    /// one of them by the number of visits is the same class of mistake as the one
    /// above, one level down.
    func label(every frequency: Frequency, eachTime: Bool) -> String {
        eachTime ? "\(label) each time" : label(every: frequency)
    }
}

enum Frequency: String, Codable, CaseIterable, Identifiable, Equatable {
    case once, daily, weekly, fortnightly, monthly, yearly

    var id: String { rawValue }

    var label: String {
        switch self {
        case .once: return "Just once"
        case .daily: return "Every day"
        case .weekly: return "Every week"
        case .fortnightly: return "Every 2 weeks"
        case .monthly: return "Every month"
        case .yearly: return "Every year"
        }
    }

    var shortLabel: String {
        switch self {
        case .once: return "once"
        case .daily: return "day"
        case .weekly: return "week"
        case .fortnightly: return "fortnight"
        case .monthly: return "month"
        case .yearly: return "year"
        }
    }

    var perYear: Double {
        switch self {
        case .once: return 1
        case .daily: return 365.25
        case .weekly: return 52
        case .fortnightly: return 26
        case .monthly: return 12
        case .yearly: return 1
        }
    }

    var isRecurring: Bool { self != .once }
}

/// One side of a decision. Amounts are entered as positive numbers; `direction`
/// decides whether they flow towards you or away from you.
struct DecisionOption: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var name: String = ""
    var direction: MoneyDirection = .cost

    /// Money and time per occurrence.
    var money: Double = 0
    var minutes: Double = 0

    /// One-off money and time to get started — the admin of switching, the cost of moving.
    var setupMoney: Double = 0
    var setupMinutes: Double = 0

    /// Which way the one-off money flows, when that differs from the recurring money.
    ///
    /// Training is the case that forces this open: fees leave you now and a pay rise
    /// arrives every month for years afterwards. Signing both from one field makes that
    /// decision literally unsayable — you either book the pay rise as a cost or the fees
    /// as income, and £3,000 out with £200 a month back comes out as £15,916 in whichever
    /// direction you pick. Nil means "the same way as everything else", which is the
    /// ordinary case and what every decision saved before this did.
    var setupDirection: MoneyDirection? = nil

    /// The direction the one-off money actually flows.
    var effectiveSetupDirection: MoneyDirection { setupDirection ?? direction }

    /// How long this one lasts before it has to be bought again, in months.
    ///
    /// Nil means it isn't replaced on a schedule, which is the ordinary case — the
    /// one-off is genuinely one-off and the decision's own setup frequency says the rest.
    var lifespanMonths: Double? = nil

    /// How many times this gets bought over `horizonMonths`.
    ///
    /// Rounded up, because you replace a thing when it dies rather than buying four
    /// fifths of a new one — five years of boots that last two is three pairs, bought
    /// at the start, at two years and at four.
    func purchases(over horizonMonths: Double, fallback: Double) -> Double {
        guard let lifespan = lifespanMonths, lifespan > 0 else { return fallback }
        return max(1, (max(0, horizonMonths) / lifespan).rounded(.up))
    }

    /// How this option makes you feel, -3 to +3. +3 is worth your joy anchor.
    var feel: Int = 0

    /// What it does to your body, which is not the same question as how it feels.
    var health: HealthEffect = .neutral

    /// What you'd come away able to do that you couldn't before.
    var growth: GrowthEffect = .none

    /// How much of the use you're imagining will really happen.
    var usageConfidence: UsageConfidence = .certain

    /// How tied this option is to someone else's timetable.
    var flexibility: Flexibility = .free


/// What it's worth to the other people involved.
    var socialValue: SocialValue = .none

    /// How likely the enjoyment is to actually materialise.
    var joyConfidence: JoyConfidence = .certain

    /// Whether skipping it now really means missing it.
    var deferability: Deferability = .nowOrNever

    /// What this pushes out of the way to happen.
    var displaces: Displacement = .nothing

    /// How many times this option happens in each period.
    ///
    /// The two sides of a decision often don't happen at the same rate: one grocery
    /// delivery a week against three trips to the shop, one batch cook against seven
    /// dinners. Comparing them one-for-one quietly flatters whichever one you do more
    /// often, which is usually the one you're trying to get away from.
    var timesEach: Double = 1

    /// Whether `money` is charged once per go or once per period.
    ///
    /// Only means anything when `timesEach` is above one, and then it means a great
    /// deal: eight swims at £6 is £48 a month, and a membership is £40 whether you go
    /// eight times or none. The time always counts per go — you spend the hour either
    /// way. Optional so decisions saved before this existed still decode.
    var chargedEachTime: Bool? = nil

    /// Whether the time is dead time or time you can actually use.
    var usableTime: UsableTime = .none

    /// Whether it leaves you wrung out afterwards.
    var drain: DrainLevel = .fine

    /// How often this option goes wrong.
    var reliability: Reliability = .never

    /// Per go unless the scenario says otherwise, which is what "cost" plainly means.

    var isChargedEachTime: Bool { chargedEachTime ?? true }

    /// What one period's worth of `money` comes to, before inflation or the horizon.
    /// The place the two cadences actually differ, and the only place they need to.
    var moneyPerPeriod: Double {
        isChargedEachTime ? money * max(0, timesEach) : money
    }

    var isEmpty: Bool {
        money == 0 && minutes == 0 && setupMoney == 0 && setupMinutes == 0 && feel == 0
    }
}

// MARK: - Scenarios

// MARK: - Review

enum ReviewOutcome: String, Codable, CaseIterable, Identifiable, Equatable {
    case rightCall, wrongCall, cantTell

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rightCall: return "Right call"
        case .wrongCall: return "Wrong call"
        case .cantTell: return "Can't tell"
        }
    }

    var symbol: String {
        switch self {
        case .rightCall: return "hand.thumbsup.fill"
        case .wrongCall: return "hand.thumbsdown.fill"
        case .cantTell: return "questionmark"
        }
    }
}

/// Which way a regret points. This is what calibration reads.
enum RegretDirection: String, Codable, Equatable {
    case shouldHaveSpent      // wished they'd paid to save the time
    case shouldHaveSaved      // wished they'd kept the money
    case unclear
}

// MARK: - Decision

struct Decision: Codable, Equatable, Identifiable {
    var id: UUID = UUID()
    var title: String = ""
    var scenario: ScenarioKind = .custom
    var createdAt: Date = Date()

    var optionA: DecisionOption = DecisionOption()
    var optionB: DecisionOption = DecisionOption()

    /// "Should I?" rather than "A or B?" — B is an untouched do-nothing option.
    var isYesNo: Bool = false

    var frequency: Frequency = .once

    /// How often the "one-off" fields actually recur. Usually never — but rent runs
    /// monthly alongside a daily commute, and counting it once is badly wrong.
    var setupFrequency: Frequency = .once

    var horizonMonths: Double = 12

    /// How soon this chance comes round again. Applies to enjoyment only.
    var scarcity: Scarcity = .often

    /// What a bad outcome costs. A property of the situation, shared by both options.
    var stakes: Stakes = .none

    /// What one bad outcome actually costs, when it costs money.
    ///
    /// Without it the app had to guess from the largest figure in front of it, which
    /// on a warranty is the cover itself: £60 of protection on an £800 machine reckoned
    /// a breakdown set you back £60, and so priced the cover against a tenth of what it
    /// was covering. Nil keeps the old guess, which is right often enough — a lodger who
    /// doesn't pay costs you the month's rent, and that is already on the screen.
    var costIfItGoesWrong: Double? = nil

    /// How many people's time this genuinely affects.
    var peopleCount: Int = 1

    /// Which questions the flow has already put to the user, so it doesn't repeat itself.
    var answeredQuestions: [String] = []

    // Record
    var recordedVerdict: String? = nil
    var recordedRate: Double? = nil
    var recommendedSide: String? = nil

    /// What the user actually did, which may not be what the app said.
    var chosenSide: String? = nil

    /// What choosing it committed over the following month, captured at the time.
    /// Positive means money out. Held as a fact rather than recomputed, so editing
    /// a decision later can't quietly rewrite what you actually spent.
    var committedMoney: Double? = nil

    /// The hours the thing you chose actually takes, once. Used to suggest — gently —
    /// that you go and do it before deciding anything else.
    var committedMinutes: Double? = nil
    var committedAt: Date? = nil

    /// Set when the app decided by itself that an option would run past the point
    /// the evening is meant to start winding down. Kept on the decision rather than
    /// recomputed, so a decision looked at in a fortnight still says why it was
    /// counted the way it was.
    var sleepBoundaryNote: String? = nil

    var review: ReviewOutcome? = nil
    var reviewedAt: Date? = nil

    var isSaved: Bool = false

    static func make(from kind: ScenarioKind) -> Decision {
        let t = kind.template
        var d = Decision()
        d.scenario = kind
        d.frequency = t.frequency
        d.setupFrequency = t.setupFrequency
        d.horizonMonths = t.horizonMonths
        d.isYesNo = t.isYesNo
        // Names are left empty on purpose. Most decisions arrive as two things,
        // not as a "faster one" and a "cheaper one", and the template labels are
        // only ever placeholders. The verdict works out what to call them from
        // the numbers actually entered.
        d.optionA = DecisionOption(direction: t.directionA, setupDirection: t.setupDirectionA,
                                   chargedEachTime: t.chargedEachTimeA)
        d.optionB = DecisionOption(direction: t.directionB, setupDirection: t.setupDirectionB,
                                   chargedEachTime: t.chargedEachTimeB)
        return d
    }
}

// The memberwise and no-argument initialisers survive only if this lives in an
// extension rather than in the body of the type.
extension DecisionOption {
    /// Decoded field by field, so that a decision saved by an older version still opens.
    ///
    /// Synthesised decoding throws on any key it cannot find — defaults and all — so
    /// every field ever added here was a landmine under everything already saved:
    /// six of them would still refuse to open a decision written before they existed.
    /// Anything missing now falls back to what a new DecisionOption would have had.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = DecisionOption()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? fresh.id
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? fresh.name
        direction = try c.decodeIfPresent(MoneyDirection.self, forKey: .direction) ?? fresh.direction
        money = try c.decodeIfPresent(Double.self, forKey: .money) ?? fresh.money
        minutes = try c.decodeIfPresent(Double.self, forKey: .minutes) ?? fresh.minutes
        setupMoney = try c.decodeIfPresent(Double.self, forKey: .setupMoney) ?? fresh.setupMoney
        setupMinutes = try c.decodeIfPresent(Double.self, forKey: .setupMinutes) ?? fresh.setupMinutes
        setupDirection = try c.decodeIfPresent(MoneyDirection.self, forKey: .setupDirection)
        lifespanMonths = try c.decodeIfPresent(Double.self, forKey: .lifespanMonths)
        feel = try c.decodeIfPresent(Int.self, forKey: .feel) ?? fresh.feel
        health = try c.decodeIfPresent(HealthEffect.self, forKey: .health) ?? fresh.health
        growth = try c.decodeIfPresent(GrowthEffect.self, forKey: .growth) ?? fresh.growth
        usageConfidence = try c.decodeIfPresent(UsageConfidence.self, forKey: .usageConfidence) ?? fresh.usageConfidence
        flexibility = try c.decodeIfPresent(Flexibility.self, forKey: .flexibility) ?? fresh.flexibility
        socialValue = try c.decodeIfPresent(SocialValue.self, forKey: .socialValue) ?? fresh.socialValue
        joyConfidence = try c.decodeIfPresent(JoyConfidence.self, forKey: .joyConfidence) ?? fresh.joyConfidence
        deferability = try c.decodeIfPresent(Deferability.self, forKey: .deferability) ?? fresh.deferability
        displaces = try c.decodeIfPresent(Displacement.self, forKey: .displaces) ?? fresh.displaces
        timesEach = try c.decodeIfPresent(Double.self, forKey: .timesEach) ?? fresh.timesEach
        chargedEachTime = try c.decodeIfPresent(Bool.self, forKey: .chargedEachTime)
        usableTime = try c.decodeIfPresent(UsableTime.self, forKey: .usableTime) ?? fresh.usableTime
        drain = try c.decodeIfPresent(DrainLevel.self, forKey: .drain) ?? fresh.drain
        reliability = try c.decodeIfPresent(Reliability.self, forKey: .reliability) ?? fresh.reliability
    }
}

// The memberwise and no-argument initialisers survive only if this lives in an
// extension rather than in the body of the type.
extension Decision {
    /// Decoded field by field, so that a decision saved by an older version still opens.
    ///
    /// Synthesised decoding throws on any key it cannot find — defaults and all — so
    /// every field ever added here was a landmine under everything already saved:
    /// six of them would still refuse to open a decision written before they existed.
    /// Anything missing now falls back to what a new Decision would have had.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let fresh = Decision()
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? fresh.id
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? fresh.title
        scenario = try c.decodeIfPresent(ScenarioKind.self, forKey: .scenario) ?? fresh.scenario
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? fresh.createdAt
        optionA = try c.decodeIfPresent(DecisionOption.self, forKey: .optionA) ?? fresh.optionA
        optionB = try c.decodeIfPresent(DecisionOption.self, forKey: .optionB) ?? fresh.optionB
        isYesNo = try c.decodeIfPresent(Bool.self, forKey: .isYesNo) ?? fresh.isYesNo
        frequency = try c.decodeIfPresent(Frequency.self, forKey: .frequency) ?? fresh.frequency
        setupFrequency = try c.decodeIfPresent(Frequency.self, forKey: .setupFrequency) ?? fresh.setupFrequency
        horizonMonths = try c.decodeIfPresent(Double.self, forKey: .horizonMonths) ?? fresh.horizonMonths
        scarcity = try c.decodeIfPresent(Scarcity.self, forKey: .scarcity) ?? fresh.scarcity
        stakes = try c.decodeIfPresent(Stakes.self, forKey: .stakes) ?? fresh.stakes
        costIfItGoesWrong = try c.decodeIfPresent(Double.self, forKey: .costIfItGoesWrong)
        peopleCount = try c.decodeIfPresent(Int.self, forKey: .peopleCount) ?? fresh.peopleCount
        answeredQuestions = try c.decodeIfPresent([String].self, forKey: .answeredQuestions) ?? fresh.answeredQuestions
        recordedVerdict = try c.decodeIfPresent(String.self, forKey: .recordedVerdict)
        recordedRate = try c.decodeIfPresent(Double.self, forKey: .recordedRate)
        recommendedSide = try c.decodeIfPresent(String.self, forKey: .recommendedSide)
        chosenSide = try c.decodeIfPresent(String.self, forKey: .chosenSide)
        committedMoney = try c.decodeIfPresent(Double.self, forKey: .committedMoney)
        committedMinutes = try c.decodeIfPresent(Double.self, forKey: .committedMinutes)
        committedAt = try c.decodeIfPresent(Date.self, forKey: .committedAt)
        sleepBoundaryNote = try c.decodeIfPresent(String.self, forKey: .sleepBoundaryNote)
        review = try c.decodeIfPresent(ReviewOutcome.self, forKey: .review)
        reviewedAt = try c.decodeIfPresent(Date.self, forKey: .reviewedAt)
        isSaved = try c.decodeIfPresent(Bool.self, forKey: .isSaved) ?? fresh.isSaved
    }
}
