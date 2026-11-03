import Foundation

/// How the app's answers have held up against how things actually turned out.
///
/// Local only, and descriptive: it says how often following the answer was called the
/// right decision against how often going your own way was. It never changes the rate.
struct ReviewReport: Equatable {
    struct Tally: Equatable {
        var right = 0
        var wrong = 0
        var cantTell = 0
        var total: Int { right + wrong + cantTell }
        /// Of the reviews that took a side, the share that were right. Nil with none.
        var rightShare: Double? {
            let decided = right + wrong
            return decided > 0 ? Double(right) / Double(decided) : nil
        }
    }

    /// Decisions where you did what the app said.
    var followed = Tally()
    /// Decisions where you chose the other side.
    var overrode = Tally()
    /// Reviewed decisions with no recorded choice, so neither of the above.
    var unrecorded = Tally()

    var reviewed: Int { followed.total + overrode.total + unrecorded.total }

    /// Enough to say anything at all.
    static let minimumReviews = 5

    var hasEnough: Bool { reviewed >= ReviewReport.minimumReviews }

    static func make(from decisions: [Decision]) -> ReviewReport {
        var report = ReviewReport()
        for d in decisions {
            guard let outcome = d.review else { continue }
            func add(_ t: inout Tally) {
                switch outcome {
                case .rightCall: t.right += 1
                case .wrongCall: t.wrong += 1
                case .cantTell: t.cantTell += 1
                }
            }
            if let chosen = d.chosenSide, let recommended = d.recommendedSide,
               recommended != Side.tooClose.rawValue {
                if chosen == recommended { add(&report.followed) } else { add(&report.overrode) }
            } else {
                add(&report.unrecorded)
            }
        }
        return report
    }

    /// One plain sentence, or nil while there is too little to say.
    var summary: String? {
        guard hasEnough else { return nil }
        func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
        switch (followed.rightShare, overrode.rightShare) {
        case let (f?, o?):
            return "When you followed the answer, \(pct(f)) of your reviews were \u{201C}right call\u{201D}; when you went your own way, \(pct(o))."
        case let (f?, nil):
            return "When you followed the answer, \(pct(f)) of your reviews were \u{201C}right call\u{201D}."
        case let (nil, o?):
            return "You went your own way on these, and \(pct(o)) of the reviews were \u{201C}right call\u{201D}."
        default:
            return nil
        }
    }
}
