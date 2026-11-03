import Foundation

/// How far out to count.
///
/// The most decisive number in any decision with a one-off cost on one side, and
/// the one nobody thinks to set. A perpetual licence judged over twelve months is
/// judged over the only window in which it cannot win; blackout curtains look
/// marginal over a year and obvious over ten. Leaving this fixed at a year didn't
/// make the app neutral — it made it quietly, consistently pro-subscription.
enum Horizon: Int, CaseIterable, Identifiable, Equatable {
    case threeMonths = 3, sixMonths = 6, oneYear = 12, twoYears = 24
    case threeYears = 36, fiveYears = 60, tenYears = 120

    var id: Int { rawValue }
    var months: Double { Double(rawValue) }

    var label: String {
        switch self {
        case .threeMonths: return "3 months"
        case .sixMonths: return "6 months"
        case .oneYear: return "A year"
        case .twoYears: return "2 years"
        case .threeYears: return "3 years"
        case .fiveYears: return "5 years"
        case .tenYears: return "10 years"
        }
    }

    /// The listed horizon closest to an arbitrary number of months, so a decision
    /// saved before there was a picker still shows something true.
    static func nearest(to months: Double) -> Horizon {
        allCases.min(by: { abs($0.months - months) < abs($1.months - months) }) ?? .oneYear
    }
}

/// How long a thing lasts before you have to buy another.
///
/// The term that decides "buy better, keep longer", and the one no frequency can hold:
/// a coat replaced every two years and boots replaced every ten are both "sometimes".
/// It belongs to the option rather than the decision, because the whole point of these
/// is that the two sides last different lengths of time — and asking someone to convert
/// "they last about a decade" into a yearly replacement cost is asking them to do the
/// arithmetic the app exists to do.
enum Lifespan: Int, CaseIterable, Identifiable, Equatable {
    case sixMonths = 6, oneYear = 12, twoYears = 24, threeYears = 36
    case fiveYears = 60, tenYears = 120, twentyYears = 240

    var id: Int { rawValue }
    var months: Double { Double(rawValue) }

    var label: String {
        switch self {
        case .sixMonths: return "6 months"
        case .oneYear: return "A year"
        case .twoYears: return "2 years"
        case .threeYears: return "3 years"
        case .fiveYears: return "5 years"
        case .tenYears: return "10 years"
        case .twentyYears: return "20 years"
        }
    }

    /// What to call the absence of one: it never wears out, so it's bought once.
    static let foreverLabel = "It won't need replacing"

    static func nearest(to months: Double) -> Lifespan {
        allCases.min(by: { abs($0.months - months) < abs($1.months - months) }) ?? .fiveYears
    }
}

// MARK: - The terms that make an hour cost more or less than an hour

/// Not all time is lost time. An hour on a train where you read or work is not
/// the same hour as one spent driving, and pretending otherwise is the single
/// biggest error in this kind of arithmetic.
enum UsableTime: String, Codable, CaseIterable, Identifiable, Equatable {
    case none, some, most

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Not at all"
        case .some: return "Some of it"
        case .most: return "Most of it"
        }
    }

    var multiplier: Double {
        switch self {
        case .none: return 1.0
        case .some: return 0.5
        case .most: return 0.2
        }
    }

    var explanation: String {
        switch self {
        case .none: return "Every minute is gone."
        case .some: return "Half of it is yours — counted at half cost."
        case .most: return "You can read, work or rest through it — counted at a fifth."
        }
    }
}

/// Some hours cost more than an hour — a 6am start, something that leaves you
/// useless all evening. And some cost less than nothing: a walk in the middle of
/// the afternoon buys back more than the twenty minutes it takes.
enum DrainLevel: String, Codable, CaseIterable, Identifiable, Equatable {
    case restoring, fine, tiring, costsSleep

    var id: String { rawValue }

    var label: String {
        switch self {
        case .restoring: return "It'll set me up"
        case .fine: return "I'll be fine"
        case .tiring: return "It'll wipe me out"
        case .costsSleep: return "It'll cost me sleep"
        }
    }

    /// Restorative time is charged at nothing: you get back in the quality of the
    /// hours afterwards roughly what you spend on it.
    var multiplier: Double {
        switch self {
        case .restoring: return 0
        case .fine: return 1.0
        case .tiring: return 1.5
        case .costsSleep: return 2.5
        }
    }

