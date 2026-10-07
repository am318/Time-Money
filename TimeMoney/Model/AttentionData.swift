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

// MARK: - Deriving it

enum AttentionAnalysis {

    /// Days of timed work before the overhead figure means anything. Attention's own
    /// floor, borrowed rather than invented.
    static let minimumTimedDays = 14
    /// Minutes of timed work before a day counts as timed at all. A day with ten
    /// timed minutes is a day that wasn't timed, not a day of pure overhead.
    static let timedDayFloor = 180
    /// Known days before a free-time baseline is worth quoting.
    static let minimumKnownDays = 7

    // The conventional working week, and the refusals that come with it.
    //
    // Every threshold below except the last is Attention's own, borrowed rather than
    // invented, for the reason the rest of this file borrows its floors: the app that
    // owns the method gets to say when the method stops working.

    /// How far back the conventional-hours figure looks. Attention's own baseline
    /// window for the multiplier, so the multiplier and the hours it scales are
    /// describing the same stretch of somebody's life.
    static let conventionalWindowDays = 84
    /// Attention's supported band for the multiplier.
    static let multiplierRange: ClosedRange<Double> = 1.0...4.0
    /// Below this a deep hour has cost so little of the day around it that the
    /// conversion has stopped being informative — multiplying by something
    /// indistinguishable from one returns the strict figure with false precision
    /// attached. Attention withholds here (`EngagedSpan.wholeDayRatio`) and so does
    /// this: applying a conversion the app that owns it declines to show would be
    /// asserting more than either app believes.
    static let wholeDayRatio = 1.15
    /// Past this fractional spread Attention stops converting, on the grounds that a
    /// range wide enough to be honest would be too wide to read. A rate has more
    /// reason to respect that than a screen does: a number nobody can bound is a
    /// worse thing to price an hour against than a number nobody has.
    static let widestUsefulSpread = 0.35

    /// The spread below which the measurement is used whole.
    ///
    /// Attention's own assumption about a personal figure it has no distribution
    /// for. A measured spread tighter than that is better than what the app that
    /// owns the method would have assumed in its place, so there is nothing left
    /// to discount for.
    static let fullConfidenceSpread = 0.20

    /// How much of the measured week to believe, given how much the days scattered.
    ///
    /// A ramp rather than a cliff, because the underlying quantity is continuous
    /// and nothing happens to a diary at 0.35 that does not also nearly happen at
    /// 0.34. A hard cutoff also puts a discontinuity in the rate — two exports a
    /// day apart could move an hour's price by a tenth with nothing in the diary
    /// to explain it — and makes the threshold load-bearing in a way the evidence
    /// cannot support.
    ///
    /// Both endpoints are Attention's, which is the point: this app is not
    /// entitled to an opinion about where a measurement stops being worth having,
    /// only about what to do between the two places Attention has already marked.
    /// Linear between them, because anything shaped more cleverly would be
    /// asserting something about the distribution of diaries that nobody has
    /// measured.
    static func confidence(forSpread spread: Double) -> Double {
        guard spread > fullConfidenceSpread else { return 1 }
        guard spread < widestUsefulSpread else { return 0 }
        return (widestUsefulSpread - spread) / (widestUsefulSpread - fullConfidenceSpread)
    }
    /// Distinct weeks carrying deep work, and total deep minutes, before this app
    /// will average a working week out of the digest.
    ///
    /// This app's own test, not Attention's — Attention gates the *multiplier* on
    /// fourteen measurable days, which it can do because it has the session marks.
    /// The digest carries none of those, so there is nothing here to re-check it
    /// with; this asks the separate question of whether there is enough of a diary
    /// to average hours over. Lagging is the conservative failure either way.
    static let minimumDeepWeeks = 8
    static let minimumDeepMinutes = 40 * 60
    /// Past this much strict work per timed day Attention declines to convert at all:
    /// sustaining it is qualitatively different from being present at a desk for a
    /// long time, and the strict figure says more than any multiple of it. Adopting
    /// the arithmetic without adopting the refusal would be doing sums Attention
    /// itself won't.
    static let conversionCeilingPerDay = 300
    /// The share of working days that may have gone untimed before the total stops
    /// being a measurement and starts being a floor.
    ///
    /// The one figure here that is this app's own. Attention reports its untimed days
    /// and leaves the reading to you; a rate has to decide. Only timed work counts
    /// towards the total — the same rule the rest of this file follows — so a week
    /// half of which was typed in afterwards doesn't read as a light week, it reads
    /// as a week that can't be measured, and nothing is reported.
    static let maximumUntimedShare = 0.2

