import SwiftUI

struct HomeView: View {
    @Environment(Store.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Binding var path: [Route]
    @State private var query = ""

    private var searchResults: [ScenarioKind] { ScenarioTemplate.search(query) }

    var body: some View {
        ScrollView {
            if !query.isEmpty {
                searchContent
            } else {
                mainContent
            }
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .automatic),
                    prompt: "Uber, gym, warranty…")
        // A search field has no sentences in it. Left on, iOS capitalised the first
        // letter of a box whose own placeholder is lowercase, and autocorrect took
        // a fair run at "payg" and "diy".
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("Time / Money")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { path.append(.settings) } label: { Image(systemName: "gearshape") }
                    .accessibilityLabel("Settings")
            }
        }
    }

    // MARK: - Searching

    private var searchContent: some View {
        VStack(spacing: 10) {
            if searchResults.isEmpty {
                VStack(spacing: 8) {
                    Text("Nothing matching “\(query)”")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button("Start a blank decision instead") {
                        path.append(.newDecision(.custom))
                    }
                    .font(.subheadline)
                }
                .padding(.top, 40)
            } else {
                ForEach(searchResults) { kind in
                    ScenarioRow(kind: kind) { path.append(.newDecision(kind)) }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Home

    private var mainContent: some View {
        VStack(spacing: 20) {
            rateCard
            weekRow

            PrimaryButton(title: "New decision", systemImage: "plus") {
                path.append(.newDecision(.custom))
            }

            if let raise = store.pendingSavingsRaise { savingsRaiseCard(raise) }
            if let cooldown = store.activeCooldown { cooldownNote(cooldown) }
            if !store.awaitingReview.isEmpty { reviewNudge }

            VStack(alignment: .leading, spacing: 10) {
                Text("Or start from a situation")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10),
                                    GridItem(.flexible(), spacing: 10)],
                          spacing: 10) {
                    ForEach(store.suggestedScenarios) { kind in
                        ScenarioTile(kind: kind) { path.append(.newDecision(kind)) }
                    }
                }

                Button { path.append(.browse) } label: {
                    HStack {
                        Text("All \(store.visibleScenarioCount) situations")
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)
            }

            if !store.decisions.isEmpty { recentSection }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }

    private var rateCard: some View {
        let b = store.breakdown
        return Button { path.append(.rateDetail) } label: {
            Card {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("An hour of your time")
                            .font(.caption.weight(.semibold)).tracking(0.6)
                            .textCase(.uppercase)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(Fmt.money(b.personalHourlyRate))
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("an hour").font(.title3).foregroundStyle(.secondary)
                    }

                    // Three pills side by side stop fitting long before the largest
                    // text sizes, and a capsule is the worst possible place to wrap:
                    // "Balanced" came out as "Bal-an-ced" stacked inside a circle.
                    // Past the accessibility sizes they go one to a line instead.
                    let chipLayout = typeSize.isAccessibilitySize
                        ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6))
                        : AnyLayout(HStackLayout(spacing: 6))
                    chipLayout {
                        Chip(text: b.stance.shortLabel, systemImage: "scalemass")
                        Chip(text: "\(Fmt.money(b.discretionaryMonthly, decimals: false)) spare", systemImage: "banknote")
                        Chip(text: "\(Int(b.freeHoursWeekly))h free", systemImage: "clock")
                    }

                    if b.recentlyCommitted > 0 {
                        Text("\(Fmt.money(b.recentlyCommitted, decimals: false)) committed in the last month, so there's \(Fmt.money(max(0, b.discretionaryMonthly), decimals: false)) left to play with.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }

                    if let commitment = b.tightestCommitment, b.goalPressure > 0 {
                        Text("\(commitment.name) is \(commitment.daysAway) days away and you're \(Fmt.money(b.tightestShortfall, decimals: false)) short, so money's counting for more right now.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// The acute kind of time pressure. Sets itself back to normal after a week,
    /// so there's never a stale setting quietly distorting everything.
    ///
    /// Hidden entirely once the diary is answering the question. A control that
    /// looks live and is being overruled is worse than no control: the first time
    /// you tap it and nothing moves, you stop believing any of it.
    @ViewBuilder
    private var weekRow: some View {
        @Bindable var store = store
        let b = store.breakdown
        if b.loadIsMeasured {
            HStack(spacing: 6) {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(b.load.shortLabel), from your diary")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        } else {
            weekPicker
        }
    }

    private var weekPicker: some View {
        @Bindable var store = store
        let current = store.profile.effectiveLoad
        return HStack(spacing: 6) {
            ForEach(LoadLevel.allCases) { level in
                Button {
                    withAnimation(.snappy(duration: 0.15)) {
                        store.profile.loadLevel = level
                        store.profile.loadSetAt = level == .normal ? nil : Date()
                    }
                } label: {
                    Text(typeSize.isAccessibilitySize ? level.tightLabel : level.shortLabel)
                        .font(.caption.weight(current == level ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(current == level
                                      ? Color.accentColor.opacity(0.15)
                                      : Color(.secondarySystemGroupedBackground))
                        )
                        .foregroundStyle(current == level ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Pay has gone up and savings haven't followed.
    ///
    /// Shown once per raise and dismissible, because a card that reappears every
    /// launch stops being information and becomes nagging. The proportional figure
    /// is the floor the user asked for; the other one is there because none of the
    /// rent or the bills went up with the raise, so rather more is usually
    /// affordable than merely keeping the share.
    private func savingsRaiseCard(_ raise: SavingsRatchet.Raise) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "arrow.up.right.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Your take-home is up \(Fmt.money(raise.incomeIncrease, decimals: false)) a month")
                            .font(.subheadline.weight(.medium))
                        Text("Saving the same \(Int((raise.share * 100).rounded()))% means \(Fmt.money(raise.proportionalSavings, decimals: false)) rather than \(Fmt.money(raise.previousSavings, decimals: false)). Your rent and bills didn't go up with it, so \(Fmt.money(secondFigure(raise), decimals: false)) is usually affordable too.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        // What the rise was actually worth. A payslip going up and a
                        // standard of living going up are not the same event, and the
                        // only way to tell them apart is against something outside
                        // this app's own figures.
                        if let note = riseAgainstTheLine(raise) {
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(raise.keptUpWithTheLine ? Color.secondary : Color.orange)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Spacer(minLength: 0)
                }

                HStack(spacing: 8) {
                    Button {
                        store.applySavingsRaise(raise.proportionalSavings, raise: raise,
                                                includingGoal: raise.hasGoal)
                    } label: {
                        Text("Save \(Fmt.money(raise.proportionalSavings, decimals: false))")
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.accentColor.opacity(0.15)))
                            .foregroundStyle(Color.accentColor)
                    }
                    .buttonStyle(.plain)

                    Button {
                        store.applySavingsRaise(secondFigure(raise), raise: raise,
                                                includingGoal: raise.hasGoal)
                    } label: {
                        Text("Save \(Fmt.money(secondFigure(raise), decimals: false))")
                            .font(.footnote.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color(.secondarySystemGroupedBackground)))
                            .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }

                Button("Not this time") { store.declineSavingsRaise(raise) }
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// The second of the two figures offered.
    ///
    /// Half the rise, unless Portfolio is publishing a living-wage line — in which
    /// case the indexed version, which is the same idea done properly: it holds the
    /// old saving at what it was *worth* and adds half of whatever was genuinely new,
    /// rather than treating the whole rise as spare when part of it was the cost of
    /// living catching up. With a flat line the two are the same number.
    private func secondFigure(_ raise: SavingsRatchet.Raise) -> Double {
        raise.livingWage == nil ? raise.halfTheRiseSavings : raise.indexedSavings
    }

    /// What the rise did against the London Living Wage, where there is one to
    /// measure against and it has actually moved.
    private func riseAgainstTheLine(_ raise: SavingsRatchet.Raise) -> String? {
        guard raise.livingWage != nil, let newMoney = raise.newMoneyMonthly else { return nil }
        if raise.indexedIsCapped {
            return "Held at \(Fmt.money(secondFigure(raise), decimals: false)) so that what is left still clears the London Living Wage."
        }
        guard abs(newMoney - raise.incomeIncrease) > 1 else { return nil }
        if newMoney < 0 {
            return "Against the London Living Wage this is a cut: the line has risen further than your pay since \(raise.since.formatted(.dateTime.month(.wide).year())), so you would need \(Fmt.money(-newMoney, decimals: false)) a month more just to stand still."
        }
        return "Of that rise, \(Fmt.money(newMoney, decimals: false)) a month is genuinely new — the rest is the London Living Wage catching up since \(raise.since.formatted(.dateTime.month(.wide).year()))."
    }

    /// A suggestion, not a barrier. Deciding is the easy part.
    private func cooldownNote(_ cooldown: Store.Cooldown) -> some View {
        Card {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hourglass")
                    .font(.system(size: 16))
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("You said you'd do \(cooldown.name)")
                        .font(.subheadline.weight(.medium))
                    Text(cooldown.remainingMinutes >= 60
                         ? "About \(cooldown.remainingMinutes / 60)h \(cooldown.remainingMinutes % 60)m of that left. Worth getting on with it before deciding anything else."
                         : "About \(cooldown.remainingMinutes) minutes of that left. Worth getting on with it before deciding anything else.")
                        .font(.caption).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
        }
    }

    /// Deliberately gentle, and it goes away on its own. Nothing here nags.
    private var reviewNudge: some View {
        Button { path.append(.review) } label: {
            Card {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(store.awaitingReview.count) to look back on")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Text("A tap each, whenever you fancy it.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Recent").font(.subheadline.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                Button("See all") { path.append(.history) }.font(.subheadline)
            }
            ForEach(store.decisions.prefix(3)) { decision in
                Button { path.append(.savedDecision(decision.id)) } label: {
                    DecisionRow(decision: decision)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Browsing the full set

struct ScenarioBrowserView: View {
    @Environment(Store.self) private var store
    @Binding var path: [Route]
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if query.isEmpty {
                    ForEach(ScenarioTemplate.Family.allCases) { family in
                        // A family everything has been hidden out of shouldn't leave
                        // its heading behind with nothing under it.
                        let kinds = store.visibleScenarios(in: family)
                        if !kinds.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(family.rawValue, systemImage: family.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(kinds) { kind in
                                    ScenarioRow(kind: kind) { path.append(.newDecision(kind)) }
                                }
                            }
                        }
                    }
                    if !store.hiddenScenarios.isEmpty {
                        Text("\(store.hiddenScenarios.count) hidden. Search still finds them, and Settings brings them back.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(ScenarioTemplate.search(query)) { kind in
                        ScenarioRow(kind: kind) { path.append(.newDecision(kind)) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $query, prompt: "Search situations")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("Situations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pieces

struct ScenarioRow: View {
    @Environment(Store.self) private var store
    let kind: ScenarioKind
    let action: () -> Void

    var body: some View {
        let t = kind.template
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: t.symbol)
                    .font(.system(size: 16))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(t.blurb)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .contextMenu { ScenarioVisibilityButton(kind: kind) }
    }
}

struct ScenarioTile: View {
    @Environment(Store.self) private var store
    let kind: ScenarioKind
    let action: () -> Void

    var body: some View {
        let t = kind.template
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: t.symbol)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 20)
                Text(t.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .contextMenu { ScenarioVisibilityButton(kind: kind) }
    }
}

struct Chip: View {
    let text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(text).font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .foregroundStyle(.secondary)
    }
}

struct DecisionRow: View {
    let decision: Decision

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: decision.scenario.template.symbol)
                .font(.system(size: 15))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(decision.title.isEmpty ? decision.scenario.template.title : decision.title)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                if let verdict = decision.recordedVerdict {
                    Text(verdict).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Text(decision.createdAt, format: .dateTime.day().month(.abbreviated))
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}


/// Shelving a situation, and bringing it back.
///
/// Hidden ones stay searchable on purpose. Someone who never takes taxis shouldn't
/// have to scroll past them for a year, and someone who suddenly does shouldn't have
/// to go to settings to find out where it went.
struct ScenarioVisibilityButton: View {
    @Environment(Store.self) private var store
    let kind: ScenarioKind

    var body: some View {
        if kind != .custom {
            let hidden = store.isHidden(kind)
            Button {
                store.setHidden(!hidden, for: kind)
            } label: {
                Label(hidden ? "Show in the list again" : "Hide from the list",
                      systemImage: hidden ? "eye" : "eye.slash")
            }
        }
    }
}
