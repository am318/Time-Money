import XCTest
@testable import TimeMoney

/// Properties that have to hold for every preset situation, not just the worked
/// examples. These replace the throwaway sweeps the design doc's audit was run with.
final class ScenarioSweepTests: XCTestCase {

    private let profile = Fixture.profile
    private var rate: Double { Fixture.rate }

    /// A grid of plausible money and time entries, applied to both sides.
    private func grid(for kind: ScenarioKind) -> [Decision] {
        var out: [Decision] = []
        for (am, bm) in [(2.0, 1.0), (10.0, 4.0), (40.0, 90.0), (500.0, 120.0)] {
            for (amin, bmin) in [(5.0, 30.0), (60.0, 15.0), (240.0, 240.0)] {
                var d = Decision.make(from: kind)
                d.optionA.money = am; d.optionA.minutes = amin
                d.optionB.money = bm; d.optionB.minutes = bmin
                out.append(d)
            }
        }
        return out
    }

    /// Answers the planner's questions until it stops asking, the way the flow does.
    private func questionsAsked(for start: Decision) -> [QuestionKind] {
        var d = start
        var asked: [QuestionKind] = []
        while let next = QuestionPlanner.next(for: d, profile: profile, rate: rate) {
            asked.append(next)
            d.answeredQuestions.append(next.rawValue)
            if asked.count > 10 { break }   // a loop here would be the bug
        }
        return asked
    }

    func testThereAreFiftyOnePresetsPlusCustom() {
        XCTAssertEqual(ScenarioKind.allCases.count, 52)
        XCTAssertEqual(ScenarioKind.allCases.filter { $0 != .custom }.count, 51)
    }

    func testNoScenarioEverAsksMoreThanThreeQuestionsOrRepeatsOne() {
        for kind in ScenarioKind.allCases {
            for d in grid(for: kind) {
                let asked = questionsAsked(for: d)
                XCTAssertLessThanOrEqual(asked.count, QuestionPlanner.maximumFollowUps, "\(kind)")
                XCTAssertEqual(Set(asked).count, asked.count, "\(kind) repeated a question")
            }
        }
    }

    func testOnAverageTheAppAsksFewerThanTwoQuestions() {
        var total = 0, count = 0, none = 0
        for kind in ScenarioKind.allCases {
            for d in grid(for: kind) {
                let n = questionsAsked(for: d).count
                total += n; count += 1; if n == 0 { none += 1 }
            }
        }
        let average = Double(total) / Double(count)
        print("average follow-up questions: \(average), asking none: \(none)/\(count)")
        XCTAssertLessThan(average, 2.0)
        XCTAssertGreaterThan(none, 0, "some decisions should be settled with no questions at all")
    }

    func testEverySuggestedQuestionIsRelevantToItsScenario() {
        for kind in ScenarioKind.allCases {
            for d in grid(for: kind) {
                for q in questionsAsked(for: d) {
                    XCTAssertTrue(QuestionPlanner.isRelevant(q, to: d), "\(kind) asked \(q)")
                }
            }
        }
    }

    func testEveryTermOfARecurringDecisionGrowsWithTheHorizon() {
        // The property the "risk counted once" bug broke: on a decision that recurs,
        // every non-zero term must be larger over a longer horizon.
        for kind in ScenarioKind.allCases {
            let template = kind.template
            guard template.frequency.isRecurring else { continue }
            func rich(months: Double) -> Decision {
                var d = Decision.make(from: kind)
                d.horizonMonths = months
                d.stakes = .costsMoney
                d.costIfItGoesWrong = 100
                d.peopleCount = 2
                for keyPath in [\Decision.optionA, \Decision.optionB] {
                    d[keyPath: keyPath].money = 20
                    d[keyPath: keyPath].minutes = 30
                    d[keyPath: keyPath].feel = 2
                    d[keyPath: keyPath].health = .good
                    d[keyPath: keyPath].growth = .some
                    d[keyPath: keyPath].socialValue = .aLot
                    d[keyPath: keyPath].reliability = .sometimes
                }
                return d
            }
            let short = DecisionEngine.evaluate(rich(months: 12), profile: profile)
            let long = DecisionEngine.evaluate(rich(months: 120), profile: profile)
            for (name, s, l) in [
                ("money", short.a.money, long.a.money), ("hours", short.a.hours, long.a.hours),
                ("joy", short.a.joy, long.a.joy), ("social", short.a.social, long.a.social),
                ("health", short.a.health, long.a.health), ("growth", short.a.growth, long.a.growth),
                ("risk", short.a.riskCost, long.a.riskCost),
            ] where abs(s) > 0 {
                XCTAssertGreaterThan(abs(l), abs(s), "\(kind): \(name) did not grow with the horizon")
            }
        }
    }

    func testEveryScenarioEvaluatesToFiniteNumbers() {
        for kind in ScenarioKind.allCases {
            for d in grid(for: kind) {
                let e = DecisionEngine.evaluate(d, profile: profile)
                for v in [e.a.netCost, e.b.netCost, e.advantage, e.deltaMoney, e.deltaHours] {
                    XCTAssertTrue(v.isFinite, "\(kind)")
                }
            }
        }
    }
}
