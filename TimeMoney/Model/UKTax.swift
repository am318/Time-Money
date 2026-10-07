import Foundation

/// A deliberately simple UK take-home estimator for the 2025/26 tax year.
///
/// It is an estimate, not a payslip. It covers the common case — one PAYE job,
/// standard tax code, salary-sacrifice pension — and ignores benefits in kind,
/// marriage allowance, unusual tax codes and everything else. The app says so
/// in the UI, and the user can always switch to entering take-home directly.
enum UKTax {

    struct Band {
        let width: Double   // width of the band in taxable income; .infinity for the top band
        let rate: Double
    }

    static let personalAllowance: Double = 12_570
    static let allowanceTaperStart: Double = 100_000

    static let englandBands: [Band] = [
        Band(width: 37_700, rate: 0.20),
        Band(width: 74_870, rate: 0.40),   // up to £125,140 gross
        Band(width: .infinity, rate: 0.45)
    ]

    static let scotlandBands: [Band] = [
        Band(width: 2_827, rate: 0.19),
        Band(width: 12_094, rate: 0.20),
        Band(width: 16_171, rate: 0.21),
        Band(width: 31_338, rate: 0.42),
        Band(width: 50_140, rate: 0.45),
        Band(width: .infinity, rate: 0.48)
    ]

    static let niPrimaryThreshold: Double = 12_570
    static let niUpperEarningsLimit: Double = 50_270
    static let niMainRate: Double = 0.08
    static let niUpperRate: Double = 0.02

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
