import XCTest
@testable import TimeMoney

final class DecisionEngineTests: XCTestCase {

    private let profile = Fixture.profile

    private func evaluate(_ d: Decision, profile p: Profile? = nil) -> Evaluation {
        DecisionEngine.evaluate(d, profile: p ?? profile)
    }

    // MARK: - The README's headline example

    func testUberVsBusTippingPoint() throws {
        let e = evaluate(Fixture.uberVsBus())
        // Uber costs £15.50 more to save 35 minutes. Counting what that £15.50 would
        // have grown into, the hour has to be worth £27.10 for it to be worth it.
        XCTAssertEqual(try XCTUnwrap(e.breakEvenRate), 27.10, accuracy: 0.01)
        XCTAssertEqual(try XCTUnwrap(e.pricePerHourSaved), 26.57, accuracy: 0.01)
        XCTAssertEqual(e.fasterSide, .a)
    }

    func testAtSixPoundEightySixTheBusWins() {
        XCTAssertEqual(Fixture.rate, 6.86, accuracy: 0.005)
        let e = evaluate(Fixture.uberVsBus())
        XCTAssertEqual(e.winner, .b)
        XCTAssertNil(e.tiebreak, "decided by the arithmetic, not a fallback")
    }

    func testTheSameDecisionFlipsOnceTheRateIsAboveTheTippingPoint() throws {
        let tipping = try XCTUnwrap(evaluate(Fixture.uberVsBus()).breakEvenRate)

        var rich = profile
        rich.rateOverride = tipping + 20
        XCTAssertEqual(evaluate(Fixture.uberVsBus(), profile: rich).winner, .a)

        var poor = profile
        poor.rateOverride = tipping - 5
        XCTAssertEqual(evaluate(Fixture.uberVsBus(), profile: poor).winner, .b)
    }

    func testTippingPointDoesNotDependOnTheRate() throws {
        // The whole point of showing it: a wrong rate leaves it untouched.
        var other = profile
        other.rateOverride = 80
        let base = try XCTUnwrap(evaluate(Fixture.uberVsBus()).breakEvenRate)
        let moved = try XCTUnwrap(evaluate(Fixture.uberVsBus(), profile: other).breakEvenRate)
        XCTAssertEqual(base, moved, accuracy: 1e-9)
    }

    func testTheSentenceTheUserReads() throws {
        let d = Fixture.uberVsBus()
        let e = evaluate(d)
        let sentence = try XCTUnwrap(VerdictText.breakEven(for: e, decision: d))
        XCTAssertEqual(sentence, "Uber is worth it only if an hour of your time is worth more than £27.10/hr. Yours is £6.86/hr, so the bus wins.")
    }

    func testTheSentenceNeverContradictsTheVerdict() throws {
        // Just above the tipping point the answer is inside the noise band, so the
        // cheaper option wins by tiebreak. The sentence has to name that same option.
        let d = Fixture.uberVsBus()
        let tipping = try XCTUnwrap(evaluate(d).breakEvenRate)
        for offset in stride(from: -10.0, through: 40.0, by: 2.5) {
            var p = profile
            p.rateOverride = max(1, tipping + offset)
            let e = evaluate(d, profile: p)
            guard e.winner != .tooClose else { continue }
            let sentence = try XCTUnwrap(VerdictText.breakEven(for: e, decision: d))
            let expected = e.winner == .a ? "Uber" : "the bus"
            XCTAssertTrue(sentence.hasSuffix("so \(expected) wins."), "rate \(p.rateOverride!): \(sentence)")
        }
    }

    func testInsideTheNoiseBandTheSentenceSaysItBarelyMatters() throws {
        let d = Fixture.uberVsBus()
        var p = profile
        p.rateOverride = try XCTUnwrap(evaluate(d).breakEvenRate) + 5
        let e = evaluate(d, profile: p)
        XCTAssertNotNil(e.tiebreak)
        let sentence = try XCTUnwrap(VerdictText.breakEven(for: e, decision: d))
        XCTAssertEqual(sentence, "Uber is worth it only if an hour of your time is worth more than £27.10/hr. Yours is £32.10/hr, which is close enough that it barely matters, so the bus wins.")
    }

    // MARK: - Dead time versus usable time

    func testUsableTimeScalesTheTimeCost() {
        var d = Fixture.uberVsBus()
        let none = evaluate(d).b.hours
        d.optionB.usableTime = .some
        XCTAssertEqual(evaluate(d).b.hours, none * 0.5, accuracy: 1e-9)
        d.optionB.usableTime = .most
        let most = evaluate(d)
        XCTAssertEqual(most.b.hours, none * 0.2, accuracy: 1e-9)
        // "A 55-minute bus you can read on costs you 11 effective minutes."
        XCTAssertEqual(most.b.hours * 60, 11, accuracy: 1e-9)
        XCTAssertEqual(most.b.rawHours * 60, 55, accuracy: 1e-9, "clock time is still what was typed")
    }