    /// A flat cost each time, over and above the clock.
    ///
    /// This is the cost of having to decide and organise at all, and it's why the
    /// cheaper option is often worse than it looks: three shop trips a week is three
    /// lots of working out what's for dinner, not just three lots of walking there.
    /// It scales with how often you do the thing, so many-small-things pays it over
    /// and over where one-big-thing pays it once.
    var overheadMinutes: Double {
        switch self {
        case .restoring: return 0
        case .fine: return 0
        case .tiring: return 10
        case .costsSleep: return 20
        }
    }

    var explanation: String {
        switch self {
        case .restoring: return "Counted as free — a proper break pays for itself in what you get done after."
        case .fine: return "Counted at face value."
        case .tiring: return "Counted at half as much again, because it costs you the hours afterwards too."
        case .costsSleep: return "Counted at two and a half times, deliberately. Sleep isn't ordinary tiredness — you pay for it all the next day and some of the day after."
        }
    }
}

/// What this pushes out of the way.
///
/// Taking on something unplanned rarely costs only the hours it takes. An idea you
/// wanted to test turns into a day, and the day comes out of work you'd already
/// committed to — which doesn't vanish, it just arrives later and more compressed.
/// So hours that displace something already planned cost more than hours that don't.
enum Displacement: String, Codable, CaseIterable, Identifiable, Equatable {
    case nothing, somethingFlexible, somethingFixed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .nothing: return "Nothing — the time was free"
        case .somethingFlexible: return "Something that can slip"
        case .somethingFixed: return "Something with a deadline"
        }
    }

    var multiplier: Double {
        switch self {
        case .nothing: return 1.0
        case .somethingFlexible: return 1.3
        case .somethingFixed: return 1.8
        }
    }

    var explanation: String {
        switch self {
        case .nothing: return "These hours cost what they cost."
        case .somethingFlexible: return "Counted at a third more — what you've pushed back still has to happen."
        case .somethingFixed: return "Counted at nearly double, because the deadline doesn't move just because you did something else."
        }
    }
}

/// Whether skipping it tonight actually means missing it.
///
/// Most things that feel urgent aren't. The gym at eleven at night is not a choice
/// between training and not training — it's a choice between training tonight and
/// training tomorrow, and tomorrow costs you no sleep. Something you'd genuinely do
/// tomorrow is worth very little extra for being squeezed in today.
enum Deferability: String, Codable, CaseIterable, Identifiable, Equatable {
    case wouldDoTomorrow, probablyWould, nowOrNever

    var id: String { rawValue }

    var label: String {
        switch self {
        case .wouldDoTomorrow: return "Yes, I'd just do it tomorrow"
        case .probablyWould: return "Probably"
        case .nowOrNever: return "No, it's now or not at all"
        }
    }

    /// How much of the benefit is genuinely lost by not doing it right now.
    var share: Double {
        switch self {
        case .wouldDoTomorrow: return 0.2
        case .probablyWould: return 0.5
        case .nowOrNever: return 1.0
        }
    }

    var explanation: String {
        switch self {
        case .wouldDoTomorrow: return "So doing it tonight buys you almost nothing that tomorrow wouldn't."
        case .probablyWould: return "So some of the benefit survives the wait, and some doesn't."
        case .nowOrNever: return "So the whole of it rides on tonight."
        }
    }
}

/// What it's worth to the other people involved.
///
/// This is the term that stops the app giving cold answers. Your friend's fortieth
/// matters whether or not you fancy it tonight, and an evening you'd rate as mildly
/// pleasant can be the thing someone else remembers. It is not your enjoyment, and
/// folding it into your enjoyment gets both wrong.
enum SocialValue: String, Codable, CaseIterable, Identifiable, Equatable {
    case none, aBit, quiteAbit, aLot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Nobody minds either way"
        case .aBit: return "They'd be glad I came"
        case .quiteAbit: return "It'd mean something"
        case .aLot: return "They'd really want me there"
        }
    }

    /// As a fraction of what a memorable evening is worth to you.
    ///
    /// The top of the scale sits above parity, which is a judgement and an arguable
    /// one. It's there because people consistently treat "they'd really want me
    /// there" as outweighing their own preferences, and on the whole they're right
    /// to. Turn the enjoyment anchor down if you disagree.
    var share: Double {
        switch self {
        case .none: return 0
        case .aBit: return 0.3
        case .quiteAbit: return 0.75
        case .aLot: return 1.4
        }
    }

    var symbol: String {
        switch self {
        case .none: return "circle"
        case .aBit: return "person"
        case .quiteAbit: return "person.2"
        case .aLot: return "person.2.fill"
        }
    }
}