    static func summarise(_ snapshot: AttentionSnapshot,
                          now: Date = Date(),
                          calendar: Calendar = .current) -> AttentionSummary {

        let exported = snapshot.exportedAt ?? now
        let age = max(0, now.timeIntervalSince(exported) / 86_400)
        let settings = snapshot.settings
        let all = snapshot.days ?? []
        let today = calendar.startOfDay(for: now)

        // Local midnight, taken from the instant. The string says 23:00 the previous
        // day for anyone in BST, so the date portion of it is not the date.
        func day(_ d: AttentionDay) -> Date { calendar.startOfDay(for: d.date) }

        let past = all.filter { day($0) < today }
        let future = all.filter { day($0) >= today }
        let knownPast = past.filter(\.calendarKnown)

        // --- free evenings -------------------------------------------------
        // Weekdays and weekends are kept apart and recombined five-and-two, because
        // a median across the lot lands between two quite different kinds of day and
        // describes neither.
        let weekdayFree = knownPast.filter(\.isOrdinaryWeekday)
            .compactMap { $0.freeInLifeWindowMinutes.map(Double.init) }
        let weekendFree = knownPast.filter { $0.isWeekend && !$0.isHoliday }
            .compactMap { $0.freeInLifeWindowMinutes.map(Double.init) }

        var freeWeekly: Double? = nil
        if knownPast.count >= minimumKnownDays,
           let weekday = median(weekdayFree), let weekend = median(weekendFree) {
            freeWeekly = (weekday * 5 + weekend * 2) / 60
        } else if knownPast.count >= minimumKnownDays,
                  let overall = median(knownPast.compactMap { $0.freeInLifeWindowMinutes.map(Double.init) }) {
            // One kind of day missing entirely — still better than nothing, just blunter.
            freeWeekly = overall * 7 / 60
        }

        let busyMedian = median(knownPast.filter(\.isOrdinaryWeekday)
            .compactMap { $0.busyInWorkWindowMinutes.map(Double.init) })

        // --- the working week ----------------------------------------------
        let weekdayWindow = median(past.filter(\.isOrdinaryWeekday).map { Double($0.workWindowMinutes) })
        let weekendWindow = median(past.filter(\.isWeekend).map { Double($0.workWindowMinutes) })
        var statedWeekly: Double? = nil
        if let weekday = weekdayWindow {
            let weekendsOff = settings?.weekendsAreOff ?? true
            let weekend = weekendsOff ? 0 : (weekendWindow ?? 0) * 2
            statedWeekly = (weekday * 5 + weekend) / 60
        }

        // Work escaping into evenings and weekends, over the last four weeks. Summed
        // rather than medianed: the question is how much there was, not how a typical
        // day went, and most days have none.
        let recent = past.filter { day($0) >= calendar.date(byAdding: .day, value: -28, to: today) ?? today }
        var overspillWeekly: Double? = nil
        if recent.count >= 14 {
            let total = recent.reduce(0) { $0 + Double($1.workMinutesOutsideWindow) }
            overspillWeekly = total / Double(recent.count) * 7 / 60
        }

        // --- what a nominal hour really yields --------------------------------
        // Only days that were genuinely timed, and only where the diary was known —
        // treating an unknown day's bookings as zero would charge them all to overhead.
        let timed = knownPast.filter {
            $0.timedWorkMinutes >= timedDayFloor && $0.busyInWorkWindowMinutes != nil
        }
        var overhead: Double? = nil
        var realised: Double? = nil
        if timed.count >= minimumTimedDays {
            overhead = median(timed.map {
                max(0, Double($0.workWindowMinutes - ($0.busyInWorkWindowMinutes ?? 0) - $0.timedWorkMinutes))
            })
            realised = median(timed.map { d -> Double in
                let available = Double(d.workWindowMinutes - (d.busyInWorkWindowMinutes ?? 0))
                guard available > 0 else { return 0 }
                return min(1, Double(d.timedWorkMinutes) / available)
            })
        }

        // --- the week ahead ---------------------------------------------------
        // Compared against this person's own weekday and weekend normals rather than
        // against a total, so a run of forward days that happens to be weekend-heavy
        // doesn't read as a quiet week.
        let nextWeek = future
            .filter { day($0) < (calendar.date(byAdding: .day, value: 7, to: today) ?? today) }
            .filter(\.calendarKnown)
        var load: LoadLevel? = nil
        var loadRatio: Double? = nil
        if nextWeek.count >= 4,
           let weekday = median(weekdayFree), let weekend = median(weekendFree),
           age <= 7 {
            var actual: Double = 0
            var expected: Double = 0
            for d in nextWeek where !d.isHoliday {
                actual += Double(d.freeInLifeWindowMinutes ?? 0)
                expected += d.isWeekend ? weekend : weekday
            }
            if expected > 0 {
                let ratio = actual / expected
                loadRatio = ratio
                load = ratio < 0.7 ? .busier : (ratio > 1.3 ? .quieter : .normal)
            }
        }

        // Only from a day the diary was actually read for — an unknown tomorrow
        // reports its whole evening as free, which is the one answer that would
        // make the app encourage squeezing something in.
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today) ?? today
        let freeToday = future
            .first { $0.calendarKnown && day($0) == today }?
            .freeInLifeWindowMinutes
        let freeTomorrow = future
            .first { $0.calendarKnown && day($0) == tomorrow }?
            .freeInLifeWindowMinutes

