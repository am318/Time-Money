import Foundation

// MARK: - The file on disk

/// The parts of an Attention backup this app has any business reading.
///
/// Deliberately a subset. Attention's export carries projects, notes, deadlines
/// and an inbox; none of that is a time or money fact, and decoding it would
/// only create something to break. Every field is optional because the format is
/// additive — a missing key means "written before that existed", never zero.
struct AttentionSnapshot: Decodable {
    var formatVersion: Int?
    var exportedAt: Date?
    var days: [AttentionDay]?
    var workSpan: AttentionWorkSpan?
    var settings: AttentionSettings?
    var shortlist: [AttentionShortlistItem]?
    var holidays: [AttentionHoliday]?

    /// Attention writes ISO 8601 in UTC with no fractional seconds.
    static func decode(_ data: Data) throws -> AttentionSnapshot {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(AttentionSnapshot.self, from: data)
    }
}

/// One day's conclusions. Clock fields are minutes from midnight; minute totals
/// are whole minutes, floored.
struct AttentionDay: Decodable {
    /// Midnight **local** on the day described, serialised as UTC. Never parse the
    /// date portion of the string — for anyone east of UTC it names the day before.
    var date: Date

    var workWindowStart: Int
    var workWindowEnd: Int
    var lifeWindowStart: Int
    var lifeWindowEnd: Int
    var isWeekend: Bool
    var isHoliday: Bool

    /// Whether anyone looked at the calendar for this day.
    ///
    /// The single most dangerous field in the file. False does not mean an empty
    /// day, and — checked against Attention's own `DayDigest.build` rather than its
    /// documentation — the two `free` figures below are **still written** when it is
    /// false, reporting the whole window as though nothing were booked. Averaging
    /// them without filtering doesn't just add noise, it adds a nominal free evening
    /// for every day nobody looked at.
    var calendarKnown: Bool

    var busyMinutes: Int?
    var busyInWorkWindowMinutes: Int?
    var busyWorkRoleMinutes: Int?
    var busyLifeRoleMinutes: Int?
    var freeInWorkWindowMinutes: Int?
    /// Free evening time, counted only in stretches of twenty minutes or more.
    var freeInLifeWindowMinutes: Int?

    /// A stopwatch ran. The only work figure that may be used to conclude anything.
    var timedWorkMinutes: Int
    /// Typed in afterwards. True, but an estimate, and stamped at the moment it was
    /// typed rather than when the work happened.
    var enteredWorkMinutes: Int
    var meetingMinutes: Int
    /// Timed work that landed in an evening or at a weekend. The clearest single
    /// signal of work taking life's time back.
    var workMinutesOutsideWindow: Int
    var lifeMinutes: Int

    var workWindowMinutes: Int { max(0, workWindowEnd - workWindowStart) }
    var lifeWindowMinutes: Int { max(0, lifeWindowEnd - lifeWindowStart) }

    /// An ordinary working day: not a weekend, not a holiday. Holidays are excluded
    /// wherever a baseline is being formed, because Attention gives a holiday the
    /// whole day as its life window and a fortnight in Italy would otherwise redefine
    /// what a free evening looks like.
    var isOrdinaryWeekday: Bool { !isWeekend && !isHoliday }
}

/// What a deep hour has cost in hours of working day, and how well that is known.
///
/// Attention's `EngagedSpan`, as far as the export carries it. The multiplier this
/// app applies *is* this ratio once accepted, so the reason to read the block is
/// the scatter: without it there is no way to tell a conversion built on days that
/// agree from one built on days that vary wildly, and Attention withholds the
/// second kind rather than show a range spanning a factor of three.
struct AttentionWorkSpan: Decodable {
    var ratio: Double
    var dispersion: Double
    var measuredDays: Int

    /// Attention's own floor before it will offer an opinion. Below it the block
    /// is still written — so "still gathering" can be told from "old file" — but
    /// nothing here should be concluded from it.
    static let requiredDays = 14

