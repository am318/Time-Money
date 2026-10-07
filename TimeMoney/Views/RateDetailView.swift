import SwiftUI

/// Shows the whole derivation. A rate you don't believe is a rate you won't act on.
struct RateDetailView: View {

    /// Where the scarcity adjustment lands in the numbered working, which depends on
    /// whether the marginal-rate step was shown above it.
    private func scarcityStep(_ b: RateBreakdown) -> Int {
        b.earningFlexibility.usesMarginalRate ? 5 : 4
    }

    @Environment(Store.self) private var store

    var body: some View {
        let b = store.breakdown

        ScrollView {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("An hour of your time is worth")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(Fmt.money(b.personalHourlyRate))
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        if b.isOverridden {
                            Text("Set by hand. The working below shows what the numbers would have said.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                step(1, "What work actually pays you") {
                    StatRow(label: "Take-home", value: Fmt.money(b.netMonthlyIncome) + " / month")
                    StatRow(label: "Paid hours", value: String(format: "%.0f / month", b.paidHoursMonthly),
                            detail: "\(Int(b.paidHoursWeekly))h a week")
                    StatRow(label: "Nominal rate", value: Fmt.rate(b.earnedRate))
                    if let measured = b.measuredWorkHoursWeekly {
                        StatRow(label: "Hours work really takes",
                                value: String(format: "%.0fh a week", b.workHoursWeekly),
                                detail: b.measuredWorkConfidence >= 1
                                    ? "Your timed deep work in conventional hours, over \(b.measuredWorkWeeks) recorded weeks"
                                    : "Your diary says \(String(format: "%.0f", measured))h over \(b.measuredWorkWeeks) recorded weeks, taken \(Int((b.measuredWorkConfidence * 100).rounded()))% of the way towards the \(String(format: "%.0f", b.paidHoursWeekly))h you typed — your days have been varying")
                    }
                    StatRow(label: "With commute counted", value: Fmt.rate(b.effectiveEarnedRate),
                            detail: b.measuredWorkHoursWeekly == nil
                                ? "\(Int(b.commuteHoursWeekly))h a week you give to work unpaid"
                                : "Those hours plus \(Int(b.commuteHoursWeekly))h of commute. This is what a pound costs you in life.",
                            emphasis: true)
                }

                step(2, "What a spare hour competes with") {
                    StatRow(label: "Committed each month", value: Fmt.money(b.committedMonthly, decimals: false),
                            detail: "Rent, bills and savings")
                    StatRow(label: "Genuinely free to spend", value: Fmt.money(b.discretionaryMonthly, decimals: false),
                            tint: b.discretionaryMonthly < 0 ? .red : nil)
                    if let measured = b.measuredFreeHoursWeekly {
                        StatRow(label: "Free evenings, measured", value: String(format: "%.0fh a week", measured),
                                detail: "from \(b.measuredDays) days of your own diary, not a subtraction")
                        if b.overspillHoursWeekly > 0 {
                            StatRow(label: "Less work done in them",
                                    value: "−" + Fmt.duration(hours: b.overspillHoursWeekly),
                                    detail: "timed work that landed in evenings and weekends")
                        }
                        StatRow(label: "Genuinely free hours", value: String(format: "%.0f / month", b.freeHoursMonthly),
                                detail: "\(Int(b.freeHoursWeekly))h a week once chores come off too")
                    } else {
                        StatRow(label: "Genuinely free hours", value: String(format: "%.0f / month", b.freeHoursMonthly),
                                detail: "\(Int(b.freeHoursWeekly))h a week after sleep, work and chores")
                    }
                    StatRow(label: "Money per free hour", value: Fmt.rate(b.leisureRate), emphasis: true)
                    Text("Buying back an hour costs money you'd otherwise have spent enjoying an hour. That's the honest exchange rate.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                step(3, "Blending the two") {
                    StatRow(label: "35% of your commute-adjusted wage", value: Fmt.money(0.35 * b.effectiveEarnedRate))
                    StatRow(label: "65% of your money-per-free-hour", value: Fmt.money(0.65 * b.leisureRate))
                    StatRow(label: "Blended", value: Fmt.rate(b.leisureBlend), emphasis: true)
                    Text("Most people's instinct about an hour sits between what work pays and what their spare money buys. The blend puts it there.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if b.earningFlexibility.usesMarginalRate {
                    step(4, "Because you can sell an hour") {
                        StatRow(label: "Your hourly rate", value: Fmt.rate(b.marginalRate))
                        StatRow(label: b.earningFlexibility.label, value: Fmt.rate(b.baseRate), emphasis: true)
                        Text(b.earningFlexibility.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                step(scarcityStep(b), "Which is scarcer for you") {
                    StatRow(label: "Before adjustment", value: Fmt.rate(b.baseRate))
                    StatRow(label: b.stance.label, value: String(format: "× %.1f", b.stanceMultiplier))
                    StatRow(label: "Your rate", value: Fmt.rate(b.baseRate * b.stanceMultiplier), emphasis: true)
                    Text(b.stance.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                // Shown only when it's doing something. It was previously missing from the
                // working entirely, which meant a rate could be a quarter higher than the
                // steps above it accounted for.
                if b.loadMultiplier != 1 {
                    step(scarcityStep(b) + 1, "How this week is going") {
                        StatRow(label: b.load.shortLabel, value: String(format: "× %.2f", b.loadMultiplier))
                        StatRow(label: "Your rate",
                                value: Fmt.rate(b.baseRate * b.stanceMultiplier * b.loadMultiplier),
                                emphasis: true)
                        Text(b.loadIsMeasured
                             ? "Read from your diary — the next seven days against your own normal — so there's nothing to remember to turn off."
                             : b.load.explanation)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if b.goalPressure > 0, let commitment = b.tightestCommitment {
                    step(scarcityStep(b) + (b.loadMultiplier != 1 ? 2 : 1), "Something coming up") {
                        StatRow(label: commitment.name, value: Fmt.money(commitment.amount, decimals: false),
                                detail: "needed in \(commitment.daysAway) days")
                        StatRow(label: "Still to find", value: Fmt.money(b.tightestShortfall, decimals: false),
                                tint: .orange)
                        StatRow(label: "So money counts for more",
                                value: String(format: "× %.2f", b.pressureMultiplier))
                        StatRow(label: "Your rate", value: Fmt.rate(b.personalHourlyRate), emphasis: true)
                        Text("Being short of something specific makes a pound genuinely scarcer, so an hour is worth less until you're back on track. This lifts on its own once you are.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("A sense of scale", systemImage: "ruler")
                            .font(.subheadline.weight(.semibold))
                        Text("At \(Fmt.rate(b.personalHourlyRate)), paying to save ten minutes is worth up to \(Fmt.money(b.personalHourlyRate / 6)). Saving a whole Saturday is worth \(Fmt.money(b.personalHourlyRate * 8, decimals: false)).")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                NavigationLink(value: Route.settings) {
                    Label("Change your situation", systemImage: "gearshape")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Your rate")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func step<Content: View>(_ number: Int, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Text("\(number)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Color(.systemBackground))
                        .frame(width: 20, height: 20)
                        .background(Circle().fill(Color.accentColor))
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                }
                content()
            }
        }
    }
}