/// How likely the good version is to actually happen.
///
/// Enjoyment is usually written down as though it were certain, and for a night out
/// it plainly isn't. Saying "it could go either way" is much easier to answer
/// honestly than quietly marking it down from three to one, and it means the app
/// can say when something is a gamble rather than a calculation.
enum JoyConfidence: String, Codable, CaseIterable, Identifiable, Equatable {
    case certain, likely, couldGoEitherWay, doubtful

    var id: String { rawValue }

    var label: String {
        switch self {
        case .certain: return "It'll be good"
        case .likely: return "Probably good"
        case .couldGoEitherWay: return "Could go either way"
        case .doubtful: return "Probably a damp squib"
        }
    }

    var multiplier: Double {
        switch self {
        case .certain: return 1.0
        case .likely: return 0.8
        case .couldGoEitherWay: return 0.5
        case .doubtful: return 0.25
        }
    }

    var isGamble: Bool { self == .couldGoEitherWay || self == .doubtful }
}

/// How tied you are to somebody else's timetable.
///
/// Leaving when you like is worth real money, and it shows up as time you'd never
/// think to write down: the half hour you spend waiting for the next train, or
/// leaving the pub earlier than you wanted to because the last one is at eleven.
enum Flexibility: String, Codable, CaseIterable, Identifiable, Equatable {
    case free, someFixedTimes, tiedToTimetable

    var id: String { rawValue }

    var label: String {
        switch self {
        case .free: return "Leave when I like"
        case .someFixedTimes: return "A few set times"
        case .tiedToTimetable: return "Tied to a timetable"
        }
    }

    /// Expected slack: roughly half the gap between departures, each way.
    var slackMinutes: Double {
        switch self {
        case .free: return 0
        case .someFixedTimes: return 15
        case .tiedToTimetable: return 30
        }
    }

    var explanation: String {
        switch self {
        case .free: return "No waiting around built in."
        case .someFixedTimes: return "Adds about 15 minutes of waiting and leaving early."
        case .tiedToTimetable: return "Adds about half an hour of waiting and leaving early."
        }
    }
}

/// How confident you are that you'll use the thing as much as you think you will.
///
/// This is the honest version of "is it a staple?". A coat you'll genuinely wear
/// every week is a different purchase from the same coat bought on a whim, at the
/// same price — the difference isn't the cost, it's how many wears you'll get out
/// of it, and cost per wear is what actually decides these.
enum UsageConfidence: String, Codable, CaseIterable, Identifiable, Equatable {
    case certain, probably, maybe, unsure

    var id: String { rawValue }

    var label: String {
        switch self {
        case .certain: return "Certain — it's a staple"
        case .probably: return "Probably"
        case .maybe: return "Maybe half that"
        case .unsure: return "Honestly, who knows"
        }
    }

    /// What fraction of the uses you're imagining will actually happen.
    var multiplier: Double {
        switch self {
        case .certain: return 1.0
        case .probably: return 0.7
        case .maybe: return 0.45
        case .unsure: return 0.25
        }
    }
}

/// What you come away knowing how to do.
///
/// Distinct from enjoyment and from health because it lasts and it transfers: the
/// hours spent fixing it yourself buy a capability you keep. Front-loaded, though —
/// you learn most of it the first few times, so this is damped hard with repetition.
enum GrowthEffect: String, Codable, CaseIterable, Identifiable, Equatable {
    case none, tangent, some, lots

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Nothing new"
        case .tangent: return "Something, but it's a detour"
        case .some: return "Something I'd actually use"
        case .lots: return "Something I'm trying to get good at"
        }
    }

    /// A detour scores nothing on purpose.
    ///
    /// Learning is only worth something if it's taking you somewhere. Hours spent
    /// getting competent at a thing you don't need are hours not spent on the thing
    /// you do — and when someone else will do it for less than your time is worth,
    /// doing it yourself is being busy rather than effective.
    var points: Double {
        switch self {
        case .none, .tangent: return 0
        case .some: return 1
        case .lots: return 2
        }
    }

    var note: String? {
        self == .tangent
            ? "Counted as nothing. Learning only pays when it's taking you somewhere you're already going."
            : nil
    }

    var symbol: String {
        switch self {
        case .none: return "circle"
        case .tangent: return "arrow.triangle.branch"
        case .some: return "book"
        case .lots: return "graduationcap.fill"
        }
    }
}