        let weekEnd = calendar.date(byAdding: .day, value: 7, to: today) ?? today
        let holidayAhead = (snapshot.holidays ?? []).contains { $0.start < weekEnd && $0.end >= today }
            || future.contains { day($0) < weekEnd && $0.isHoliday }

        // --- the conventional working week -----------------------------------
        let conventionalWindow = calendar.date(byAdding: .day, value: -conventionalWindowDays, to: today) ?? today
        let conventional = conventionalWeek(
            days: past.filter { day($0) >= conventionalWindow && !$0.isHoliday },
            multiplier: settings?.conventionalMultiplier,
            span: snapshot.workSpan,
            calendar: calendar)

        let shortlist = snapshot.shortlist ?? []
        let eveningIdeas = shortlist.filter { $0.isOutstanding && $0.isEveningSized }.count
        let booked = shortlist.filter { $0.isOutstanding && ($0.plannedAt ?? .distantPast) >= now }.count

        return AttentionSummary(
            exportedAt: exported,
            ageDays: age,
            hasDigest: !all.isEmpty,
            hoursConfirmed: settings?.workHoursConfirmed ?? false,
            knownDays: knownPast.count,
            freeLifeHoursPerWeek: freeWeekly,
            busyInWorkWindowMinutes: busyMedian,
            statedWorkHoursPerWeek: statedWeekly,
            overspillHoursPerWeek: overspillWeekly,
            overheadMinutesPerDay: overhead,
            realisedShare: realised,
            timedDays: timed.count,
            sleepHoursPerNight: settings?.sleepHours,
            windDownStartMinutes: settings?.windDownStartMinutes,
            estimateMultiplier: settings?.estimateMultiplier,
            conventionalMultiplier: settings?.conventionalMultiplier,
            conventionalWorkHoursPerWeek: conventional?.hoursPerWeek,
            conventionalWeeks: conventional?.weeks ?? 0,
            conventionalConfidence: conventional?.confidence ?? 0,
            conventionalRefusal: conventional?.refusal,
            quickMinutes: settings?.quickMinutes,
            shortMinutes: settings?.shortMinutes,
            weekAhead: load,
            weekAheadRatio: loadRatio,
            freeTodayMinutes: freeToday,
            freeTomorrowMinutes: freeTomorrow,
            holidayAhead: holidayAhead,
            outstandingEveningIdeas: eveningIdeas,
            bookedIdeasAhead: booked)
    }

    /// What a stretch of recorded days comes to as a conventional working week.
    ///
    /// Attention's own arithmetic — `conventional = deep x r + meetings` — applied a
    /// day at a time and averaged over the whole window, weekends and days off
    /// included, because a week is seven days whether or not all of them were worked.
    /// Holidays are the exception, filtered out by the caller: a fortnight in Italy
    /// is not a fortnight of short weeks.
    ///
    /// Only timed work counts. The digest's `enteredWorkMinutes` — work typed in
    /// afterwards — is left out entirely, in keeping with every other conclusion in
    /// this file, and the untimed days it marks are instead the signal that the
    /// measurement can't be trusted at all.
    ///
    /// - Returns: the figure with the evidence behind it, or the reason there isn't one.
    static func conventionalWeek(days: [AttentionDay],
                                 multiplier: Double?,
                                 span: AttentionWorkSpan?,
                                 calendar: Calendar = .current) -> ConventionalWeek? {
        guard !days.isEmpty else { return nil }
        // Nothing accepted in Attention means no multiplier, and the 1.5 anchor is
        // deliberately not borrowed: inventing half again of overhead for somebody
        // who has never confirmed it is exactly the flattery this link exists to stop.
        guard let multiplier else { return ConventionalWeek(refusal: .noMultiplier) }
        guard multiplier >= wholeDayRatio else { return ConventionalWeek(refusal: .deepFillsTheDay) }

        var totalMinutes: Double = 0
        var deepMinutes = 0
        var deepDays = 0
        var untimedWorkDays = 0
        var workedDays = 0
        var weeks: Set<Date> = []

        for d in days {
            let timed = max(0, d.timedWorkMinutes)
            // Timed meetings can't be separated from entered ones — the digest's
            // `meetingMinutes` counts both — so they are bounded by the timed total.
            // Exact whenever no meeting was typed in, which is the ordinary case.
            let meetings = min(max(0, d.meetingMinutes), timed)
            let deep = timed - meetings

            if timed > 0 || d.enteredWorkMinutes > 0 { workedDays += 1 }
            if timed == 0 && d.enteredWorkMinutes > 0 { untimedWorkDays += 1 }
            guard timed > 0 else { continue }

            totalMinutes += Double(deep) * multiplier + Double(meetings)
            if deep > 0 {
                deepMinutes += deep
                deepDays += 1
                if let week = calendar.dateInterval(of: .weekOfYear, for: d.date)?.start {
                    weeks.insert(week)
                }
            }
        }

        // Too much of the record typed in after the fact. Since entered work is left
        // out of the total, reporting anyway would understate the week — and an
        // understated working week quietly *raises* the rate, which is the one
        // direction a measurement failure must never push.
        if workedDays > 0,
           Double(untimedWorkDays) / Double(workedDays) > maximumUntimedShare {
            return ConventionalWeek(refusal: .tooMuchUntimed)
        }
        guard weeks.count >= minimumDeepWeeks, deepMinutes >= minimumDeepMinutes else {
            return ConventionalWeek(refusal: .notEnoughHistory)
        }
        guard deepDays > 0, deepMinutes / deepDays < conversionCeilingPerDay else {
            return ConventionalWeek(refusal: .aboveCeiling)
        }
        // Weighed last, because it is the only judgement here that needs the sample
        // it is judging. A file written before the span block existed carries no
        // scatter and is believed whole on the older evidence, rather than
        // discounted by a check it cannot answer.
        let spread = span?.spread(deepDays: deepDays, multiplier: multiplier)
        let hours = totalMinutes / Double(days.count) * 7 / 60
        return ConventionalWeek(hoursPerWeek: hours,
                                weeks: weeks.count,
                                confidence: spread.map(confidence(forSpread:)) ?? 1,
                                spread: spread,
                                refusal: nil)
    }

    /// A median, not a mean. One day spent entirely in a corridor should not redefine
    /// what an ordinary day costs.
    static func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count % 2 == 1
            ? sorted[middle]
            : (sorted[middle - 1] + sorted[middle]) / 2
    }
}

