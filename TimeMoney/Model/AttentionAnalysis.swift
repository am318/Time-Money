import Foundation

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
