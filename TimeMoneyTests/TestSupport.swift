import XCTest
@testable import TimeMoney

/// The worked examples the README and design doc quote, built once.
///
/// `Profile()` is the app's default generic UK profile: £2,400 take-home, £900 rent,
/// £350 bills, £300 saved, a 37.5-hour week and a 5-hour commute. It comes out at
/// £6.86 an hour, which is the figure the README uses throughout.
enum Fixture {
    static let profile = Profile()
    static var rate: Double { RateEngine.breakdown(for: profile).personalHourlyRate }

    /// Uber against the bus: £18 and 20 minutes against £2.50 and 55.
    static func uberVsBus(uber: Double = 18, bus: Double = 2.5) -> Decision {
        var d = Decision()
        d.scenario = .fasterVsCheaper
        d.optionA.name = "Uber"
        d.optionA.money = uber
        d.optionA.minutes = 20
        d.optionB.name = "the bus"
        d.optionB.money = bus
        d.optionB.minutes = 55
        return d
    }

    /// A plain two-option decision with no scenario attached.
    static func custom(aMoney: Double, aMinutes: Double, bMoney: Double, bMinutes: Double) -> Decision {
        var d = Decision()
        d.optionA.money = aMoney
        d.optionA.minutes = aMinutes
        d.optionB.money = bMoney
        d.optionB.minutes = bMinutes
        return d
    }
}