// MARK: - Corrections the engine can apply

/// Adjustments to the time side of a decision, learned from this person's own records
/// rather than assumed about people in general.
struct TimeCalibration: Equatable {

    /// How their estimates of their own effort run.
    ///
    /// Applied to setup time only — the getting ready, the going to fetch it, the
    /// working out where the thing is — and deliberately not to the main duration,
    /// which is as often a looked-up fact as a guess. Correcting a train timetable by
    /// twenty per cent would be inventing a delay.
    ///
    /// Note this is not neutral across a comparison even though it scales both sides:
    /// it scales the *difference* too, which is what the verdict turns on.
    var estimateMultiplier: Double = 1

    /// What Attention's "under an hour" bucket is worth before anything is learned.
    static let nominalShortMinutes: Double = 40

    /// The range a learned estimate correction may take.
    ///
    /// The upper bound is not a taste: Attention clamps that bucket at its own label
    /// of sixty minutes, so sixty over a nominal forty is the most it can ever
    /// report. Stated once, here, rather than as a pair of literals at each end.
    static let multiplierRange: ClosedRange<Double> = 0.5...1.5

    /// The least an hour may be discounted to, measured.
    ///
    /// `usableTime` lets an hour on a train count for a fifth of a lost hour. If only
    /// seventy per cent of this person's free working time has ever turned into timed
    /// work, a fifth is optimistic about the other seventy minutes of the journey.
    /// Never allowed past `.some`, because the measurement is about focused work and
    /// some usable time is reading a novel.
    var usableFloor: Double = 0

