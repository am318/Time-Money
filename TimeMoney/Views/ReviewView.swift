import SwiftUI

/// Looking back, with no pressure attached. Nothing here keeps score, nothing
/// nags, and skipping it costs nothing at all.
struct ReviewView: View {
    @Environment(Store.self) private var store

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                CalibrationCard()

                if store.awaitingReview.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nothing waiting")
                                .font(.headline)
                            Text("Decisions turn up here a day after you save them. There's no schedule and nothing to keep up with.")
                                .font(.footnote).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    ForEach(store.awaitingReview) { decision in
                        ReviewCard(decision: decision)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Looking back")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ReviewCard: View {
    @Environment(Store.self) private var store
    let decision: Decision

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(decision.title.isEmpty ? decision.scenario.template.title : decision.title)
                        .font(.headline)
                    if let verdict = decision.recordedVerdict {
                        Text(verdict).font(.subheadline).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Text(decision.createdAt, format: .dateTime.weekday(.wide).day().month())
                        .font(.caption).foregroundStyle(.tertiary)
                }

                Text("Looking back, how does it seem?")
                    .font(.footnote).foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    ForEach(ReviewOutcome.allCases) { outcome in
                        Button {
                            withAnimation(.snappy) { store.setReview(outcome, for: decision) }
                        } label: {
                            VStack(spacing: 5) {
                                Image(systemName: outcome.symbol).font(.system(size: 15))
                                Text(outcome.label).font(.caption2.weight(.medium))
                                    .lineLimit(1).minimumScaleFactor(0.8)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .background(RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .fill(Color.secondary.opacity(0.10)))
                            .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// What the reviews add up to. Offered as a question, never applied on its own.
struct CalibrationCard: View {
    @Environment(Store.self) private var store
    @State private var dismissed: Set<String> = []

    var body: some View {
        let c = store.calibration

        VStack(spacing: 12) {
            Card(tint: (c.suggestedRate != nil || !c.anchorSuggestions.isEmpty) ? .accentColor : .clear) {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Checking its own numbers", systemImage: "scalemass")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(c.headline).font(.headline)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(c.detail)
                        .font(.footnote).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let suggested = c.suggestedRate, !dismissed.contains("rate") {
                        HStack(spacing: 10) {
                            Button {
                                store.profile.rateOverride = suggested
                            } label: {
                                Text("Use \(Fmt.money(suggested))")
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 14).padding(.vertical, 9)
                                    .background(Capsule().fill(Color.accentColor))
                                    .foregroundStyle(Color(.systemBackground))
                            }
                            .buttonStyle(.plain)

                            Button("Leave it") {
                                withAnimation { _ = dismissed.insert("rate") }
                            }
                            .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 2)
                    }

                    if c.setAside > 0 {
                        Text("\(c.setAside) you couldn't call either way. Those count for nothing — saying so is always safe.")
                            .font(.caption).foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }

            ForEach(c.anchorSuggestions) { suggestion in
                if !dismissed.contains(suggestion.id) {
                    Card(tint: .teal) {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("From the decisions about \(suggestion.factor.label)",
                                  systemImage: suggestion.isRaise ? "arrow.up.right" : "arrow.down.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            Text(suggestion.detail)
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 10) {
                                Button {
                                    apply(suggestion)
                                } label: {
                                    Text("\(Fmt.money(suggestion.current)) → \(Fmt.money(suggestion.suggested))")
                                        .font(.subheadline.weight(.semibold))
                                        .padding(.horizontal, 14).padding(.vertical, 9)
                                        .background(Capsule().fill(Color.teal.opacity(0.18)))
                                        .foregroundStyle(.teal)
                                }
                                .buttonStyle(.plain)

                                Button("Leave it") {
                                    withAnimation { _ = dismissed.insert(suggestion.id) }
                                }
                                .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func apply(_ suggestion: AnchorSuggestion) {
        switch suggestion.factor {
        case .joy, .social: store.profile.joyAnchor = suggestion.suggested
        case .health: store.profile.healthAnchor = suggestion.suggested
        case .growth: store.profile.growthAnchor = suggestion.suggested
        case .money, .time: break
        }
        withAnimation { _ = dismissed.insert(suggestion.id) }
    }
}

/// What past purchases actually cost, once enough time has passed to tell.
struct InContextView: View {
    @Environment(Store.self) private var store

    var body: some View {
        let ctx = store.spendingInContext

        ScrollView {
            VStack(spacing: 16) {
                if ctx.isEmpty {
                    Card {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Nothing bought yet").font(.headline)
                            Text("Anything you buy outright and save shows up here, spread across the days since — which is the only way to tell whether the expensive one was right.")
                                .font(.footnote).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                } else {
                    Card {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Since \(ctx.earliest?.formatted(date: .abbreviated, time: .omitted) ?? "")")
                                .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                            HStack(alignment: .firstTextBaseline, spacing: 6) {
                                Text(Fmt.money(ctx.totalCommitted, decimals: false))
                                    .font(.system(size: 34, weight: .bold, design: .rounded))
                                Text("on things you bought")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            if ctx.discretionaryOverPeriod > 0 {
                                Text("That's \(String(format: "%.0f%%", ctx.share * 100)) of everything you had spare over the same period.")
                                    .font(.footnote).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }

                    ForEach(ctx.purchases) { item in
                        Card {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(alignment: .firstTextBaseline) {
                                    Text(item.name).font(.headline)
                                    Spacer()
                                    Text(Fmt.money(item.amount, decimals: false))
                                        .font(.headline.monospacedDigit()).foregroundStyle(.secondary)
                                }
                                HStack(alignment: .firstTextBaseline, spacing: 5) {
                                    Text(Fmt.money(item.perDay))
                                        .font(.system(size: 26, weight: .bold, design: .rounded))
                                    Text("a day").font(.subheadline).foregroundStyle(.secondary)
                                }
                                Text("\(item.daysSince) days ago, so it's cost you \(item.comparison).")
                                    .font(.footnote).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                                Divider()
                                StatRow(label: "In today's money", value: Fmt.money(item.amountToday, decimals: false))
                                StatRow(label: "In hours of work", value: Fmt.duration(hours: item.hoursOfWork))
                                if item.shareOfDiscretionary > 0 {
                                    StatRow(label: "Of what you had spare since",
                                            value: String(format: "%.1f%%", item.shareOfDiscretionary * 100))
                                }
                            }
                        }
                    }

                    Text("A big number on the day is a small number spread over a few years — or it isn't, and that's worth seeing too.")
                        .font(.caption).foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("In context")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - History

struct HistoryView: View {
    @Environment(Store.self) private var store
    @Binding var path: [Route]

    var body: some View {
        List {
            if !store.decisions.isEmpty {
                Section {
                    let saved = store.lifetimeSaved
                    StatRow(label: "Money the better option avoided",
                            value: Fmt.money(saved.money, decimals: false), emphasis: true)
                    StatRow(label: "Hours it gave back",
                            value: Fmt.duration(hours: saved.hours), emphasis: true)
                    if store.overrideCount > 0 {
                        StatRow(label: "Times you did your own thing",
                                value: "\(store.overrideCount)",
                                detail: "Which is useful information, not a failing.")
                    }
                } header: {
                    Text("If you followed the answers")
                } footer: {
                    Text("Recalculated at your current rate, so it moves when your situation does.")
                }
            }

            if !store.activeCommitments.isEmpty {
                Section {
                    ForEach(store.activeCommitments) { decision in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(decision.title.isEmpty ? decision.scenario.template.title : decision.title)
                                if let at = decision.committedAt {
                                    Text(at, format: .dateTime.day().month(.abbreviated))
                                        .font(.caption).foregroundStyle(.tertiary)
                                }
                            }
                            Spacer()
                            let amount = decision.committedMoney ?? 0
                            Text(Fmt.money(amount))
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(amount < 0 ? .green : .orange)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { store.clearCommitment(store.activeCommitments[index]) }
                    }
                } header: {
                    Text("Committed in the last month")
                } footer: {
                    Text("What you've said you'd actually do, and what it ties up. It comes off what you have spare, so the decisions that follow are a little tighter — and it drops off after \(Int(Store.commitmentWindowDays)) days. Swipe to remove anything you didn't go through with.")
                }
            }

            Section {
                NavigationLink(value: Route.inContext) {
                    Label("What things actually cost", systemImage: "chart.line.downtrend.xyaxis")
                }
            } footer: {
                Text("Past purchases spread across the days since you made them.")
            }

            Section("Saved") {
                ForEach(store.decisions) { decision in
                    Button { path.append(.savedDecision(decision.id)) } label: {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(decision.title.isEmpty ? decision.scenario.template.title : decision.title)
                                    .foregroundStyle(.primary)
                                if let review = decision.review {
                                    Image(systemName: review.symbol)
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            if let verdict = decision.recordedVerdict {
                                Text(verdict).font(.caption).foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if let rate = decision.recordedRate {
                                Text("Decided at \(Fmt.rate(rate)) · \(decision.createdAt.formatted(date: .abbreviated, time: .omitted))")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
                .onDelete { offsets in
                    for index in offsets { store.delete(store.decisions[index]) }
                }
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if store.decisions.isEmpty {
                ContentUnavailableView("Nothing saved yet",
                                       systemImage: "tray",
                                       description: Text("Work something out, then tap Save what I did if you want to keep it."))
            }
        }
    }
}
