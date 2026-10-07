import Foundation

/// The London real Living Wage — what an hour of a London life is calculated to cost.
///
/// Not a wage floor for a job nobody is going to take. The Resolution Foundation
/// builds this figure from what a London household actually has to spend, then
/// divides by a full-time week, so it is a **cost of living calculation wearing an
/// hourly rate's clothes**. That is the only reason it belongs in these two apps: it
/// is an external, published, needs-based line that neither app can flatter itself
/// past.
///
/// It does two jobs here, and they are different jobs:
///
/// 1. **An index for pay.** A raise is only a raise if it beat the line. Both apps
///    already keep a dated record of what pay did; this is the dated record of what
///    living cost, and the comparison is the one that matters.
/// 2. **A floor under decisions.** What is left to live on should not fall below what
///    living is calculated to take — however good the reason, and however willing
///    somebody is to tolerate it.
///
/// Only the London rate is carried. The UK rate and the statutory National Living
/// Wage are deliberately absent: a table of three lines invites picking the flattering
/// one, and the question this answers is what *this* life costs, in the place it is
/// being lived.
///
/// Doubles rather than Decimals, and pence rather than pounds in the table itself.
/// The Double is because this file is copied verbatim into Time / Money and compiled
/// into two widget extensions, where `Portfolio/Support/Money.swift` does not reach —
/// the same reason `PortfolioSnapshot` is all Doubles. The pence are because
/// `Decimal(14.80)` and `Double(14.80)` are both slightly more than fourteen pounds
/// eighty, and a rate that is wrong in the twelfth decimal place is a rate that
/// disagrees with itself across a comparison.
///
/// Rates verified against the Living Wage Foundation's own announcements. The series
/// starts in 2018 rather than 2011 because 2018 is as far back as every figure in it
/// could be checked, and a benchmark seeded with a remembered number is worse than a
/// short one.
struct LivingWageRate: Hashable, Identifiable, Codable, Sendable {
    /// The calendar year of the autumn announcement. The rate is usually written
    /// "2025/26"; this is the first half of that.
    let announcedIn: Int
    /// Pence per hour. See the note above on why not pounds.
    let pence: Int
    /// When the Foundation published it. Living Wage Week is normally the first week
    /// of November, but it has moved — 2025 was announced in October — so the ones
    /// that are known are stated rather than assumed.
    let announcedMonth: Int
    let announcedDay: Int

    init(announcedIn: Int, pence: Int, announcedMonth: Int = 11, announcedDay: Int = 1) {
        self.announcedIn = announcedIn
        self.pence = pence
        self.announcedMonth = announcedMonth
        self.announcedDay = announcedDay
    }

    var id: Int { announcedIn }

    var hourly: Double { Double(pence) / 100 }

    /// "2025/26", the way the Foundation writes it.
    var label: String {
        let next = (announcedIn + 1) % 100
        return "\(announcedIn)/\(next < 10 ? "0\(next)" : "\(next)")"
    }

    /// A full-time year at this rate, before tax.
    var annualGross: Double { hourly * LivingWage.hoursPerYear }

    /// When the figure was published — and so the date from which it describes what
    /// living cost.
    ///
    /// This is the date to index pay against. The compliance deadline below is a fact
    /// about employers; this is the fact about prices, and prices are what the
    /// comparison is really about.
    func announcedOn(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(
            year: announcedIn, month: announcedMonth, day: announcedDay
        )) ?? Date.distantPast
    }

    /// The first of May after the announcement: the day accredited employers must
    /// have implemented the new rate by.
    ///
    /// Kept separate from the announcement because it answers a different question.
    /// The announcement says the line moved. This says everyone has had their six
    /// months, so if your own pay has not moved with it, that is now a finding rather
    /// than a timing difference.
    func inForceBy(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: announcedIn + 1, month: 5, day: 1))
            ?? Date.distantPast
    }
}

enum LivingWage {
    /// The week the Foundation itself divides by. Not a setting: changing it would
    /// not describe a different life, it would describe a different *calculation*,
    /// and then the number stops being the published one.
    static let hoursPerWeek: Double = 37.5
    static let weeksPerYear: Double = 52
    static let hoursPerYear: Double = hoursPerWeek * weeksPerYear

    /// London, oldest first.
    ///
    /// Sources are the Living Wage Foundation's announcements for each year. Where a
    /// row carries no explicit announcement date, Living Wage Week's usual first-week-
    /// of-November slot is assumed; the two that are known exactly say so.
    static let london: [LivingWageRate] = [
        LivingWageRate(announcedIn: 2018, pence: 1_055),
        LivingWageRate(announcedIn: 2019, pence: 1_075),
        LivingWageRate(announcedIn: 2020, pence: 1_085, announcedMonth: 11, announcedDay: 9),
        LivingWageRate(announcedIn: 2021, pence: 1_105),
        LivingWageRate(announcedIn: 2022, pence: 1_195),
        LivingWageRate(announcedIn: 2023, pence: 1_315),
        LivingWageRate(announcedIn: 2024, pence: 1_385),
        LivingWageRate(announcedIn: 2025, pence: 1_480, announcedMonth: 10, announcedDay: 22)
    ]

    /// The earliest date the table can speak about. Anything before this gets the
    /// first row, and a caller that cares should ask `covers(_:)` first.
    static var firstAnnouncement: Date { london.first?.announcedOn() ?? .distantPast }

    static func covers(_ date: Date, calendar: Calendar = .current) -> Bool {
        date >= (london.first?.announcedOn(calendar: calendar) ?? .distantFuture)
    }

    /// The rate describing what living cost on a given date.
    ///
    /// The newest announcement at or before the date. A date in the gap between two
    /// announcements gets the older one, which is correct: the line had not moved yet.
    static func london(on date: Date, calendar: Calendar = .current) -> LivingWageRate {
        london.last { $0.announcedOn(calendar: calendar) <= date } ?? london[0]
    }

    static func current(asOf date: Date = Date(), calendar: Calendar = .current) -> LivingWageRate {
        london(on: date, calendar: calendar)
    }

    /// The next announcement due after a date, where the table does not already have
    /// it. Nil once the table has caught up with the calendar, which is the state it
    /// spends most of its life in and the reason the agenda item exists.
    static func nextAnnouncementDue(after date: Date, calendar: Calendar = .current) -> Date? {
        let latest = current(asOf: date, calendar: calendar)
        guard let due = calendar.date(from: DateComponents(
            year: latest.announcedIn + 1, month: 11, day: 1
        )) else { return nil }
        return due > date ? due : nil
    }

    /// Fractional change between two rates — 0.069 for the 6.9% of 2025.
    static func change(from earlier: LivingWageRate, to later: LivingWageRate) -> Double {
        guard earlier.pence > 0 else { return 0 }
        return Double(later.pence - earlier.pence) / Double(earlier.pence)
    }

    /// Annualised change between two rates, so a comparison across four years and one
    /// across seven can be put beside each other.
    ///
    /// Worth having because the two answers differ a lot: the line has run at roughly
    /// 7.6% a year since 2021 and 5.0% since 2018, and the difference is the 2022
    /// inflation spike sitting inside the shorter window. Quoting only the shorter one
    /// would make an alarming case out of an artefact of where you started counting.
    static func annualisedChange(from earlier: LivingWageRate, to later: LivingWageRate) -> Double {
        let years = Double(later.announcedIn - earlier.announcedIn)
        guard years > 0, earlier.pence > 0 else { return 0 }
        return pow(Double(later.pence) / Double(earlier.pence), 1 / years) - 1
    }
}