    var isUsable: Bool { measuredDays >= Self.requiredDays && ratio > 0 }

    /// How far the median itself could be out. Not exported, because it follows
    /// from the two figures that are: `1.253 x dispersion / sqrt(days)`.
    var standardError: Double {
        guard measuredDays > 0 else { return 0 }
        return 1.253 * dispersion / Double(measuredDays).squareRoot()
    }

    /// The fraction of the multiplier the conversion could be out by, over a
    /// stretch containing `deepDays` days of deep work.
    ///
    /// Attention's own composition, reproduced rather than reinvented: how well a
    /// fortnight pins the centre, and how much a single week scatters around it.
    /// A week is a handful of draws from the distribution, so even a perfectly
    /// known centre does not pin *this* week.
    func spread(deepDays: Int, multiplier: Double) -> Double? {
        guard isUsable, multiplier > 0 else { return nil }
        let weekly = dispersion / Double(max(deepDays, 1)).squareRoot()
        let combined = (standardError * standardError + weekly * weekly).squareRoot()
        return 2 * combined / multiplier
    }
}

struct AttentionSettings: Decodable {
    var workdayStartMinutes: Int?
    var workdayEndMinutes: Int?
    var weekendStartMinutes: Int?
    var weekendEndMinutes: Int?
    /// Whether a human has agreed to the working hours, or they're still the
    /// shipped nine-to-five — a guess about a stranger.
    var workHoursConfirmed: Bool?
    var weekendsAreOff: Bool?
    var sleepAtMinutes: Int?
    var wakeAtMinutes: Int?
    var windDownMinutes: Int?
    var easeInMinutes: Int?
    var calendarAwarenessEnabled: Bool?

    /// Attention's strict-to-conventional multiplier.
    var conventionalMultiplierRaw: Double?
    var calibratedQuickMinutes: Int?
    var calibratedShortMinutes: Int?

    /// What this person's strictly timed deep work comes to in conventional hours.
    ///
    /// Attention's own formula, and worth stating because the name alone invites
    /// the wrong reading:
    ///
    ///     conventional = deep x r + meetings
    ///
    /// It is a unit conversion, not a claim about anybody's estimates. `r` is how
    /// many hours of working day one hour of deep work costs — measured by
    /// Attention's `EngagedSpan` from the first timer start to the last stop of each
    /// day, median over a fortnight or more of days that qualify. Meetings are timed,
    /// so they are added at face value and never scaled.
    ///
    /// It used to be a residual, `1.5 - meetings / deep`, and the difference is not
    /// cosmetic: that version modelled overhead as proportional to deep hours and had
    /// a meeting-heavy week come out with *less* unmeasured overhead, which is
    /// backwards. It also lived in `1.15...1.5`, where this one typically lands
    /// nearer two — a deep hour costing two hours of day is an ordinary day, not a
    /// bad one. Anything here that still assumed the old band would quietly cut a
    /// measured week by a third.
    ///
    /// Zero is Attention's "nothing accepted yet", not a multiplier of nought.
    var conventionalMultiplier: Double? {
        guard let raw = conventionalMultiplierRaw, raw > 0 else { return nil }
        // Attention's own supported band, which this app has no business widening or
        // narrowing. The floor is arithmetic — a deep hour cannot cost less than an
        // hour of the day it happened in — and past the ceiling the timer is catching
        // so little of the day that the multiplier is not the thing that is wrong.
        return min(AttentionAnalysis.multiplierRange.upperBound,
                   max(AttentionAnalysis.multiplierRange.lowerBound, raw))
    }

    /// Zero is Attention's "not learned yet" here too, not a bucket of no length.
    var quickMinutes: Int? {
        guard let v = calibratedQuickMinutes, v > 0 else { return nil }
        return v
    }

    var shortMinutes: Int? {
        guard let v = calibratedShortMinutes, v > 0 else { return nil }
        return v
    }

