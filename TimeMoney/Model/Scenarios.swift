import Foundation

/// Presets set labels, defaults and which fields start visible. The engine
/// underneath is identical for every one of them — which is exactly why the
/// list must never be the way in. It's a convenience, not a gate.
enum ScenarioKind: String, Codable, CaseIterable, Identifiable {

    // Comes up constantly
    case fasterVsCheaper, paySomeoneElse, deliverVsCollect, parkingCloseVsFar
    case skipTheQueue, eatOutVsCook, coffeeOutVsHome, driveOrTrain, inPersonOrRemote

    // Comes up monthly
    case switchProvider, subscription, bulkBuy, fixTheFriction, groceries

    // Is this worth paying for?
    case gymVsPayg, seasonTicket, annualVsMonthly, buyNowVsWait
    case extendedWarranty, claimVsPay, buyOrRent, payForSpeed
    case buyOutrightVsSubscribe, costPerUse, paysYouBack, buyOnceBetterForever

    // Once in a while
    case buyRepairDoWithout, returnAnItem, experience, upgradeQuality, socialEvent
    case extraWork, dropAnIncome, sellStuff, shopAround, diyVsHire, squeezeItIn, unplannedWork
    case secondHandVsNew, payForAdmin, dayOffForAdmin, babysitterTax, learnItOnce
    case sellIndividuallyVsBulk

    // Life-sized
    case commuteVsRent, fourDayWeek, salaryVsCommute, childcareVsHours
    case trainingForPay, carOwnership, takeALodger

    case custom

    var id: String { rawValue }
    var template: ScenarioTemplate { ScenarioTemplate.all[self] ?? ScenarioTemplate.fallback }
}

struct ScenarioTemplate {
    let title: String
    let symbol: String
    let blurb: String
    let family: Family
    let optionA: String
    let optionB: String
    let directionA: MoneyDirection
    let directionB: MoneyDirection
    let frequency: Frequency
    let showsSetup: Bool
    let setupLabel: String
    /// How often the setup fields recur. Rent is monthly even when the commute is daily.
    var setupFrequency: Frequency = .once
    /// How far out to count by default. A year suits most things and is badly wrong
    /// for anything bought once that then keeps going: a year is the only window in
    /// which a perpetual licence can't beat a subscription, and a coat worn weekly
    /// is 46p a wear over five years and £2.31 over one.
    var horizonMonths: Double = 12
    /// Which way the one-off money flows, where that differs from the recurring money.
    /// Course fees leave you once; the pay rise they buy arrives every month after.
    var setupDirectionA: MoneyDirection? = nil
    var setupDirectionB: MoneyDirection? = nil
    /// Whether this is a going-somewhere decision, where timetables apply.
    var involvesTravel: Bool = false
    /// Whether other people are involved, so that what it means to them is a question
    /// worth putting. A dishwasher does not have feelings about being bought.
    var involvesOthers: Bool = false
    /// Whether there's a task here you could get better at. Rules out asking whether
    /// a party teaches you anything.
    var involvesEffort: Bool = false
    /// Whether there is something here that can fail to be delivered, so that "how
    /// often does each let you down" is a question about the options rather than about
    /// life in general. A cancelled train is a real cost; a birthday party does not
    /// have a reliability record, and asking after one reads as a category error —
    /// whether a night out turns out to be any good is `joyOdds`, not this.
    var canGoWrong: Bool = false
    /// Whether this is a chance that might not come round again. Scarcity is a strong
    /// multiplier — two and a half times, at the top — and it lifts enjoyment only, so
    /// it belongs to occasions and not to errands. The nearer parking space may well
    /// be nicer; it is not a once-in-a-lifetime nicer.
    var isAnOccasion: Bool = false
    /// Whether each side is something you do a countable number of times in a period —
    /// a trip, a wear, a meal, a journey — rather than a standing arrangement charged
    /// once per period. "How many times each" multiplies an option's money and its time
    /// together, which is right for three trips to the shop and nonsense for rent: you
    /// can make three trips in a week, and you cannot have three lodgers in one spare
    /// room. `showsTimesEach` is the subset obvious enough to put on the form.
    var isCountable: Bool = false
    /// Whether each side's recurring money is charged per go or per period, where that
    /// differs between them. A membership is billed monthly however often you turn up;
    /// the pay-as-you-go swim next to it is charged per swim. Nil means per go, which
    /// is what "cost" plainly means and is right for the other forty-nine.
    var chargedEachTimeA: Bool? = nil
    var chargedEachTimeB: Bool? = nil
    /// Whether the one-off field is the number this decision is made of, rather than a
    /// side charge next to a monthly one. The purchase price, the course fees, the
    /// excess — where it is the headline figure the cursor should start there, because
    /// the field above it is charged every period and the difference is the whole bug
    /// this scenario exists to avoid.
    var startsOnTheOneOff: Bool = false

