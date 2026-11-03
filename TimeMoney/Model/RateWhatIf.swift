import Foundation

/// "What if an hour of my time were worth £X?" Re-runs the decision at a different rate
/// without touching the profile, so the answer's dependence on the rate can be felt
/// rather than read about.
struct RateWhatIf {
    let decision: Decision
    let profile: Profile
    let calibration: TimeCalibration
    let money: MoneyCalibration
    /// The rate the real verdict used.
    let baseRate: Double
    /// The rate at which the two options tie, if there is one.
    let breakEven: Double?

    init(decision: Decision, profile: Profile, evaluation: Evaluation,
         calibration: TimeCalibration = .none, money: MoneyCalibration = .none) {
        self.decision = decision
        self.profile = profile
        self.calibration = calibration
        self.money = money
        self.baseRate = evaluation.rate
        self.breakEven = evaluation.breakEvenRate
    }

    /// The slider's span: wide enough to show both sides of the tipping point, and to
    /// move well past the user's own rate in either direction.
    var range: ClosedRange<Double> {
        let top = max(baseRate, breakEven ?? 0, 1) * 2
        return 0...max(10, top.rounded(.up))
    }

    struct Outcome: Equatable {
        let winner: Side
        /// False when the arithmetic could not separate the two at this rate.
        let isDecisive: Bool
    }

    func outcome(atRate rate: Double) -> Outcome {
        let core = DecisionEngine.core(decision, profile: profile, rate: max(0, rate),
                                       calibration: calibration, money: money)
        return Outcome(winner: core.winner, isDecisive: core.isDecisive)
    }

    /// Whether the verdict at `rate` differs from the one the user was shown.
    func flips(atRate rate: Double) -> Bool {
        outcome(atRate: rate).winner != outcome(atRate: baseRate).winner
    }
}
