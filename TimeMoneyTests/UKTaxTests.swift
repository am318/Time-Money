import XCTest
@testable import TimeMoney

final class UKTaxTests: XCTestCase {

    func testBasicRateWorkedExample() {
        // £38,000 with 5% salary-sacrifice pension: £36,100 adjusted.
        // Tax: (36,100 - 12,570) × 20% = 4,706. NI: (36,100 - 12,570) × 8% = 1,882.40.
        let r = UKTax.takeHome(grossAnnual: 38_000, pensionPercent: 5, plan: .none, region: .englandWalesNI)
        XCTAssertEqual(r.pension, 1_900, accuracy: 0.001)
        XCTAssertEqual(r.incomeTax, 4_706, accuracy: 0.001)
        XCTAssertEqual(r.nationalInsurance, 1_882.40, accuracy: 0.001)
        XCTAssertEqual(r.netAnnual, 29_511.60, accuracy: 0.001)
        XCTAssertEqual(r.netMonthly, 29_511.60 / 12, accuracy: 0.001)
    }

    func testNothingPaidBelowTheAllowance() {
        let r = UKTax.takeHome(grossAnnual: 12_000, pensionPercent: 0, plan: .none, region: .englandWalesNI)
        XCTAssertEqual(r.incomeTax, 0)
        XCTAssertEqual(r.nationalInsurance, 0)
        XCTAssertEqual(r.netAnnual, 12_000)
    }

    func testHigherRateBandStartsAboveFiftyThousand() {
        // 37,700 at 20% then the rest at 40%.
        let tax = UKTax.incomeTax(on: 60_000, region: .englandWalesNI)
        let higherSlice: Double = 60_000 - 12_570 - 37_700
        let expected: Double = 37_700 * 0.20 + higherSlice * 0.40
        XCTAssertEqual(tax, expected, accuracy: 0.001)
    }

    func testNationalInsuranceDropsToTwoPercentAboveTheUpperLimit() {
        let ni = UKTax.nationalInsurance(on: 60_000)
        let main: Double = (50_270 - 12_570) * 0.08
        let upper: Double = (60_000 - 50_270) * 0.02
        XCTAssertEqual(ni, main + upper, accuracy: 0.001)
    }

    func testPersonalAllowanceTapersAboveOneHundredThousand() {
        XCTAssertEqual(UKTax.allowance(for: 100_000), 12_570)
        XCTAssertEqual(UKTax.allowance(for: 110_000), 12_570 - 5_000)
        XCTAssertEqual(UKTax.allowance(for: 125_140), 0, accuracy: 0.001)
        XCTAssertEqual(UKTax.allowance(for: 200_000), 0)
    }

    func testScottishBandsWorkedExample() {
        // 30,000 → 17,430 taxable: 2,827 at 19%, 12,094 at 20%, the remaining 2,509 at 21%.
        let scotland = UKTax.incomeTax(on: 30_000, region: .scotland)
        let starter: Double = 2_827 * 0.19
        let basic: Double = 12_094 * 0.20
        let intermediate: Double = 2_509 * 0.21
        XCTAssertEqual(scotland, starter + basic + intermediate, accuracy: 0.001)
        // The 19% starter band makes a £30,000 salary slightly cheaper in Scotland...
        XCTAssertLessThan(scotland, UKTax.incomeTax(on: 30_000, region: .englandWalesNI))
        // ...and the 42% band makes a £60,000 one dearer.
        XCTAssertGreaterThan(UKTax.incomeTax(on: 60_000, region: .scotland),
                             UKTax.incomeTax(on: 60_000, region: .englandWalesNI))
    }

    func testStudentLoanOnlyAboveItsThreshold() {
        XCTAssertEqual(UKTax.studentLoan(on: 28_000, plan: .plan2), 0)
        let plan2: Double = (40_000 - 28_470) * 0.09
        let postgrad: Double = (40_000 - 21_000) * 0.06
        XCTAssertEqual(UKTax.studentLoan(on: 40_000, plan: .plan2), plan2, accuracy: 0.001)
        XCTAssertEqual(UKTax.studentLoan(on: 40_000, plan: .postgraduate), postgrad, accuracy: 0.001)
        XCTAssertEqual(UKTax.studentLoan(on: 40_000, plan: .none), 0)
    }

    func testPensionIsTakenBeforeTaxNotAfter() {
        let without = UKTax.takeHome(grossAnnual: 50_000, pensionPercent: 0, plan: .none, region: .englandWalesNI)
        let with = UKTax.takeHome(grossAnnual: 50_000, pensionPercent: 10, plan: .none, region: .englandWalesNI)
        // Putting £5,000 aside costs less than £5,000 of take-home.
        XCTAssertGreaterThan(with.netAnnual, without.netAnnual - 5_000)
        XCTAssertEqual(with.totalDeductions + with.netAnnual, 50_000, accuracy: 0.001)
    }

    func testNegativeAndAbsurdInputsAreClamped() {
        let r = UKTax.takeHome(grossAnnual: -5, pensionPercent: 500, plan: .none, region: .englandWalesNI)
        XCTAssertEqual(r.gross, 0)
        XCTAssertEqual(r.netAnnual, 0)
    }
}
