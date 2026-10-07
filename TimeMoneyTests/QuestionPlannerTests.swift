import XCTest
@testable import TimeMoney

final class QuestionPlannerTests: XCTestCase {

    private let profile = Fixture.profile
    private var rate: Double { Fixture.rate }

    func testNothingEnteredMeansNothingAsked() {
        let d = Decision()
        XCTAssertTrue(QuestionPlanner.rank(for: d, profile: profile, rate: rate).isEmpty)
        XCTAssertNil(QuestionPlanner.next(for: d, profile: profile, rate: rate))
    }

    func testNearlyIdenticalOptionsAreAnsweredWithoutAskingAnything() {
        // £2.50 and £2.60 for the same ten minutes: not worth a single question.
        let d = Fixture.custom(aMoney: 2.50, aMinutes: 10, bMoney: 2.60, bMinutes: 10)
        XCTAssertTrue(QuestionPlanner.isEffectivelyIdentical(d, profile: profile, rate: rate))
        XCTAssertTrue(QuestionPlanner.rank(for: d, profile: profile, rate: rate).isEmpty)
    }

    func testSimilarIsNotTheSameAsBalanced() {
        // Cheap-and-slow against dear-and-quick is a real trade-off, however level
        // the verdict, so it is not skipped as "identical".
        let d = Fixture.uberVsBus(uber: 5)
        XCTAssertFalse(QuestionPlanner.isEffectivelyIdentical(d, profile: profile, rate: rate))
    }

    func testALopsidedDecisionAsksNothing() {
        // £100 against £20 for ten minutes less: no answer to any question changes it.
        let d = Fixture.custom(aMoney: 100, aMinutes: 0, bMoney: 20, bMinutes: 10)
        XCTAssertNil(QuestionPlanner.next(for: d, profile: profile, rate: rate))
        XCTAssertTrue(QuestionPlanner.rank(for: d, profile: profile, rate: rate).allSatisfy { !$0.flips })
    }

    func testACloseDecisionAsksHowItWouldFeel() {
        let d = Fixture.custom(aMoney: 12, aMinutes: 10, bMoney: 10, bMinutes: 10)
        XCTAssertEqual(QuestionPlanner.next(for: d, profile: profile, rate: rate), .feel)
    }

    func testQuestionsThatCanChangeTheAnswerComeFirst() {
        let d = Fixture.custom(aMoney: 12, aMinutes: 30, bMoney: 10, bMinutes: 10)
        let ranked = QuestionPlanner.rank(for: d, profile: profile, rate: rate)
        let firstNonFlip = ranked.firstIndex { !$0.flips } ?? ranked.count
        XCTAssertTrue(ranked[firstNonFlip...].allSatisfy { !$0.flips }, "flipping questions must precede the rest")
        XCTAssertFalse(ranked.isEmpty)
        XCTAssertTrue(ranked[0].flips)
    }

    func testAnAnsweredQuestionIsNeverAskedAgain() {
        var d = Fixture.custom(aMoney: 12, aMinutes: 10, bMoney: 10, bMinutes: 10)
        d.answeredQuestions = [QuestionKind.feel.rawValue]
        XCTAssertFalse(QuestionPlanner.rank(for: d, profile: profile, rate: rate).contains { $0.kind == .feel })
        XCTAssertNotEqual(QuestionPlanner.next(for: d, profile: profile, rate: rate), .feel)
    }

    func testAtMostThreeFollowUps() {
        XCTAssertEqual(QuestionPlanner.maximumFollowUps, 3)
        var d = Fixture.custom(aMoney: 12, aMinutes: 10, bMoney: 10, bMinutes: 10)
        d.answeredQuestions = ["feel", "social", "health"]
        XCTAssertNil(QuestionPlanner.next(for: d, profile: profile, rate: rate))
    }

    func testUsableTimeIsOnlyAskedAboutWhenThereIsTimeToUse() {
        XCTAssertFalse(QuestionPlanner.isRelevant(.usableTime,
            to: Fixture.custom(aMoney: 2, aMinutes: 0, bMoney: 3, bMinutes: 0)))
        XCTAssertTrue(QuestionPlanner.isRelevant(.usableTime,
            to: Fixture.custom(aMoney: 2, aMinutes: 30, bMoney: 3, bMinutes: 60)))
    }

    func testRelativeMarginIsSignedTowardsOptionA() {
        let aWins = DecisionEngine.core(Fixture.custom(aMoney: 3, aMinutes: 10, bMoney: 30, bMinutes: 10),
                                        profile: profile, rate: rate)
        let bWins = DecisionEngine.core(Fixture.custom(aMoney: 30, aMinutes: 10, bMoney: 3, bMinutes: 10),
                                        profile: profile, rate: rate)
        XCTAssertGreaterThan(QuestionPlanner.relativeMargin(aWins), 0)
        XCTAssertLessThan(QuestionPlanner.relativeMargin(bWins), 0)
    }
}