    /// Show the "how many times each" field up front, for decisions where the two
    /// sides plainly don't happen at the same rate.
    var showsTimesEach: Bool = false
    /// Show "how long each one lasts". Only for decisions that turn on durability,
    /// where the two sides wear out at different rates.
    var showsLifespan: Bool = false
    /// Show the one-off time row on its own, for decisions where hours are spent once
    /// and no money is. Finding and vetting a cleaner is real effort, and leaving it
    /// out quietly flatters every option that involves arranging something.
    var showsSetupTime: Bool = false
    /// What to call that row. Nil derives it: "One-off time", or the cadence when the
    /// one-off fields actually recur — a row labelled "One-off" and charged monthly is
    /// the same lie as a price charged twelve times.
    var setupTimeLabel: String? = nil
    let hint: String
    /// True when the natural shape is "should I, or not?" rather than "A or B?".
    var isYesNo: Bool = false
    /// Whether that second side is genuinely nothing, or a thing in its own right.
    ///
    /// "Don't" is nothing and a card asking how it would feel is noise. "Leave it and
    /// rest", "Keep the time", "Keep the place to myself" are not nothing — they are
    /// the other half of the decision, and hiding them meant the app scored resting at
    /// zero against a late gym session marked tiring, and privacy at zero on a scenario
    /// whose own hint says the feel slider decides it. The planner had always modelled
    /// a second side; only the screen left it out.
    var secondSideIsBlank: Bool = false
    /// Questions this decision cannot be answered without, asked whether or not they
    /// change the verdict.
    ///
    /// The rule everywhere else — ask only what could move the answer — is the right
    /// one, and for a warranty it fails completely: £60 of cover against £0 is decisive
    /// on price alone, nothing flips, and so the app never asks how likely the thing is
    /// to break. It settles the question by pricing the cover and ignoring the risk,
    /// which is the one calculation a warranty scenario exists to avoid. These are not
    /// nuances to be earned; they are the facts the app cannot guess and cannot do
    /// without. They still count against the three-question cap.
    var essentialQuestions: [QuestionKind] = []
    /// Whether the option labels name the choice, or merely illustrate it.
    ///
    /// "Buy it outright" names it. "e.g. Uber" is a suggestion for a field you are meant
    /// to fill in yourself, and "Option A" names nothing at all — for those two the
    /// numbers have to do the describing instead.
    var optionsAreNamed: Bool {
        !optionA.hasPrefix("e.g.") && !optionA.hasPrefix("Option ")
    }

    /// One-tap names for a scenario whose sides the app can't name for itself.
    ///
    /// "Getting somewhere" is the first tile and the one decision with no fixed pair of
    /// options — it could be any two of a dozen ways to travel — so its verdict falls
    /// back to describing the winner by its numbers. Offering the usual suspects costs
    /// one tap and turns "the cheaper one" into "the bus".
    var nameSuggestions: [String] = []

    /// Words people might actually type when searching.
    var keywords: [String] = []

    /// Grouped by **how often the decision comes up**, not by topic. Sorting by
    /// topic buries the daily ones among the once-a-decade ones; sorting by
    /// frequency puts the rare ones last by construction.
    enum Family: String, CaseIterable, Identifiable {
        case constant = "Comes up constantly"
        case monthly = "Comes up monthly"
        case worthPayingFor = "Is this worth paying for?"
        case occasional = "Once in a while"
        case timeToMoney = "Turning hours into money"
        case lifeSized = "Life-sized"

