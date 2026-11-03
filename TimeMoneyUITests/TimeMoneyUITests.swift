import XCTest

/// End-to-end smoke tests against the real app, launched with a throwaway demo profile
/// (see `-uitest-demo` in TimeMoneyApp). They check that the app starts, that the
/// headline number matches the README's worked example, and that the main screens open.
final class TimeMoneyUITests: XCTestCase {

    private func launch() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-demo", "-AppleLocale", "en_GB", "-AppleLanguages", "(en)"]
        app.launch()
        return app
    }

    private func rateCard(in app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "label CONTAINS 'An hour of your time'")).firstMatch
    }

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testLaunchShowsTheDemoRate() {
        let app = launch()
        let card = rateCard(in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 15), "the home screen's rate card should appear")
        XCTAssertTrue(card.label.contains("6.86"), "the demo profile's rate is £6.86, got: \(card.label)")
    }

    func testTheRateCardOpensTheWorkingAndGoesBack() {
        let app = launch()
        let card = rateCard(in: app)
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        card.tap()
        let back = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(back.waitForExistence(timeout: 5), "the rate screen should have a back button")
        back.tap()
        XCTAssertTrue(rateCard(in: app).waitForExistence(timeout: 5))
    }

    func testSettingsOpens() {
        let app = launch()
        XCTAssertTrue(rateCard(in: app).waitForExistence(timeout: 15))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Reviewing decisions"].waitForExistence(timeout: 5)
                      || app.staticTexts["REVIEWING DECISIONS"].waitForExistence(timeout: 2))
    }
}
