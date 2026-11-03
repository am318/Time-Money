import XCTest
@testable import TimeMoney

/// The presets live in Resources/scenarios.json; these pin its shape and a few
/// values the rest of the app depends on.
final class ScenarioPresetsTests: XCTestCase {

    func testEveryKindHasATemplate() {
        for kind in ScenarioKind.allCases {
            XCTAssertNotNil(ScenarioTemplate.all[kind], "\(kind) has no entry in scenarios.json")
        }
        XCTAssertEqual(ScenarioTemplate.all.count, ScenarioKind.allCases.count)
        XCTAssertEqual(ScenarioKind.allCases.count - 1, 51, "51 presets plus the custom one")
    }

    func testEveryPresetIsComplete() {
        for kind in ScenarioKind.allCases where kind != .custom {
            let t = kind.template
            XCTAssertFalse(t.title.isEmpty, "\(kind)")
            XCTAssertFalse(t.symbol.isEmpty, "\(kind)")
            XCTAssertFalse(t.blurb.isEmpty, "\(kind)")
            XCTAssertFalse(t.hint.isEmpty, "\(kind)")
            XCTAssertFalse(t.optionA.isEmpty, "\(kind)")
            XCTAssertFalse(t.keywords.isEmpty, "\(kind) needs search keywords")
            XCTAssertGreaterThan(t.horizonMonths, 0, "\(kind)")
        }
    }

    func testEveryPresetBelongsToAFamilyShownInTheBrowser() {
        let listed = Set(ScenarioTemplate.Family.allCases.flatMap { ScenarioTemplate.scenarios(in: $0) })
        let all = Set(ScenarioKind.allCases.filter { $0 != .custom })
        XCTAssertEqual(listed, all)
    }

    func testGettingSomewhereKeepsItsDefaults() {
        let t = ScenarioKind.fasterVsCheaper.template
        XCTAssertEqual(t.title, "Getting somewhere")
        XCTAssertEqual(t.family, .constant)
        XCTAssertEqual(t.frequency, .once)
        XCTAssertTrue(t.involvesTravel)
        XCTAssertTrue(t.canGoWrong)
        XCTAssertFalse(t.isYesNo)
        XCTAssertEqual(t.horizonMonths, 12)
        XCTAssertFalse(t.optionsAreNamed, "\"e.g. Uber\" only illustrates")
        XCTAssertTrue(t.nameSuggestions.contains("Uber"))
    }

    func testEscapedQuotesSurviveTheMove() {
        let hint = ScenarioKind.costPerUse.template.hint
        XCTAssertTrue(hint.contains("\"Counted over\""))
    }

    func testSearchStillFindsThings() {
        XCTAssertTrue(ScenarioTemplate.search("uber").contains(.fasterVsCheaper))
        XCTAssertFalse(ScenarioTemplate.search("netflix").isEmpty)
    }
}