    static let none = TimeCalibration()

    init(estimateMultiplier: Double = 1, usableFloor: Double = 0) {
        self.estimateMultiplier = min(Self.multiplierRange.upperBound,
                                      max(Self.multiplierRange.lowerBound, estimateMultiplier))
        self.usableFloor = max(0, min(0.4, usableFloor))
    }

    /// Nothing is taken from a summary the user hasn't linked, and nothing is taken
    /// from a figure that isn't there. Both halves fail safe to no correction at all.
    init(summary: AttentionSummary?) {
        guard let summary else { self = .none; return }
        let floor = summary.realisedShare.map { 1 - $0 } ?? 0
        self.init(estimateMultiplier: summary.estimateMultiplier ?? 1,
                  usableFloor: floor)
    }

    var isActive: Bool { estimateMultiplier != 1 || usableFloor > 0 }
}

// MARK: - Things the records can answer so the app doesn't have to ask

enum AttentionAutomation {

    /// The longest an option can run and still sensibly be assumed to be happening
    /// this evening. Past this it's a project, not a plan for tonight.
    static let sameEveningHours: Double = 8

    /// Whether doing this now would run past the point the evening is meant to start
    /// winding down.
    ///
    /// The assumption is that a decision is about now, which is true of nearly every
    /// decision anyone opens this app for. Where it isn't, the answer is one tap away.
    static func crossesWindDown(durationMinutes: Double,
                                windDownStartMinutes: Int?,
                                now: Date = Date(),
                                calendar: Calendar = .current) -> Bool {
        guard let line = windDownStartMinutes, line > 0 else { return false }
        guard durationMinutes > 0, durationMinutes <= sameEveningHours * 60 else { return false }
        let components = calendar.dateComponents([.hour, .minute], from: now)
        let minutesNow = Double((components.hour ?? 0) * 60 + (components.minute ?? 0))
        // Already past the line and about to start something: that is the clearest
        // case of all, not an edge one.
        return minutesNow + durationMinutes > Double(line)
    }

    /// The wind-down line as a clock time, for saying so out loud.
    static func clockLabel(minutesFromMidnight: Int) -> String {
        let hour = (minutesFromMidnight / 60) % 24
        let minute = minutesFromMidnight % 60
        return String(format: "%d:%02d", hour, minute)
    }
}

extension AttentionAutomation {