        var id: String { rawValue }

        var symbol: String {
            switch self {
            case .constant: return "sun.horizon.fill"
            case .monthly: return "calendar"
            case .worthPayingFor: return "questionmark.circle.fill"
            case .occasional: return "clock.arrow.circlepath"
            case .timeToMoney: return "hourglass.bottomhalf.filled"
            case .lifeSized: return "mountain.2.fill"
            }
        }
    }

    static let fallback = ScenarioTemplate(
        title: "Something else", symbol: "slider.horizontal.3",
        blurb: "Any two options, weighed the same way.",
        family: .occasional, optionA: "Option A", optionB: "Option B",
        directionA: .cost, directionB: .cost, frequency: .once,
        showsSetup: false, setupLabel: "One-off cost to start",
        hint: "What does each one cost you, in money and in time?")

    /// Every preset, loaded from `Resources/scenarios.json` so adding or rewording one
    /// is a data edit. Fields the file omits take the defaults declared above.
    static let all: [ScenarioKind: ScenarioTemplate] = {
        let file = DataTables.load(ScenarioFile.self, from: "scenarios")
        var table: [ScenarioKind: ScenarioTemplate] = [:]
        for (name, template) in file.scenarios {
            guard let kind = ScenarioKind(rawValue: name) else {
                assertionFailure("scenarios.json has an unknown scenario: \(name)")
                continue
            }
            table[kind] = template
        }
        table[.custom] = fallback
        return table
    }()

    private struct ScenarioFile: Decodable {
        let schemaVersion: Int
        let scenarios: [String: ScenarioTemplate]
    }

    // MARK: - Finding one without scrolling

    static func scenarios(in family: Family) -> [ScenarioKind] {
        ScenarioKind.allCases.filter { $0 != .custom && $0.template.family == family }
    }

    /// Free-text search across titles, blurbs and the words people actually type.
    /// At forty-odd presets this beats any taxonomy.
    static func search(_ query: String) -> [ScenarioKind] {
        // Word by word rather than as one string. "gym membership" and "membership
        // gym" are the same request, and matching the whole query as a run of
        // characters answers only the first — which is a coin toss on a box whose
        // own placeholder invites two words.
        let terms = SearchMatch.terms(query)
        guard !terms.isEmpty else { return [] }

        return ScenarioKind.allCases
            .filter { $0 != .custom }
            .compactMap { kind -> (ScenarioKind, Int, Int)? in
                var worst = 0
                var total = 0
                for term in terms {
                    // Every word typed has to land somewhere. A scenario that answers
                    // half the query is not the scenario.
                    guard let tier = tier(of: term, in: kind.template) else { return nil }
                    worst = max(worst, tier)
                    total += tier
                }
                return (kind, worst, total)
            }
            // Ranked by the *weakest* word's match, because that is how good the
            // answer actually is: a scenario whose title starts with one of your
            // words but that only mentions the other deep in its blurb is a worse
            // answer than one that has both in its keywords.
            .sorted { ($0.1, $0.2) < ($1.1, $1.2) }
            .map(\.0)
    }

    /// How well one typed word matches a scenario, lowest being best. Nil when it
    /// does not match at all.
    private static func tier(of term: String, in t: ScenarioTemplate) -> Int? {
        let title = SearchMatch.fold(t.title)
        let titleWords = title.split(separator: " ").map(String.init)
        let keywords = t.keywords.map(SearchMatch.fold)

        if titleWords.contains(where: { $0.hasPrefix(term) }) { return 0 }
        if keywords.contains(where: { $0.hasPrefix(term) }) { return 1 }
        if title.contains(term) { return 2 }
        if keywords.contains(where: { $0.contains(term) }) { return 3 }
        if SearchMatch.fold(t.blurb).contains(term) { return 4 }
        return nil
    }
}

// MARK: - Decoding the presets file