    /// How this person's estimates of small jobs actually run.
    ///
    /// From the "under an hour" bucket alone. `quick` is deliberately left out: its
    /// calibration ceiling equals its nominal ten minutes, so it can only ever move
    /// down and carries no information at all about work running long. Averaging a
    /// censored measure with an uncensored one would pull the result towards one for
    /// no reason anybody could name.
    ///
    /// Conservative by construction, in two ways worth knowing before trusting it.
    /// Attention discards samples that turned out to belong in a bigger bucket, so
    /// the hour-long job that took three hours is thrown out rather than counted as
    /// bias — this understates rather than invents. And the measurement is clamped
    /// at the bucket's own label, so the top of the range means "at least that",
    /// not "exactly that".
    var estimateMultiplier: Double? {
        guard let minutes = shortMinutes else { return nil }
        let ratio = Double(minutes) / TimeCalibration.nominalShortMinutes
        return min(TimeCalibration.multiplierRange.upperBound,
                   max(TimeCalibration.multiplierRange.lowerBound, ratio))
    }

    /// Hours between going to bed and getting up, wrapping midnight.
    var sleepHours: Double? {
        guard let sleep = sleepAtMinutes, let wake = wakeAtMinutes else { return nil }
        let minutes = sleep > wake ? (1440 - sleep) + wake : wake - sleep
        guard minutes > 0, minutes < 16 * 60 else { return nil }
        return Double(minutes) / 60
    }

    /// The moment the evening is supposed to start winding down — the line past
    /// which an hour is taken out of tomorrow.
    var windDownStartMinutes: Int? {
        guard let sleep = sleepAtMinutes else { return nil }
        return max(0, sleep - (windDownMinutes ?? 0))
    }
}

struct AttentionShortlistItem: Decodable {
    var id: UUID
    var title: String
    var scaleRaw: String
    var plannedAt: Date?
    var plannedMinutes: Int?
    var withWhom: String?
    var doneAt: Date?

    var isOutstanding: Bool { doneAt == nil }
    /// Something that would fill an evening, as opposed to a day out or a trip.
    var isEveningSized: Bool { scaleRaw == "evening" }
}

struct AttentionHoliday: Decodable {
    var id: UUID
    var title: String
    var start: Date
    /// Inclusive: away from the 1st to the 8th is eight days.
    var end: Date
}

// MARK: - What it all adds up to

/// Conclusions drawn from a snapshot, with the sample sizes that back them.
///
/// Every figure here is optional and every one carries how many days it rests on,
/// because a measured number the user can't interrogate is worth less than a guess
/// they made themselves. Nothing is reported without enough evidence behind it.
struct AttentionSummary: Equatable {

    // Provenance
    let exportedAt: Date
    let ageDays: Double
    /// Whether the export carries the derived day digest at all. Files written
    /// before it shipped have only raw records, and almost nothing here works.
    let hasDigest: Bool
    /// Whether a human confirmed the working hours. When false every window-derived
    /// figure is built on the shipped nine-to-five.
    let hoursConfirmed: Bool
    let knownDays: Int

    // Time
    /// Free evening hours in a typical week, measured against what was actually booked.
    let freeLifeHoursPerWeek: Double?
    /// Typical booked minutes inside a working day.
    let busyInWorkWindowMinutes: Double?
    /// Stated working hours a week, from the windows themselves.
    let statedWorkHoursPerWeek: Double?
    /// Timed work that escaped into evenings and weekends, per week.
    let overspillHoursPerWeek: Double?
    /// The gap between stated hours and work that reaches a project.
    let overheadMinutesPerDay: Double?
    /// The share of free working time that turns into timed work, 0 to 1.
    let realisedShare: Double?
    /// Days of evidence behind the overhead and realised-share figures.
    let timedDays: Int

    // The day's shape
    let sleepHoursPerNight: Double?
    let windDownStartMinutes: Int?

