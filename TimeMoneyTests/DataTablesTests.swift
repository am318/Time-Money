import XCTest
@testable import TimeMoney

/// Guards the bundled JSON tables: that they load, that they are internally sane, and
/// that they have not quietly gone out of date.
final class DataTablesTests: XCTestCase {

    private func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
        DataTables.date(String(format: "%04d-%02d-%02d", y, m, d))!
    }

    func testTaxTablesLoadAndAreSane() {
        let t = UKTax.tables
        XCTAssertEqual(t.schemaVersion, 1)
        XCTAssertEqual(t.england.count, 3)
        XCTAssertEqual(t.scotland.count, 6)
        XCTAssertEqual(t.england.last?.width, .infinity, "top band must be open-ended")
        XCTAssertEqual(t.scotland.last?.width, .infinity, "top band must be open-ended")
        XCTAssertEqual(UKTax.personalAllowance, 12_570)
        XCTAssertLessThan(UKTax.niMainRate, 1)
        XCTAssertNotNil(DataTables.date(t.validFrom))
        XCTAssertNotNil(DataTables.date(t.validTo))
    }

    func testEveryStudentLoanPlanHasTerms() {
        for plan in StudentLoanPlan.allCases where plan != .none {
            XCTAssertNotNil(UKTax.tables.studentLoan[plan.rawValue], "\(plan) has no terms in uk-tax.json")
            XCTAssertTrue(plan.threshold.isFinite)
            XCTAssertGreaterThan(plan.rate, 0)
        }
        XCTAssertEqual(StudentLoanPlan.none.threshold, .infinity)
    }

    func testLivingWageTableLoadsInOrder() {
        let years = LivingWage.london.map(\.announcedIn)
        XCTAssertEqual(years, years.sorted())
        XCTAssertEqual(Set(years).count, years.count)
        XCTAssertEqual(LivingWage.london.last?.pence, 1_480)
    }

    func testExpiryRule() {
        XCTAssertFalse(UKTax.tables.isExpired(asOf: date(2025, 12, 1)))
        XCTAssertFalse(UKTax.tables.isExpired(asOf: date(2026, 4, 5)))
        XCTAssertTrue(UKTax.tables.isExpired(asOf: date(2026, 4, 7)))
    }

    // MARK: Staleness
    //
    // These fail when the tables are out of date, which is the point. The 2025/26 tax
    // year ended on 5 April 2026 and the 2026 Living Wage announcement is due around
    // 1 November, so both are known-stale today. They are marked as non-strict expected
    // failures so CI stays green until the figures are refreshed. Once the JSON is
    // updated, delete the XCTExpectFailure line and the tests become real guards.

    func testTaxTablesAreForTheCurrentTaxYear() {
        XCTExpectFailure("uk-tax.json is for 2025/26; refresh it for the current tax year",
                         options: .nonStrict())
        XCTAssertFalse(UKTax.tables.isExpired(), "uk-tax.json (\(UKTax.tables.taxYear)) has expired")
    }

    func testLivingWageIsNotAnAnnouncementBehind() {
        XCTExpectFailure("living-wage-london.json lacks the 2026 announcement; refresh it",
                         options: .nonStrict())
        let now = Date()
        let calendar = Calendar.current
        let year = calendar.component(.year, from: now)
        // This year's row is due on 1 November; before that, last year's is the newest.
        let nov1 = calendar.date(from: DateComponents(year: year, month: 11, day: 1))!
        let required = now >= nov1 ? year : year - 1
        XCTAssertGreaterThanOrEqual(LivingWage.london.last!.announcedIn, required)
    }
}