    // MARK: - Tiebreaks

    func testWhenItBarelyMattersTheCheaperOneWins() {
        // £5 against £2.50 with 35 minutes between them lands inside the noise band.
        let e = evaluate(Fixture.uberVsBus(uber: 5))
        XCTAssertEqual(e.tiebreak, .cheaper)
        XCTAssertEqual(e.winner, .b)
    }

    func testIfMoneyIsLevelTheQuickerOneWins() {
        let d = Fixture.custom(aMoney: 5, aMinutes: 10, bMoney: 5, bMinutes: 20)
        let e = evaluate(d)
        XCTAssertEqual(e.tiebreak, .quicker)
        XCTAssertEqual(e.winner, .a)
    }

    func testOnlyIdenticalOptionsAreTooCloseToCall() {
        let e = evaluate(Fixture.custom(aMoney: 5, aMinutes: 10, bMoney: 5, bMinutes: 10))
        XCTAssertEqual(e.winner, .tooClose)
        XCTAssertEqual(e.tiebreak, .nothingInIt)
    }

    // MARK: - Recurrence and horizon

    func testDailyDecisionCountsEveryDayOfTheYear() {
        XCTAssertEqual(DecisionEngine.occurrences(frequency: .daily, horizonMonths: 12), 365.25, accuracy: 1e-9)
        XCTAssertEqual(DecisionEngine.occurrences(frequency: .once, horizonMonths: 60), 1)
        XCTAssertEqual(DecisionEngine.occurrences(frequency: .monthly, horizonMonths: 12), 12, accuracy: 1e-9)
    }

    func testRepetitionIsWhereTheMoneyHides() {
        var d = Decision()
        d.frequency = .daily
        d.horizonMonths = 12
        d.optionA.money = 2
        d.optionA.minutes = 20
        let e = evaluate(d)
        XCTAssertGreaterThan(e.a.money, 2 * 365)           // inflation on top of £730
        XCTAssertEqual(e.a.rawHours, 20 * 365.25 / 60, accuracy: 1e-9)   // 121.75 hours
    }

    func testOneOffDecisionsGetAWeeklyProjection() throws {
        let e = evaluate(Fixture.uberVsBus())
        let weekly = try XCTUnwrap(e.ifWeeklyForAYear)
        XCTAssertEqual(weekly.money, e.deltaMoney * 52, accuracy: 1e-9)
    }

    func testHorizonDecidesBuyOutrightAgainstSubscribe() {
        // £210 outright against £8.99 a month: loses over a year, wins over five.
        func decision(months: Double) -> Decision {
            var d = Decision()
            d.frequency = .monthly
            d.horizonMonths = months
            d.optionA.name = "Buy it outright"
            d.optionA.setupMoney = 210
            d.optionB.name = "Subscribe"
            d.optionB.money = 8.99
            return d
        }
        XCTAssertEqual(evaluate(decision(months: 12)).winner, .b)
        XCTAssertEqual(evaluate(decision(months: 60)).winner, .a)
    }

    func testCostPerUseDecidesPurchases() throws {
        // A £120 coat worn weekly for five years: 46p a wear.
        var d = Decision()
        d.frequency = .weekly
        d.horizonMonths = 60
        d.optionA.setupMoney = 120
        let e = evaluate(d)
        XCTAssertEqual(try XCTUnwrap(e.a.costPerUse), 0.46, accuracy: 0.005)
    }

    func testDoubtAboutUsageRaisesCostPerUseButNeverDiscountsTheBill() throws {
        var d = Decision()
        d.frequency = .weekly
        d.horizonMonths = 60
        d.optionA.setupMoney = 120
        let sure = evaluate(d).a
        d.optionA.usageConfidence = .probably
        let doubtful = evaluate(d).a
        XCTAssertEqual(doubtful.money, sure.money, "doubt must not make the bill smaller")
        XCTAssertGreaterThan(try XCTUnwrap(doubtful.costPerUse), try XCTUnwrap(sure.costPerUse))
    }

    // MARK: - Dominance and consistency

    func testAnOptionThatIsCheaperAndQuickerDominates() {
        let e = evaluate(Fixture.custom(aMoney: 3, aMinutes: 10, bMoney: 9, bMinutes: 30))
        XCTAssertTrue(e.isDominant)
        XCTAssertEqual(e.winner, .a)
    }

    func testSwappingTheOptionsSwapsTheWinner() {
        let d = Fixture.uberVsBus()
        var swapped = d
        swapped.optionA = d.optionB
        swapped.optionB = d.optionA
        XCTAssertEqual(evaluate(d).winner, .b)
        XCTAssertEqual(evaluate(swapped).winner, .a)
        XCTAssertEqual(evaluate(d).advantage, evaluate(swapped).advantage, accuracy: 1e-9)
    }
}
