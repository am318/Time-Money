import SwiftUI

/// Everything behind the answer. Reached only by tapping "Why?", and never
/// shown unasked.
struct VerdictView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    let decision: Decision
    let evaluation: Evaluation
    /// What the time being bought back is actually for, when the records know.
    var freedTimeNote: String? = nil

    private var nameA: String { VerdictText.displayName(for: .a, decision: decision, evaluation: evaluation) }
    private var nameB: String { VerdictText.displayName(for: .b, decision: decision, evaluation: evaluation) }

    /// What the winning option does to the London Living Wage line.
    ///
    /// Only recurring money is tested. A one-off is a month you chose; the thing that
    /// changes a standard of living without anybody deciding to is the commitment that
    /// turns up every month. Testing one-offs against the line would flag every sofa
    /// and teach people to ignore the warning that exists to catch subscriptions.
    ///
    /// Silent when the option brings money in rather than taking it out, and silent
    /// when Portfolio is not publishing a line — this app has no business inventing
    /// the number itself.
    private var livingWageNote: String? {
        guard let line = store.moneyCalibration.livingWage else { return nil }
        let option = evaluation.winner == .b ? decision.optionB : decision.optionA
        guard option.direction == .cost else { return nil }
        guard let monthly = LivingWageLine.monthlyEquivalent(
            of: option.moneyPerPeriod, frequency: decision.frequency
        ) else { return nil }
        return line.crossing(monthlyCost: monthly).note
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    headline
                    if evaluation.payback.isWorthShowing { paybackCard }
                    if evaluation.breakEvenRate != nil { breakEvenCard }
                    if let nudge = VerdictText.feelNudge(for: evaluation, decision: decision) {
                        noteCard(nudge, symbol: "heart.circle.fill", tint: .pink)
                    }
                    if let freedTimeNote {
                        noteCard(freedTimeNote, symbol: "list.bullet.rectangle", tint: .teal)
                    }
                    if let sleep = decision.sleepBoundaryNote {
                        noteCard(sleep, symbol: "moon.zzz.fill", tint: .indigo)
                    }
                    if let crossing = livingWageNote {
                        noteCard(crossing, symbol: "figure.stand", tint: .orange)
                    }
                    tradeCard
                    consequencesCard
                    if !evaluation.sensitivities.isEmpty { sensitivityCard }
                    if let projection = evaluation.ifWeeklyForAYear { projectionCard(projection) }
                    totalsCard
                    footnote
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("The working")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } }
            }
        }
    }

    /// A five-year daily decision can come out ahead by several thousand pounds, and
    /// the figure is correct — but a number that large stops meaning anything, and an
    /// answer nobody believes is an answer nobody acts on. Where the total spans many
    /// occurrences, it's restated as the size of each one.
    private var perOccurrence: String {
        let n = evaluation.occurrences
        guard n >= 12, evaluation.advantage > 0 else { return "" }
        let each = evaluation.advantage / n
        guard each >= 0.01 else { return "" }
        return " — about \(Fmt.money(each)) each time, \(Int(n.rounded())) times over"
    }

    private var headline: some View {
        Card(tint: evaluation.winner == .tooClose ? .clear : .green) {
            VStack(alignment: .leading, spacing: 8) {
                if let winner = VerdictText.winnerName(for: evaluation, decision: decision) {
                    Text(winner)
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    switch evaluation.tiebreak {
                    case .cheaper:
                        Text("The numbers can't separate these — under \(Fmt.money(evaluation.advantage)) between them once everything is counted. So it comes down to the plainest fact available: this one \(VerdictText.moneyEdge(for: evaluation)). A sum of money is a fact; a duration is an estimate, and estimates are what tend to be wrong.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    case .quicker:
                        Text("The numbers can't separate these, and nor can the money. So it comes down to time: this one takes \(Fmt.duration(hours: abs(evaluation.deltaRawHours))) less.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    case .nothingInIt, nil:
                        Text(evaluation.isDominant
                             ? "Better on every count. Nothing to agonise over."
                             : "Ahead by \(Fmt.money(evaluation.advantage))\(perOccurrence) once your time and how it feels are priced in.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else {
                    Text("Genuinely either")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("Same money, same time, same everything. There's no answer to find here — pick one and stop thinking about it.")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// For anything bought once that keeps giving, this is the real answer.
    private var paybackCard: some View {
        let rate = evaluation.rate
        // Mirrors the engine: money that arrives up front isn't an investment.
        let costA = decision.optionA.effectiveSetupDirection.sign * decision.optionA.setupMoney
            + decision.optionA.setupMinutes / 60 * rate
        let costB = decision.optionB.effectiveSetupDirection.sign * decision.optionB.setupMoney
            + decision.optionB.setupMinutes / 60 * rate
        let invested = costA > costB ? nameA : nameB

        return Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("When it pays for itself", systemImage: "hourglass")
                    .font(.subheadline.weight(.semibold))

                switch evaluation.payback {
                case .immediate:
                    Text("Straight away")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("\(Fmt.sentenceStart(invested)) is ahead from the first month. There's nothing to pay back.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                case .months(let months):
                    Text(months < 12
                         ? "\(Int(months.rounded())) months"
                         : String(format: "%.1f years", months / 12))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                    Text("\(Fmt.sentenceStart(invested)) is behind until then, and ahead every day after. So the real question is how long you'll keep it.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                case .never:
                    Text("It doesn't")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text("\(Fmt.sentenceStart(invested)) never catches up, even given fifty years of it.")
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                case .notApplicable:
                    EmptyView()
                }
            }
        }
    }

    private var breakEvenCard: some View {
        let breakEven = evaluation.breakEvenRate ?? 0
        return Card {
            VStack(alignment: .leading, spacing: 14) {
                Label("The tipping point", systemImage: "arrow.left.and.right")
                    .font(.subheadline.weight(.semibold))

                if let sentence = VerdictText.breakEven(for: evaluation, decision: decision) {
                    Text(sentence).font(.body).fixedSize(horizontal: false, vertical: true)
                }

                if breakEven > 0 {
                    BreakEvenScale(yourRate: evaluation.rate, breakEven: breakEven)
                    if let price = evaluation.pricePerHourSaved {
                        Text("Put another way: you'd be paying \(Fmt.money(price)) for every hour it saves you.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var tradeCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("What you're trading", systemImage: "arrow.triangle.swap")
                    .font(.subheadline.weight(.semibold))

                let dm = evaluation.deltaMoney
                let dh = evaluation.deltaHours
                let dRaw = evaluation.deltaRawHours
                let dj = evaluation.deltaJoy
                let dr = evaluation.deltaRisk

                if abs(dm) > 0.01 {
                    StatRow(label: "\(Fmt.sentenceStart(dm > 0 ? nameA : nameB)) costs more",
                            value: Fmt.money(abs(dm)),
                            detail: evaluation.occurrences > 1 ? "over \(Int(evaluation.occurrences.rounded())) times" : nil,
                            tint: .orange)
                }

                if abs(dh) > 0.005 {
                    // When the clock time and the cost of that time disagree, say so —
                    // it's usually the most surprising line here.
                    let discounted = abs(abs(dRaw) - abs(dh)) > 0.02
                    StatRow(label: "\(Fmt.sentenceStart(dh > 0 ? nameB : nameA)) is quicker",
                            value: Fmt.duration(hours: abs(dh)),
                            detail: discounted
                                ? "\(Fmt.duration(hours: abs(dRaw))) on the clock, but counted as \(Fmt.duration(hours: abs(dh))) — worth \(Fmt.money(abs(dh) * evaluation.rate))"
                                : "worth \(Fmt.money(abs(dh) * evaluation.rate)) at your rate",
                            tint: .blue)
                }

                if abs(dj) > 0.5 {
                    StatRow(label: "\(Fmt.sentenceStart(dj > 0 ? nameA : nameB)) feels better",
                            value: Fmt.money(abs(dj)),
                            detail: decision.scarcity == .often
                                ? "priced against your \(Fmt.money(store.profile.joyAnchor)) memorable-evening anchor"
                                : "worth \(String(format: "%.1f", decision.scarcity.multiplier))× more because \(decision.scarcity.label.lowercased())",
                            tint: .pink)
                }

                if let perUseA = evaluation.a.costPerUse ?? evaluation.b.costPerUse,
                   perUseA > 0 {
                    if let a = evaluation.a.costPerUse {
                        StatRow(label: "\(Fmt.sentenceStart(nameA)), per use",
                                value: Fmt.money(a),
                                detail: "\(Int(evaluation.a.uses.rounded())) uses"
                                    + (decision.optionA.usageConfidence != .certain
                                       ? " — trimmed for how sure you are" : ""),
                                tint: .indigo)
                    }
                    if let b = evaluation.b.costPerUse {
                        StatRow(label: "\(Fmt.sentenceStart(nameB)), per use",
                                value: Fmt.money(b),
                                detail: "\(Int(evaluation.b.uses.rounded())) uses"
                                    + (decision.optionB.usageConfidence != .certain
                                       ? " — trimmed for how sure you are" : ""),
                                tint: .indigo)
                    }
                }

                if abs(evaluation.deltaOpportunity) > 0.5 {
                    let dOpp = evaluation.deltaOpportunity
                    StatRow(label: "\(Fmt.sentenceStart(dOpp > 0 ? nameA : nameB)) gives up more growth",
                            value: Fmt.money(abs(dOpp)),
                            detail: store.profile.savingsBonusPercent > 0
                                ? "what that money would have become at \(Fmt.money(store.profile.savingsReturnPercent, decimals: false).dropFirst())% plus the \(Int(store.profile.savingsBonusPercent))% bonus"
                                : "what that money would have become if you'd left it alone",
                            tint: .mint)
                }

                if decision.optionA.growth == .tangent || decision.optionB.growth == .tangent {
                    Text("You said the learning is a detour, so it isn't counted. Getting good at something you don't need is a longer way of being busy — if someone else will do it for less than your time is worth, that's usually the better trade.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if abs(evaluation.deltaGrowth) > 0.5 {
                    let dg = evaluation.deltaGrowth
                    StatRow(label: "\(Fmt.sentenceStart(dg > 0 ? nameA : nameB)) teaches you something",
                            value: Fmt.money(abs(dg)),
                            detail: "a capability you keep — counted mostly for the first few goes",
                            tint: .indigo)
                }

                if abs(evaluation.deltaSocial) > 0.5 {
                    let ds = evaluation.deltaSocial
                    StatRow(label: "\(Fmt.sentenceStart(ds > 0 ? nameA : nameB)) matters to other people",
                            value: Fmt.money(abs(ds)),
                            detail: "counted apart from whether you'd enjoy it, because it isn't the same thing",
                            tint: .purple)
                }

                if decision.optionA.displaces != .nothing || decision.optionB.displaces != .nothing {
                    let pushes = decision.optionA.displaces != .nothing ? nameA : nameB
                    let level = decision.optionA.displaces != .nothing
                        ? decision.optionA.displaces : decision.optionB.displaces
                    Text("\(Fmt.sentenceStart(pushes)) takes its hours from something already planned, so they're counted at \(String(format: "%.0f%%", (level.multiplier - 1) * 100)) more than the clock. \(level.explanation)")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if decision.optionA.deferability != .nowOrNever || decision.optionB.deferability != .nowOrNever {
                    let waits = decision.optionA.deferability != .nowOrNever ? nameA : nameB
                    Text("You said you'd do \(waits) tomorrow anyway, so most of what it's worth isn't riding on tonight. Squeezing it in buys you the difference, and costs you whatever tonight costs.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if decision.optionA.drain == .costsSleep || decision.optionB.drain == .costsSleep {
                    let costly = decision.optionA.drain == .costsSleep ? nameA : nameB
                    Text("\(Fmt.sentenceStart(costly)) is counted at two and a half times its clock time, because sleep isn't ordinary tiredness — you pay for it all the next day.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if decision.optionA.joyConfidence.isGamble || decision.optionB.joyConfidence.isGamble {
                    Text("You've said the good version isn't certain, so the enjoyment is counted at what it's actually worth on average. This is a gamble rather than a calculation — if it goes well it'll beat this, and if it doesn't it won't.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if abs(evaluation.deltaHealth) > 0.5 {
                    let dh2 = evaluation.deltaHealth
                    StatRow(label: "\(Fmt.sentenceStart(dh2 > 0 ? nameA : nameB)) is better for you",
                            value: Fmt.money(abs(dh2)),
                            detail: evaluation.occurrences > 1
                                ? "counted straight out over \(Int(evaluation.occurrences.rounded())) times — health compounds where enjoyment fades"
                                : "one healthy choice on its own is worth little; it's the habit that counts",
                            tint: .teal)
                }

                if abs(dr) > 0.5 {
                    StatRow(label: "\(Fmt.sentenceStart(dr > 0 ? nameB : nameA)) is more reliable",
                            value: Fmt.money(abs(dr)),
                            detail: "the expected cost of it going wrong",
                            tint: .purple)
                }

                if decision.optionA.drain == .restoring || decision.optionB.drain == .restoring {
                    let restoring = decision.optionA.drain == .restoring ? nameA : nameB
                    Text("\(Fmt.sentenceStart(restoring)) is counted as taking no time at all — a proper break pays for itself in what you get done afterwards.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if abs(dm) <= 0.01 && abs(dh) <= 0.005 && abs(dj) <= 0.5 && abs(dr) <= 0.5 && abs(evaluation.deltaHealth) <= 0.5 && abs(evaluation.deltaGrowth) <= 0.5 && abs(evaluation.deltaOpportunity) <= 0.5 && abs(evaluation.deltaSocial) <= 0.5 {
                    Text("Nothing separates these two yet.")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var consequencesCard: some View {
        let b = store.breakdown
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                Label("In real terms", systemImage: "scope")
                    .font(.subheadline.weight(.semibold))

                if abs(evaluation.deltaMoney) > 0.01 && b.effectiveEarnedRate > 0 {
                    StatRow(label: "The money gap, in work",
                            value: Fmt.duration(hours: evaluation.workHoursForMoneyGap),
                            detail: "at \(Fmt.rate(b.effectiveEarnedRate)) take-home, commute included")
                }

                // Something specific coming up beats an abstract savings target every time.
                if let commitment = b.tightestCommitment, abs(evaluation.deltaMoney) > 0.01 {
                    let share = abs(evaluation.deltaMoney) / max(commitment.amount, 1) * 100
                    StatRow(label: "Against the \(commitment.name)",
                            value: String(format: "%.0f%%", min(share, 999)),
                            detail: b.tightestShortfall > 0
                                ? "you're \(Fmt.money(b.tightestShortfall, decimals: false)) short with \(commitment.daysAway) days to go"
                                : "\(commitment.daysAway) days to go, and you're on track")
                } else if let days = evaluation.savingsDelayDays {
                    StatRow(label: "Delay to your \(store.profile.savingsGoalLabel)",
                            value: Fmt.days(days),
                            detail: "against \(Fmt.money(store.profile.monthlySavingsTarget, decimals: false)) put aside each month")
                }

                if evaluation.occurrences > 1 {
                    let years = max(decision.horizonMonths / 12, 0.0001)
                    StatRow(label: "Gap per year",
                            value: Fmt.money(abs(evaluation.deltaMoney) / years, decimals: false),
                            detail: "and \(Fmt.duration(hours: abs(evaluation.deltaHours) / years))")
                }
            }
        }
    }

    /// Where the answer is fragile. Shown plainly, without hedging the whole thing.
    private var sensitivityCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Label("Worth knowing", systemImage: "exclamationmark.triangle")
                    .font(.subheadline.weight(.semibold))
                ForEach(evaluation.sensitivities) { s in
                    HStack(alignment: .top, spacing: 8) {
                        Circle().fill(Color.secondary.opacity(0.4))
                            .frame(width: 5, height: 5).padding(.top, 6)
                        Text(s.text).font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func projectionCard(_ projection: (money: Double, hours: Double)) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Label("If this became a habit", systemImage: "calendar")
                    .font(.subheadline.weight(.semibold))
                Text("Make this same choice every week for a year and the gap becomes \(Fmt.money(abs(projection.money), decimals: false)) and \(Fmt.duration(hours: abs(projection.hours))).")
                    .font(.footnote).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var totalsCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 14) {
                Label(evaluation.occurrences > 1
                      ? "Totals over \(Int(evaluation.occurrences.rounded())) times"
                      : "The totals",
                      systemImage: "list.bullet")
                    .font(.subheadline.weight(.semibold))

                totalsColumn(name: Fmt.sentenceStart(nameA), totals: evaluation.a, isWinner: evaluation.winner == .a)
                Divider()
                totalsColumn(name: Fmt.sentenceStart(nameB), totals: evaluation.b, isWinner: evaluation.winner == .b)

                Text("True cost = money + time priced at \(Fmt.rate(evaluation.rate)) − how it feels − what it does for you + what it risks")
                    .font(.caption2).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func totalsColumn(name: String, totals: OptionTotals, isWinner: Bool) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(name).font(.headline)
                if isWinner {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.green).font(.footnote)
                }
                Spacer()
                Text(Fmt.money(totals.netCost))
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(isWinner ? .green : .primary)
            }
            HStack(spacing: 10) {
                miniStat(totals.money >= 0 ? "costs" : "pays you", Fmt.money(abs(totals.money)))
                if totals.rawHours > 0 { miniStat("takes", Fmt.duration(hours: totals.rawHours)) }
                if abs(totals.opportunityCost) > 0.5 { miniStat("forgoes", Fmt.money(abs(totals.opportunityCost))) }
                if abs(totals.joy) > 0.5 { miniStat(totals.joy > 0 ? "feels" : "grates", Fmt.money(abs(totals.joy))) }
                if totals.social > 0.5 { miniStat("means to them", Fmt.money(totals.social)) }
                if abs(totals.health) > 0.5 { miniStat(totals.health > 0 ? "health" : "costs you", Fmt.money(abs(totals.health))) }
                if totals.growth > 0.5 { miniStat("teaches", Fmt.money(totals.growth)) }
                if let perUse = totals.costPerUse { miniStat("per use", Fmt.money(perUse)) }
                if totals.riskCost > 0.5 { miniStat("risks", Fmt.money(totals.riskCost)) }
            }
        }
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold).monospacedDigit())
        }
    }

    private func noteCard(_ text: String, symbol: String, tint: Color) -> some View {
        Card {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: symbol).foregroundStyle(tint)
                Text(text).font(.footnote).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var footnote: some View {
        VStack(spacing: 6) {
            Text("Worked out at \(Fmt.rate(evaluation.rate)) for your time.")
                .font(.caption).foregroundStyle(.secondary)
            Text("A way of thinking, not an oracle. If the answer feels wrong, that feeling is information — put it on the slider.")
                .font(.caption2).foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 4)
    }
}

/// A number line with your rate and the tipping point on it.
struct BreakEvenScale: View {
    let yourRate: Double
    let breakEven: Double

    var body: some View {
        let upper = max(yourRate, breakEven) * 1.35
        let yourFraction = min(max(yourRate / upper, 0.02), 0.98)
        let beFraction = min(max(breakEven / upper, 0.02), 0.98)
        let youWin = yourRate >= breakEven

        return VStack(spacing: 8) {
            GeometryReader { geo in
                let w = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.secondary.opacity(0.15)).frame(height: 10)
                    Capsule().fill(youWin ? Color.green.opacity(0.35) : Color.blue.opacity(0.3))
                        .frame(width: w * yourFraction, height: 10)
                    Rectangle().fill(Color.primary)
                        .frame(width: 2, height: 22)
                        .offset(x: w * beFraction - 1)
                    Circle().fill(youWin ? Color.green : Color.blue)
                        .frame(width: 14, height: 14)
                        .overlay(Circle().strokeBorder(Color(.systemBackground), lineWidth: 2))
                        .offset(x: w * yourFraction - 7)
                }
                .frame(height: 24)
            }
            .frame(height: 24)

            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text("You").font(.caption2).foregroundStyle(.secondary)
                    Text(Fmt.rate(yourRate)).font(.caption.weight(.semibold).monospacedDigit())
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Tipping point").font(.caption2).foregroundStyle(.secondary)
                    Text(Fmt.rate(breakEven)).font(.caption.weight(.semibold).monospacedDigit())
                }
            }
        }
    }
}