/// What a choice does to your body, as distinct from what it does to your mood.
///
/// These come apart constantly: the walk you don't especially enjoy is still good
/// for you, and the third takeaway this week is enjoyable and isn't. Health also
/// behaves differently from pleasure over time — the fiftieth walk is as good for
/// you as the first, where the fiftieth treat is not.
enum HealthEffect: String, Codable, CaseIterable, Identifiable, Equatable {
    case bad, slightlyBad, neutral, slightlyGood, good

    var id: String { rawValue }

    var label: String {
        switch self {
        case .bad: return "Bad for me"
        case .slightlyBad: return "A bit bad"
        case .neutral: return "Neither"
        case .slightlyGood: return "A bit good"
        case .good: return "Good for me"
        }
    }

    var points: Double {
        switch self {
        case .bad: return -2
        case .slightlyBad: return -1
        case .neutral: return 0
        case .slightlyGood: return 1
        case .good: return 2
        }
    }

    var symbol: String {
        switch self {
        case .bad: return "arrow.down.heart"
        case .slightlyBad: return "arrow.down.right.circle"
        case .neutral: return "circle"
        case .slightlyGood: return "arrow.up.right.circle"
        case .good: return "arrow.up.heart"
        }
    }
}

/// How soon this same chance comes round again. Scarcity changes what an
/// experience is *worth* — it never changes what it costs. So this multiplies
/// enjoyment only, and leaves money and time strictly alone.
enum Scarcity: String, Codable, CaseIterable, Identifiable, Equatable {
    case often, fewTimesAYear, yearly, everyFewYears, once

    var id: String { rawValue }

    var label: String {
        switch self {
        case .often: return "All the time"
        case .fewTimesAYear: return "A few times a year"
        case .yearly: return "About once a year"
        case .everyFewYears: return "Every few years"
        case .once: return "This is the only time"
        }
    }

    var multiplier: Double {
        switch self {
        case .often: return 1.0
        case .fewTimesAYear: return 1.2
        case .yearly: return 1.4
        case .everyFewYears: return 1.8
        case .once: return 2.5
        }
    }
}

/// How often this option lets you down. A property of the option.
enum Reliability: String, Codable, CaseIterable, Identifiable, Equatable {
    case never, rarely, sometimes, often

    var id: String { rawValue }

    var label: String {
        switch self {
        case .never: return "Never"
        case .rarely: return "Rarely"
        case .sometimes: return "Sometimes"
        case .often: return "Often"
        }
    }

    var chance: Double {
        switch self {
        case .never: return 0
        case .rarely: return 0.05
        case .sometimes: return 0.2
        case .often: return 0.4
        }
    }
}

/// What it costs you when it does go wrong. A property of the situation, not the option.
enum Stakes: String, Codable, CaseIterable, Identifiable, Equatable {
    case none, annoying, costsMoney, cannotMiss

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: return "Doesn't matter"
        case .annoying: return "Annoying"
        case .costsMoney: return "It'd cost me money"
        case .cannotMiss: return "I cannot miss this"
        }
    }

    /// The cost of a bad outcome, in pounds. `referenceMoney` is what the person said
    /// it would cost them, or — where they didn't say — the largest sum in the decision.
    func cost(joyAnchor: Double, rate: Double, referenceMoney: Double) -> Double {
        switch self {
        case .none: return 0
        case .annoying: return 0.3 * joyAnchor
        case .costsMoney: return max(referenceMoney, 0.5 * joyAnchor)
        case .cannotMiss: return 3 * joyAnchor + 2 * rate
        }
    }
}

// MARK: - Options