extension ScenarioTemplate: Decodable {
    private enum Key: String, CodingKey {
        case title, symbol, blurb, family, optionA, optionB, directionA, directionB, frequency
        case showsSetup, setupLabel, setupFrequency, horizonMonths, setupDirectionA, setupDirectionB
        case involvesTravel, involvesOthers, involvesEffort, canGoWrong, isAnOccasion, isCountable
        case chargedEachTimeA, chargedEachTimeB, startsOnTheOneOff, showsTimesEach, showsLifespan
        case showsSetupTime, setupTimeLabel, hint, isYesNo, secondSideIsBlank
        case essentialQuestions, nameSuggestions, keywords
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Key.self)
        let familyName = try c.decode(String.self, forKey: .family)
        guard let family = Family.allCases.first(where: { String(describing: $0) == familyName }) else {
            throw DecodingError.dataCorruptedError(forKey: .family, in: c,
                                                   debugDescription: "Unknown family \(familyName)")
        }
        self.init(
            title: try c.decode(String.self, forKey: .title),
            symbol: try c.decode(String.self, forKey: .symbol),
            blurb: try c.decode(String.self, forKey: .blurb),
            family: family,
            optionA: try c.decode(String.self, forKey: .optionA),
            optionB: try c.decode(String.self, forKey: .optionB),
            directionA: try c.decode(MoneyDirection.self, forKey: .directionA),
            directionB: try c.decode(MoneyDirection.self, forKey: .directionB),
            frequency: try c.decode(Frequency.self, forKey: .frequency),
            showsSetup: try c.decode(Bool.self, forKey: .showsSetup),
            setupLabel: try c.decode(String.self, forKey: .setupLabel),
            hint: try c.decode(String.self, forKey: .hint))

        setupFrequency = try c.decodeIfPresent(Frequency.self, forKey: .setupFrequency) ?? setupFrequency
        horizonMonths = try c.decodeIfPresent(Double.self, forKey: .horizonMonths) ?? horizonMonths
        setupDirectionA = try c.decodeIfPresent(MoneyDirection.self, forKey: .setupDirectionA)
        setupDirectionB = try c.decodeIfPresent(MoneyDirection.self, forKey: .setupDirectionB)
        involvesTravel = try c.decodeIfPresent(Bool.self, forKey: .involvesTravel) ?? involvesTravel
        involvesOthers = try c.decodeIfPresent(Bool.self, forKey: .involvesOthers) ?? involvesOthers
        involvesEffort = try c.decodeIfPresent(Bool.self, forKey: .involvesEffort) ?? involvesEffort
        canGoWrong = try c.decodeIfPresent(Bool.self, forKey: .canGoWrong) ?? canGoWrong
        isAnOccasion = try c.decodeIfPresent(Bool.self, forKey: .isAnOccasion) ?? isAnOccasion
        isCountable = try c.decodeIfPresent(Bool.self, forKey: .isCountable) ?? isCountable
        chargedEachTimeA = try c.decodeIfPresent(Bool.self, forKey: .chargedEachTimeA)
        chargedEachTimeB = try c.decodeIfPresent(Bool.self, forKey: .chargedEachTimeB)
        startsOnTheOneOff = try c.decodeIfPresent(Bool.self, forKey: .startsOnTheOneOff) ?? startsOnTheOneOff
        showsTimesEach = try c.decodeIfPresent(Bool.self, forKey: .showsTimesEach) ?? showsTimesEach
        showsLifespan = try c.decodeIfPresent(Bool.self, forKey: .showsLifespan) ?? showsLifespan
        showsSetupTime = try c.decodeIfPresent(Bool.self, forKey: .showsSetupTime) ?? showsSetupTime
        setupTimeLabel = try c.decodeIfPresent(String.self, forKey: .setupTimeLabel)
        isYesNo = try c.decodeIfPresent(Bool.self, forKey: .isYesNo) ?? isYesNo
        secondSideIsBlank = try c.decodeIfPresent(Bool.self, forKey: .secondSideIsBlank) ?? secondSideIsBlank
        essentialQuestions = try c.decodeIfPresent([QuestionKind].self, forKey: .essentialQuestions) ?? essentialQuestions
        nameSuggestions = try c.decodeIfPresent([String].self, forKey: .nameSuggestions) ?? nameSuggestions
        keywords = try c.decodeIfPresent([String].self, forKey: .keywords) ?? keywords
    }
}
