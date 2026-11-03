import Foundation

/// One dated reading of the hourly rate.
struct RatePoint: Codable, Equatable, Identifiable {
    var date: Date
    var rate: Double
    var id: Date { date }
}

/// A short log of how the rate has moved, kept in the profile so it is backed up with
/// everything else. One reading per day at most, and only when it actually moved.
enum RateHistory {
    static let maxPoints = 400
    /// Movements smaller than this are noise, not a change in life.
    static let minimumChange = 0.01

    /// The log with `rate` recorded, or nil if nothing needs to change.
    static func recording(_ rate: Double, into points: [RatePoint], now: Date = Date(),
                          calendar: Calendar = .current) -> [RatePoint]? {
        guard rate.isFinite, rate > 0 else { return nil }
        var points = points
        if let last = points.last {
            if abs(last.rate - rate) < minimumChange { return nil }
            if calendar.isDate(last.date, inSameDayAs: now) {
                // Several edits in one day are one reading: the day's last word.
                points[points.count - 1] = RatePoint(date: now, rate: rate)
                return points
            }
        }
        points.append(RatePoint(date: now, rate: rate))
        if points.count > maxPoints { points.removeFirst(points.count - maxPoints) }
        return points
    }

    /// Change from the first reading in the window to the latest, as a fraction.
    static func change(in points: [RatePoint], since cutoff: Date) -> Double? {
        let window = points.filter { $0.date >= cutoff }
        guard let first = window.first, let last = window.last, window.count >= 2, first.rate > 0 else {
            return nil
        }
        return (last.rate - first.rate) / first.rate
    }
}

/// What the saved decisions came to, month by month.
struct MonthlyTotals: Equatable, Identifiable {
    let month: Date            // first day of the month
    let decisions: Int
    let moneyAvoided: Double
    let hoursGivenBack: Double
    var id: Date { month }
}

enum Trends {
    /// Saved decisions grouped by the month they were made, at the rate supplied, oldest
    /// first. The same arithmetic as `Store.lifetimeSaved`, so the two always agree.
    static func monthly(decisions: [Decision], profile: Profile, rate: Double,
                        calibration: TimeCalibration = .none,
                        calendar: Calendar = .current) -> [MonthlyTotals] {
        var buckets: [Date: (n: Int, money: Double, hours: Double)] = [:]
        for d in decisions where d.isSaved {
            let start = calendar.date(from: calendar.dateComponents([.year, .month], from: d.createdAt)) ?? d.createdAt
            var bucket = buckets[start] ?? (0, 0, 0)
            bucket.n += 1
            let core = DecisionEngine.core(d, profile: profile, rate: rate, calibration: calibration)
            if core.winner != .tooClose {
                let winner = core.winner == .a ? core.a : core.b
                let loser = core.winner == .a ? core.b : core.a
                bucket.money += max(0, loser.money - winner.money)
                bucket.hours += max(0, loser.rawHours - winner.rawHours)
            }
            buckets[start] = bucket
        }
        return buckets.keys.sorted().map { key in
            let b = buckets[key]!
            return MonthlyTotals(month: key, decisions: b.n, moneyAvoided: b.money, hoursGivenBack: b.hours)
        }
    }
}