    // Learned corrections
    /// How this person's estimates of small jobs run, from the "under an hour"
    /// bucket. Applied to setup time.
    let estimateMultiplier: Double?
    /// Strictly timed deep work per conventional hour.
    let conventionalMultiplier: Double?
    /// What the recorded weeks come to as a conventional working week — the honest
    /// answer to "how many hours does work actually take", as against the contract.
    let conventionalWorkHoursPerWeek: Double?
    /// Recorded weeks behind that figure.
    let conventionalWeeks: Int
    /// How much of it is worth believing, 0 to 1.
    let conventionalConfidence: Double
    /// Why there isn't one, where there isn't.
    let conventionalRefusal: ConventionalWeek.Refusal?
    let quickMinutes: Int?
    let shortMinutes: Int?

    // The week ahead
    /// How the next seven days compare with this person's own normal.
    let weekAhead: LoadLevel?
    let weekAheadRatio: Double?
    /// Free evening minutes today and tomorrow, where the diary is known that far.
    /// The pair that answers "does this actually fit, or are you squeezing it in?"
    let freeTodayMinutes: Int?
    let freeTomorrowMinutes: Int?
    /// Whether a holiday falls inside the coming week.
    let holidayAhead: Bool

    // What free time is for
    let outstandingEveningIdeas: Int
    let bookedIdeasAhead: Int

    /// Whether the forward-looking half can be trusted. The digest reaches 21 days
    /// ahead of the export, so a fortnight-old file is mostly describing the past.
    var forwardIsFresh: Bool { ageDays <= 7 }

    /// Whether there's enough here to be worth wiring into the rate at all.
    var isUsable: Bool { hasDigest && freeLifeHoursPerWeek != nil }
}

/// The conventional working week, or why there isn't one.
///
/// A refusal is carried rather than swallowed, because "we don't know" and "you work
/// a normal week" are different answers and the screen says which.
struct ConventionalWeek: Equatable {
    var hoursPerWeek: Double? = nil
    var weeks: Int = 0
    /// How much of `hoursPerWeek` is worth believing, from 0 to 1, given how much
    /// the days behind the multiplier scattered.
    ///
    /// Separate from `refusal` because it is a different kind of answer. The
    /// refusals are categorical — the conversion cannot be done, or Attention
    /// declines to do it — and end with the typed figure deciding alone. This is
    /// a matter of degree, and ends there only gradually.
    ///
    /// One where there is no scatter to read, which is a file written before the
    /// span block existed. Discounting an old export for failing a check it
    /// cannot answer would mean upgrading this app quietly moved everybody's rate.
    var confidence: Double = 1
    /// The measured spread behind that, where there was one.
    var spread: Double? = nil
    var refusal: Refusal? = nil

    enum Refusal: Equatable {
        /// Nothing accepted in Attention yet.
        case noMultiplier
        /// Under eight recorded weeks, or forty hours of deep work.
        case notEnoughHistory
        /// Over five strict hours a day, where Attention stops converting.
        case aboveCeiling
        /// Too many days with work recorded but no timer.
        case tooMuchUntimed
        /// Deep work has been filling the day almost entirely, so converting adds
        /// nothing a multiple of one wouldn't.
        case deepFillsTheDay

        /// Said plainly, because a figure that has quietly gone missing is worse
        /// than one that says why.
        var note: String {
            switch self {
            case .noMultiplier:
                return "Attention hasn't settled on your conventional-hours multiplier yet, so your typed figure is still deciding this."
            case .notEnoughHistory:
                return "Not enough timed weeks yet to turn your deep work into a conventional week. Your typed figure is still deciding this."
            case .aboveCeiling:
                return "Over five strict hours a day, where Attention stops converting — at that level the deep figure says more than any multiple of it. Your typed figure is still deciding this."
            case .tooMuchUntimed:
                return "Too many days had work recorded but no timer running, so the total would be a floor rather than a measurement. Your typed figure is still deciding this."
            case .deepFillsTheDay:
                return "Your deep work has been filling the day almost entirely, so converting it to conventional hours would only add false precision. Your typed figure is still deciding this."
            }
        }
    }
}