    /// Applies the wind-down line to a decision, so the app can stop asking a question
    /// it already knows the answer to.
    ///
    /// Only ever moves an option from "I'll be fine" to "it'll cost me sleep". A user
    /// who has said something is restorative, or has already answered the question,
    /// is not overruled by a clock — the point is to skip an obvious question, not to
    /// win an argument.
    ///
    /// - Returns: what changed, in words, or nil if nothing did.
    @discardableResult
    static func applySleepBoundary(to decision: inout Decision,
                                   summary: AttentionSummary?,
                                   enabled: Bool,
                                   now: Date = Date(),
                                   calendar: Calendar = .current) -> String? {
        guard enabled, let summary, let line = summary.windDownStartMinutes else { return nil }
        guard !decision.answeredQuestions.contains(QuestionKind.drain.rawValue) else { return nil }

        func crosses(_ option: DecisionOption) -> Bool {
            option.drain == .fine
                && crossesWindDown(durationMinutes: option.setupMinutes + option.minutes,
                                   windDownStartMinutes: line, now: now, calendar: calendar)
        }

        let a = crosses(decision.optionA)
        let b = crosses(decision.optionB)
        guard a || b else { return nil }

        if a { decision.optionA.drain = .costsSleep }
        if b { decision.optionB.drain = .costsSleep }
        // Marked answered so the flow doesn't then ask what it has just concluded.
        decision.answeredQuestions.append(QuestionKind.drain.rawValue)

        let clock = clockLabel(minutesFromMidnight: line)
        let note: String
        switch (a, b) {
        case (true, true):
            note = "Both of these would run past \(clock), when you wind down. Counted as costing sleep."
        case (true, false):
            note = "\(name(decision.optionA, fallback: "The first")) would run past \(clock), when you wind down. Counted as costing sleep."
        default:
            note = "\(name(decision.optionB, fallback: "The second")) would run past \(clock), when you wind down. Counted as costing sleep."
        }
        decision.sleepBoundaryNote = note
        return note
    }

    /// Puts it back the way it was, and lets the question be asked properly.
    static func undoSleepBoundary(on decision: inout Decision) {
        if decision.optionA.drain == .costsSleep { decision.optionA.drain = .fine }
        if decision.optionB.drain == .costsSleep { decision.optionB.drain = .fine }
        decision.answeredQuestions.removeAll { $0 == QuestionKind.drain.rawValue }
        decision.sleepBoundaryNote = nil
    }

    private static func name(_ option: DecisionOption, fallback: String) -> String {
        option.name.isEmpty ? fallback : option.name
    }
}

// MARK: - Things worth saying out loud

enum AttentionNotes {

    /// Whether something fits the evening it's meant to happen in.
    ///
    /// The principle the app is trying to hold onto: don't squeeze in tonight what can
    /// be done tomorrow. Stated as a fact about the diary rather than as advice, and
    /// only ever when the diary was genuinely read — an unknown evening reports itself
    /// as entirely free, which is the one answer that would push the wrong way.
    static func fit(minutes: Double, summary: AttentionSummary?, enabled: Bool) -> String? {
        guard enabled, minutes > 0,
              let summary, let tonight = summary.freeTodayMinutes else { return nil }
        // A quarter of an hour of slack, so a plan that just about fits isn't nagged at.
        guard minutes > Double(tonight) + 15 else { return nil }

        let needed = Fmt.minutes(minutes)
        let free = Fmt.minutes(Double(tonight))
        if let tomorrow = summary.freeTomorrowMinutes, Double(tomorrow) >= minutes {
            return "This needs \(needed) and tonight has \(free) free. Tomorrow evening has \(Fmt.minutes(Double(tomorrow))) — it doesn't have to be tonight."
        }
        return "This needs \(needed) and tonight has \(free) free before you wind down."
    }

    /// What the time being bought back is actually for.
    ///
    /// The leisure rate quietly assumes freed time gets used well. Where there's
    /// nothing waiting for it, that assumption is worth saying out loud rather than
    /// silently discounting — the user knows things the shortlist doesn't.
    static func freedTime(for evaluation: Evaluation, summary: AttentionSummary?, enabled: Bool) -> String? {
        guard enabled, let summary, summary.hasDigest else { return nil }
        guard evaluation.winner == .a || evaluation.winner == .b else { return nil }

        let winner = evaluation.winner == .a ? evaluation.a : evaluation.b
        let loser = evaluation.winner == .a ? evaluation.b : evaluation.a
        let hoursSaved = loser.rawHours - winner.rawHours
        let moneySpent = winner.money - loser.money
        // Only where time is genuinely being bought, and enough of it to plan around.
        guard hoursSaved >= 1, moneySpent > 0 else { return nil }

        if summary.outstandingEveningIdeas > 0 {
            let ideas = summary.outstandingEveningIdeas
            return ideas == 1
                ? "One thing on your shortlist is waiting for the \(Fmt.duration(hours: hoursSaved)) this buys back."
                : "\(ideas) things on your shortlist are waiting for the \(Fmt.duration(hours: hoursSaved)) this buys back."
        }
        return "Nothing on your shortlist is waiting for the \(Fmt.duration(hours: hoursSaved)) this buys back. Worth knowing before paying for it."
    }
}
