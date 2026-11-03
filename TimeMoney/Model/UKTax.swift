import Foundation

/// A deliberately simple UK take-home estimator. The figures come from `uk-tax.json`.
///
/// It is an estimate, not a payslip. It covers the common case — one PAYE job,
/// standard tax code, salary-sacrifice pension — and ignores benefits in kind,
/// marriage allowance, unusual tax codes and everything else. The app says so
/// in the UI, and the user can always switch to entering take-home directly.
enum UKTax {

    struct Band: Decodable {
        let width: Double   // width of the band in taxable income; .infinity for the top band
        let rate: Double

        init(width: Double, rate: Double) {
            self.width = width
            self.rate = rate
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            width = try c.decodeIfPresent(Double.self, forKey: .width) ?? .infinity
            rate = try c.decode(Double.self, forKey: .rate)
        }

        private enum CodingKeys: String, CodingKey { case width, rate }
    }

    struct StudentLoanTerms: Decodable {
        let threshold: Double
        let rate: Double
    }

    /// The year's figures, loaded from `Resources/uk-tax.json`. To roll to a new tax
    /// year, edit that file and its `taxYear`, `validFrom` and `validTo`.
    struct Tables: Decodable {
        struct NationalInsurance: Decodable {
            let primaryThreshold: Double
            let upperEarningsLimit: Double
            let mainRate: Double
            let upperRate: Double
        }

        let schemaVersion: Int
        let taxYear: String
        let validFrom: String
        let validTo: String
        let personalAllowance: Double
        let allowanceTaperStart: Double
        let england: [Band]
        let scotland: [Band]
        let nationalInsurance: NationalInsurance
        let studentLoan: [String: StudentLoanTerms]

        /// True once the tax year the tables describe has ended.
        func isExpired(asOf date: Date = Date()) -> Bool {
            guard let end = DataTables.date(validTo) else { return true }
            // validTo is the last day of the year, so it expires the day after.
            return date >= end.addingTimeInterval(24 * 60 * 60)
        }
    }

    static let tables: Tables = DataTables.load(Tables.self, from: "uk-tax")

    static var personalAllowance: Double { tables.personalAllowance }
    static var allowanceTaperStart: Double { tables.allowanceTaperStart }

    static var englandBands: [Band] { tables.england }
    static var scotlandBands: [Band] { tables.scotland }

    static var niPrimaryThreshold: Double { tables.nationalInsurance.primaryThreshold }
    static var niUpperEarningsLimit: Double { tables.nationalInsurance.upperEarningsLimit }
    static var niMainRate: Double { tables.nationalInsurance.mainRate }
    static var niUpperRate: Double { tables.nationalInsurance.upperRate }

    struct Result {
        let gross: Double
        let pension: Double
        let incomeTax: Double
        let nationalInsurance: Double
        let studentLoan: Double
        let netAnnual: Double
        var netMonthly: Double { netAnnual / 12 }

        var totalDeductions: Double { pension + incomeTax + nationalInsurance + studentLoan }
    }

    /// Personal allowance, tapered away above £100,000 at £1 for every £2 earned.
    static func allowance(for adjustedGross: Double) -> Double {
        guard adjustedGross > allowanceTaperStart else { return personalAllowance }
        let taper = (adjustedGross - allowanceTaperStart) / 2
        return max(0, personalAllowance - taper)
    }

    static func incomeTax(on adjustedGross: Double, region: TaxRegion) -> Double {
        let taxable = max(0, adjustedGross - allowance(for: adjustedGross))
        let bands = region == .scotland ? scotlandBands : englandBands
        var remaining = taxable
        var tax: Double = 0
        for band in bands {
            guard remaining > 0 else { break }
            let slice = min(remaining, band.width)
            tax += slice * band.rate
            remaining -= slice
        }
        return tax
    }

    static func nationalInsurance(on adjustedGross: Double) -> Double {
        guard adjustedGross > niPrimaryThreshold else { return 0 }
        let main = min(adjustedGross, niUpperEarningsLimit) - niPrimaryThreshold
        let upper = max(0, adjustedGross - niUpperEarningsLimit)
        return main * niMainRate + upper * niUpperRate
    }

    static func studentLoan(on adjustedGross: Double, plan: StudentLoanPlan) -> Double {
        guard plan != .none, adjustedGross > plan.threshold else { return 0 }
        return (adjustedGross - plan.threshold) * plan.rate
    }

    /// Full calculation. Pension is treated as salary sacrifice, so it comes off
    /// before tax, National Insurance and student loan are worked out.
    static func takeHome(grossAnnual: Double,
                         pensionPercent: Double,
                         plan: StudentLoanPlan,
                         region: TaxRegion) -> Result {
        let gross = max(0, grossAnnual)
        let pension = gross * max(0, min(pensionPercent, 100)) / 100
        let adjusted = gross - pension

        let tax = incomeTax(on: adjusted, region: region)
        let ni = nationalInsurance(on: adjusted)
        let loan = studentLoan(on: adjusted, plan: plan)

        return Result(gross: gross,
                      pension: pension,
                      incomeTax: tax,
                      nationalInsurance: ni,
                      studentLoan: loan,
                      netAnnual: adjusted - tax - ni - loan)
    }

    static func takeHome(for profile: Profile) -> Result {
        takeHome(grossAnnual: profile.grossAnnualSalary,
                 pensionPercent: profile.pensionPercent,
                 plan: profile.studentLoanPlan,
                 region: profile.taxRegion)
    }
}
