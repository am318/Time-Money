import SwiftUI

/// The whole of making a decision: the numbers, then only the follow-ups that
/// could change the answer, then the answer on its own.
struct DecisionFlowView: View {
    @Environment(Store.self) private var store
    @Environment(\.dismiss) private var dismiss

    enum Stage: Equatable {
        case numbers
        case question(QuestionKind)
        case answer
    }

    @State private var decision: Decision
    @State private var stage: Stage
    @State private var showWorking = false
    /// A standing cost just taken on, waiting to be offered to the monthly bills.
    @State private var pendingBill: PendingBill?

    struct PendingBill: Identifiable { let id: UUID; let amount: Double }
    /// Which cards the person has actually engaged with. An option that genuinely
    /// costs nothing is a real answer; an option nobody has looked at is not, and
    /// letting a blank card "win" by costing nothing is how you lose someone's trust.
    @State private var visited: Set<String> = []
    @FocusState private var focus: EntryField?


    init(decision: Decision, startAt stage: Stage = .numbers) {
        _decision = State(initialValue: decision)
        _stage = State(initialValue: stage)
        _visited = State(initialValue: decision.isSaved ? [Side.a.rawValue, Side.b.rawValue] : [])
    }

    private var template: ScenarioTemplate { decision.scenario.template }
    private var rate: Double { store.rate }

    /// Recomputed only when the decision actually changes, rather than on every
    /// render — a full evaluation runs the sensitivity checks behind it.
    @State private var cached: Evaluation?

    private var evaluation: Evaluation {
        cached ?? DecisionEngine.evaluate(decision, profile: store.profile,
                                          breakdown: store.breakdown,
                                          calibration: store.timeCalibration,
                                          money: store.moneyCalibration)
    }

    /// Whether the one-off *time* row is worth drawing.
    ///
    /// A scenario that has named that row means it: finding a cleaner, the study hours,
    /// waiting in for the repair. Where it is unnamed the row is an empty box on a
    /// decision made purely of prices — "One-off time, 0h 0m" on both cards of buy
    /// outright against subscribe, which is the cleanest comparison in the app.
    private var showsSetupTimeRow: Bool {
        template.showsSetupTime || template.setupTimeLabel != nil
    }

    /// Every box on the form, in the order a thumb should travel through them.
    private var fieldOrder: [EntryField] {
        var out: [EntryField] = []
        for side in decision.isYesNo ? [Side.a] : [Side.a, .b] {
            out += [.money(side), .hours(side), .minutes(side)]
            if template.showsSetup { out.append(.setupMoney(side)) }
            if showsSetupTimeRow { out += [.setupHours(side), .setupMinutes(side)] }
        }
        return out
    }

    private func step(_ delta: Int) {
        guard let current = focus, let i = fieldOrder.firstIndex(of: current) else { return }
        let next = i + delta
        guard fieldOrder.indices.contains(next) else { return }
        focus = fieldOrder[next]
    }

    private var stepIndex: Int? {
        focus.flatMap { fieldOrder.firstIndex(of: $0) }
    }

    private func refresh() {
        cached = DecisionEngine.evaluate(decision, profile: store.profile,
                                         breakdown: store.breakdown,
                                         calibration: store.timeCalibration,
                                         money: store.moneyCalibration)
    }

    private func isAnswered(_ side: Side) -> Bool {
        let option = side == .a ? decision.optionA : decision.optionB
        return !option.isEmpty || visited.contains(side.rawValue)
    }

    private var hasEnough: Bool {
        decision.isYesNo ? isAnswered(.a) : isAnswered(.a) && isAnswered(.b)
    }

    /// Things worth saying on the bare answer screen, which is a high bar.
    ///
    /// Only two qualify: an assumption the app made by itself and might have got
    /// wrong, and a plain fact about this evening's diary. Everything else that
    /// explains the answer lives behind "Why?", where it was asked for.
    private var answerNotes: [String] {
        var notes: [String] = []
        if let sleep = decision.sleepBoundaryNote { notes.append(sleep) }
        let winner = evaluation.winner == .b ? decision.optionB : decision.optionA
        if evaluation.winner != .tooClose,
           let fit = store.fitNote(forMinutes: winner.setupMinutes + winner.minutes) {
            notes.append(fit)
        }
        return notes
    }

    private var promptForMissing: String {
        if decision.isYesNo { return "Put in what it costs you." }
        if !isAnswered(.a) && !isAnswered(.b) { return "Put in what each one costs you." }
        return !isAnswered(.a)
            ? "Still need the first one."
            : "Tap the second one — leave it at zero if it genuinely costs nothing."
    }

    var body: some View {
        VStack(spacing: 0) {
            switch stage {
            case .numbers:
                numbersScreen
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            case .question(let kind):
                questionScreen(kind)
                    .id(kind)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            case .answer:
                AnswerScreen(decision: $decision,
                             evaluation: evaluation,
                             notes: answerNotes,
                             onShowWorking: { showWorking = true },
                             onChoose: { side in
                                 let saved = store.record(decision, evaluation: evaluation)
                                 store.setChoice(side, for: saved)
                                 // Something you'll keep paying belongs in what you
                                 // already pay, not in a ledger that forgets in a month.
                                 if let monthly = DecisionEngine.monthlyStandingCost(of: side, in: decision) {
                                     pendingBill = PendingBill(id: saved.id, amount: monthly)
                                 } else {
                                     dismiss()
                                 }
                             },
                             onBack: { withAnimation { stage = .numbers } })
                    .transition(.opacity)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(stage == .numbers ? "" : template.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showWorking) {
            VerdictView(decision: decision, evaluation: evaluation,
                        freedTimeNote: store.freedTimeNote(for: evaluation))
        }
        .onAppear { refresh() }
        .alert("Add \(Fmt.money(pendingBill?.amount ?? 0)) to your monthly bills?",
               isPresented: Binding(get: { pendingBill != nil },
                                    set: { if !$0 { pendingBill = nil } }),
               presenting: pendingBill) { bill in
            Button("Add it") {
                store.addToMonthlyBills(bill.amount, forDecision: bill.id)
                pendingBill = nil
                dismiss()
            }
            Button("Not now", role: .cancel) { pendingBill = nil; dismiss() }
        } message: { _ in
            Text("It'll keep counting against your spare money until you remove it in Settings.")
        }
        // The whole app exists to arrive at one of these. Worth feeling.
        .sensoryFeedback(.success, trigger: stage) { _, new in new == .answer }
        .selectAllOnFocus(focus != nil)
        .onChange(of: decision) { _, _ in refresh() }
    }

    // MARK: - Screen one: the numbers

    private var numbersScreen: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 14) {
                    if let cooldown = store.activeCooldown {
                        HStack(spacing: 8) {
                            Image(systemName: "hourglass").font(.caption)
                            Text("\(cooldown.name) is still meant to be happening — this can probably wait.")
                                .font(.caption)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .foregroundStyle(.orange)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)
                    }

                    TextField(template.title, text: $decision.title)
                        .font(.title2.weight(.semibold))
                        .textInputAutocapitalization(.sentences)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 6)

                    if !template.hint.isEmpty {
                        Text(template.hint)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    numberCard(option: $decision.optionA, side: .a,
                               placeholder: template.optionA)
                        .simultaneousGesture(TapGesture().onEnded { visited.insert(Side.a.rawValue) })

                    if decision.isYesNo {
                        Text("or don't — that's the other option, and it costs nothing")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("or")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)

                        numberCard(option: $decision.optionB, side: .b,
                                   placeholder: template.optionB)
                            .simultaneousGesture(TapGesture().onEnded { visited.insert(Side.b.rawValue) })
                    }

                    recurrenceRow
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)

            VStack(spacing: 10) {
                PrimaryButton(title: "Answer", systemImage: "arrow.right", enabled: hasEnough) {
                    focus = nil
                    advance()
                }
                Text(hasEnough
                     ? "Only questions that could change the answer get asked."
                     : promptForMissing)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.bar)
        }
        // Land on the field the scenario is about. Half the decisions with a one-off
        // field are *made of* it — the purchase price, the course fees, the excess —
        // and the cursor sat in the monthly box above it, one unnoticed keystroke away
        // from reading £210 as £210 a month.
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Button { step(-1) } label: { Image(systemName: "chevron.up") }
                    .disabled((stepIndex ?? 0) <= 0)
                Button { step(1) } label: { Image(systemName: "chevron.down") }
                    .disabled(stepIndex == nil || stepIndex! >= fieldOrder.count - 1)
                Spacer()
                Button("Done") { focus = nil }.fontWeight(.semibold)
            }
        }
        .onAppear {
            if focus == nil {
                focus = template.startsOnTheOneOff ? .setupMoney(.a) : .money(.a)
            }
        }
    }

    private func numberCard(option: Binding<DecisionOption>,
                            side: Side,
                            placeholder: String) -> some View {
        let moneyField = EntryField.money(side)
        return Card {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 7) {
                    Image(systemName: "tag")
                        .font(.caption)
                        .foregroundStyle(option.wrappedValue.name.isEmpty
                                         ? Color.secondary.opacity(0.5) : Color.accentColor)
                    TextField(placeholder, text: option.name)
                        .font(.headline)
                        .textInputAutocapitalization(.sentences)
                }

                // Offered only while the box is empty, and only where the scenario has
                // no names of its own to fall back on.
                if !template.nameSuggestions.isEmpty
                    && option.wrappedValue.name.trimmingCharacters(in: .whitespaces).isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(template.nameSuggestions, id: \.self) { suggestion in
                                Button {
                                    withAnimation(.snappy(duration: 0.15)) {
                                        option.wrappedValue.name = suggestion
                                    }
                                } label: {
                                    Text(suggestion)
                                        .font(.caption.weight(.medium))
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                                        .foregroundStyle(Color.accentColor)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 1)
                    }
                    .scrollClipDisabled()
                }

                Divider()

                HStack {
                    Button {
                        withAnimation(.snappy(duration: 0.15)) {
                            option.wrappedValue.direction = option.wrappedValue.direction == .cost ? .receive : .cost
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(option.wrappedValue.direction.label(
                                every: decision.frequency,
                                eachTime: option.wrappedValue.isChargedEachTime
                                          && option.wrappedValue.timesEach != 1))
                            Image(systemName: "arrow.left.arrow.right").font(.caption2)
                        }
                        .foregroundStyle(option.wrappedValue.direction == .receive ? Color.accentColor : .primary)
                    }
                    .buttonStyle(.plain)
                    Spacer(minLength: 8)
                    Text("£").foregroundStyle(.secondary)
                    MoneyEntry(value: option.money)
                        .focused($focus, equals: moneyField)
                }
                .frame(minHeight: 38)
                .contentShape(Rectangle())
                .onTapGesture { focus = moneyField }

                DurationField(title: "Time it takes", minutes: option.minutes,
                              focus: $focus,
                              hoursField: .hours(side), minutesField: .minutes(side))

                if template.showsTimesEach {
                    HStack {
                        // A one-off can still be made of repeated units — forty items
                        // to photograph and post — and "Times a once" is not a label.
                        Text(decision.frequency.isRecurring
                             ? "Times a \(decision.frequency.shortLabel)"
                             : "How many")
                        Spacer(minLength: 8)
                        NumberEntry(value: option.timesEach)
                    }
                    .frame(minHeight: 38)
                }

                // Only once the count is above one does the cadence mean anything: at
                // one a go and a period are the same thing, and a control for a
                // distinction without a difference is just another thing to read.
                if decision.frequency.isRecurring && option.wrappedValue.timesEach != 1 {
                    moneyCadenceRow(option)
                }

                if template.showsSetup || template.showsSetupTime {
                    Divider()

                    // The one-off leg carries its own direction. Course fees go out once
                    // and the rise they buy comes in every month, and a single toggle for
                    // both makes that decision unsayable.
                    if template.showsSetup { HStack {
                        Button {
                            withAnimation(.snappy(duration: 0.15)) {
                                option.wrappedValue.setupDirection =
                                    option.wrappedValue.effectiveSetupDirection == .cost ? .receive : .cost
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(template.setupLabel)
                                Image(systemName: "arrow.left.arrow.right").font(.caption2)
                            }
                            .foregroundStyle(option.wrappedValue.effectiveSetupDirection == .receive
                                             ? Color.accentColor : .primary)
                            .multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.plain)
                        Spacer(minLength: 8)
                        if option.wrappedValue.effectiveSetupDirection == .receive {
                            Text("you get").font(.caption).foregroundStyle(.secondary)
                        }
                        Text("£").foregroundStyle(.secondary)
                        MoneyEntry(value: option.setupMoney)
                            .focused($focus, equals: .setupMoney(side))
                    }
                    .frame(minHeight: 38) }

                    if showsSetupTimeRow {
                        DurationField(title: setupTimeTitle, minutes: option.setupMinutes,
                                      focus: $focus,
                                      hoursField: .setupHours(side), minutesField: .setupMinutes(side))
                    }

                    if template.showsLifespan {
                        HStack {
                            Text("Lasts")
                            Spacer(minLength: 8)
                            Menu {
                                Button(Lifespan.foreverLabel) { option.wrappedValue.lifespanMonths = nil }
                                ForEach(Lifespan.allCases) { l in
                                    Button(l.label) { option.wrappedValue.lifespanMonths = l.months }
                                }
                            } label: {
                                HStack(spacing: 3) {
                                    Text(option.wrappedValue.lifespanMonths
                                         .map { Lifespan.nearest(to: $0).label } ?? Lifespan.foreverLabel)
                                    Image(systemName: "chevron.up.chevron.down").font(.caption2)
                                }
                            }
                        }
                        .frame(minHeight: 38)
                    }
                }
            }
        }
    }

    /// Whether the money above is a per-go price or a standing charge.
    ///
    /// The two are indistinguishable until the count rises above one, and then they
    /// are the whole decision: eight swims at £6 is £48 a month, and the membership
    /// next to it is £40 whether you go eight times or none. The app cannot tell which
    /// was typed, so it says which it assumed and lets it be changed.
    private func moneyCadenceRow(_ option: Binding<DecisionOption>) -> some View {
        HStack {
            Text("Money is")
            Spacer(minLength: 8)
            Button {
                withAnimation(.snappy(duration: 0.15)) {
                    option.wrappedValue.chargedEachTime = !option.wrappedValue.isChargedEachTime
                }
            } label: {
                HStack(spacing: 4) {
                    Text(option.wrappedValue.isChargedEachTime
                         ? "each time"
                         : "a \(decision.frequency.shortLabel)")
                    Image(systemName: "arrow.left.arrow.right").font(.caption2)
                }
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
        }
        .frame(minHeight: 38)
    }

    private var recurrenceRow: some View {
        Card {
            VStack(spacing: 0) {
                HStack {
                    Label("Happens", systemImage: "repeat")
                        .font(.subheadline)
                    Spacer()
                    Menu {
                        ForEach(Frequency.allCases) { f in
                            Button(f.label) { decision.frequency = f }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Text(decision.frequency.label)
                            Image(systemName: "chevron.up.chevron.down").font(.caption2)
                        }
                    }
                }
                .frame(minHeight: 34)

                // Only where it changes anything. For a one-off against a one-off the
                // horizon does nothing, and a control that does nothing is worse than
                // no control at all.
                if decision.frequency.isRecurring || decision.setupFrequency.isRecurring
                    || template.showsLifespan {
                    Divider().padding(.vertical, 4)
                    HStack {
                        Label("Counted over", systemImage: "calendar")
                            .font(.subheadline)
                        Spacer()
                        Menu {
                            ForEach(Horizon.allCases) { h in
                                Button(h.label) { decision.horizonMonths = h.months }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Text(Horizon.nearest(to: decision.horizonMonths).label)
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                        }
                    }
                    .frame(minHeight: 34)

                    Text(horizonNote)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 2)
                }
            }
        }
    }

    /// What to call the one-off time row.
    ///
    /// Derived rather than fixed, because on the decisions where the one-off fields
    /// recur — rent every month against a daily commute — a row labelled "One-off"
    /// was being charged twelve times a year.
    private var setupTimeTitle: String {
        if let named = template.setupTimeLabel { return named }
        return decision.setupFrequency.isRecurring
            ? "Time a \(decision.setupFrequency.shortLabel)"
            : "One-off time"
    }

    /// Why the horizon matters here, in this decision's own terms. Only said where
    /// one side is paid once and the other keeps running, which is the shape where
    /// the answer flips on this number alone.
    private var horizonNote: String {
        let boughtOutright = decision.setupFrequency == .once
            && (decision.optionA.setupMoney > 0 || decision.optionB.setupMoney > 0)
        if template.showsLifespan {
            return "How far ahead to judge them. Anything that wears out inside this gets bought again."
        }
        return boughtOutright
            ? "How long you'll keep it. What's paid once is counted once; what recurs is counted for this long."
            : "How far ahead to count. Everything recurring is totted up over this."
    }

    // MARK: - The follow-ups

    private func questionScreen(_ kind: QuestionKind) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(kind.prompt)
                            .font(.title2.weight(.bold))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(kind.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 8)

                    questionControl(kind)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(spacing: 10) {
                PrimaryButton(title: "Next", systemImage: "arrow.right") {
                    answer(kind)
                }
                Button("Good enough, show me") {
                    withAnimation { stage = .answer }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
            .padding(.bottom, 8)
            .background(.bar)
        }
    }

    @ViewBuilder
    private func questionControl(_ kind: QuestionKind) -> some View {
        switch kind {
        case .feel:
            perOption { option, _ in
                FeelPicker(feel: option.feel, anchor: store.profile.joyAnchor)
            }

        case .joyOdds:
            perOption { option, _ in
                InlineChoice(options: JoyConfidence.allCases,
                             label: \.label,
                             selection: option.joyConfidence)
            }

        case .social:
            perOption { option, _ in
                BigChoice(options: SocialValue.allCases,
                          label: \.label,
                          selection: option.socialValue)
            }

        case .canItWait:
            perOption { option, _ in
                InlineChoice(options: Deferability.allCases,
                             label: \.label,
                             selection: option.deferability)
            }

        case .displaces:
            perOption { option, _ in
                BigChoice(options: Displacement.allCases,
                          label: \.label,
                          detail: { $0.explanation },
                          selection: option.displaces)
            }

        case .health:
            perOption { option, _ in
                HealthPicker(health: option.health, anchor: store.profile.healthAnchor)
            }

        case .growth:
            perOption { option, _ in
                InlineChoice(options: GrowthEffect.allCases,
                             label: \.label,
                             selection: option.growth)
            }

        case .usage:
            perOption { option, _ in
                BigChoice(options: UsageConfidence.allCases,
                          label: \.label,
                          selection: option.usageConfidence)
            }

        case .howOften:
            perOption { option, _ in
                VStack(spacing: 0) {
                    HStack {
                        Text("Times a \(decision.frequency.shortLabel)")
                            .font(.subheadline)
                        Spacer(minLength: 8)
                        NumberEntry(value: option.timesEach)
                    }
                    // Answering here is the other way a count gets set, and the price
                    // it multiplies is two screens back by now. Same rule: only once
                    // the count is above one is there a difference to state.
                    if option.wrappedValue.timesEach != 1 {
                        moneyCadenceRow(option).font(.subheadline)
                    }
                }
            }

        case .flexibility:
            perOption { option, _ in
                InlineChoice(options: Flexibility.allCases,
                             label: \.label,
                             selection: option.flexibility)
            }

        case .usableTime:
            perOption { option, _ in
                InlineChoice(options: UsableTime.allCases,
                             label: \.label,
                             selection: option.usableTime)
            }

        case .drain:
            perOption { option, _ in
                InlineChoice(options: DrainLevel.allCases,
                             label: \.label,
                             selection: option.drain)
            }

        case .risk:
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("If it goes wrong, what happens?")
                        .font(.subheadline.weight(.semibold))
                    BigChoice(options: Stakes.allCases,
                              label: \.label,
                              selection: $decision.stakes)
                }
                // Only "it'd cost me money" has a figure to give. The other answers are
                // priced off the anchors because what they cost isn't money.
                if decision.stakes == .costsMoney {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How much would it cost?")
                            .font(.subheadline.weight(.semibold))
                        HStack {
                            Text("£").foregroundStyle(.secondary)
                            Spacer(minLength: 8)
                            // Zero means "not said" rather than "costs nothing": somebody
                            // who meant nothing would have answered the question above.
                            MoneyEntry(value: Binding(
                                get: { decision.costIfItGoesWrong ?? 0 },
                                set: { decision.costIfItGoesWrong = $0 > 0 ? $0 : nil }))
                        }
                        .frame(minHeight: 38)
                        Text("What you'd have to spend to put it right — the repair, or replacing the thing. Leave it empty and the biggest figure you've already entered is used instead.")
                            .font(.footnote).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .transition(.opacity)
                }
                if decision.stakes != .none {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("How often does each let you down?")
                            .font(.subheadline.weight(.semibold))
                        perOption(bothSides: true) { option, _ in
                            InlineChoice(options: Reliability.allCases,
                                         label: \.label,
                                         selection: option.reliability)
                        }
                    }
                    .transition(.opacity)
                }
            }

        case .repeats:
            BigChoice(options: Frequency.allCases,
                      label: \.label,
                      selection: $decision.frequency)

        case .scarcity:
            BigChoice(options: Scarcity.allCases,
                      label: \.label,
                      selection: $decision.scarcity)

        case .people:
            BigChoice(options: [1, 2, 3, 4],
                      label: { $0 == 1 ? "Just mine" : "\($0) people's" },
                      selection: $decision.peopleCount)
        }
    }

    /// Repeats a control for each side, labelled with whatever the option is called.
    ///
    /// On a "should I?" decision the second side is normally an untouched do-nothing
    /// option, and showing an empty card for it is noise. `bothSides` is for the one
    /// question where that is false: going without the cover is not doing nothing, it
    /// is the side that lets you down, and hiding it meant a warranty could only be
    /// told how often the insurer fails — never how often the machine breaks.
    @ViewBuilder
    private func perOption<Control: View>(
        bothSides: Bool = false,
        @ViewBuilder _ control: @escaping (Binding<DecisionOption>, Side) -> Control
    ) -> some View {
        VStack(spacing: 12) {
            optionBlock(option: $decision.optionA, side: .a, control: control)
            if bothSides || !decision.isYesNo || !template.secondSideIsBlank {
                optionBlock(option: $decision.optionB, side: .b, control: control)
            }
        }
    }

    @ViewBuilder
    private func optionBlock<Control: View>(
        option: Binding<DecisionOption>,
        side: Side,
        @ViewBuilder control: (Binding<DecisionOption>, Side) -> Control
    ) -> some View {
        Card {
            VStack(alignment: .leading, spacing: 10) {
                Text(Fmt.sentenceStart(VerdictText.displayName(for: side,
                                                                decision: decision,
                                                                evaluation: evaluation)))
                    .font(.subheadline.weight(.semibold))
                control(option, side)
            }
        }
    }

    // MARK: - Moving through it

    private func answer(_ kind: QuestionKind) {
        decision.answeredQuestions.append(kind.rawValue)
        advance()
    }

    private func advance() {
        // Something the records already answer. Applied before the planner runs so the
        // question it settles is never asked, and announced on the answer screen so an
        // assumption the app made on your behalf is never a silent one.
        AttentionAutomation.applySleepBoundary(to: &decision,
                                               summary: store.attention,
                                               enabled: store.profile.attentionLinkEnabled)

        if let next = QuestionPlanner.next(for: decision, profile: store.profile, rate: rate,
                                           calibration: store.timeCalibration) {
            withAnimation(.snappy(duration: 0.25)) { stage = .question(next) }
        } else {
            withAnimation(.snappy(duration: 0.25)) { stage = .answer }
        }
    }
}

/// The answer, and nothing else. Everything that explains it is one tap away
/// and stays there until it's asked for.
struct AnswerScreen: View {
    @Binding var decision: Decision
    let evaluation: Evaluation
    let notes: [String]
    let onShowWorking: () -> Void
    let onChoose: (Side) -> Void
    let onBack: () -> Void

    @State private var labelling = false
    @FocusState private var labelFocused: Bool

    /// A yes/no decision deserves a yes or a no, not the name of an option.
    private var headline: String {
        if decision.isYesNo {
            switch evaluation.winner {
            case .a: return "Yes"
            case .b: return "No"
            case .tooClose: return "Either"
            }
        }
        return VerdictText.winnerName(for: evaluation, decision: decision) ?? "Either"
    }

    /// Only shown when there's something to add to the answer itself.
    private var subtitle: String {
        switch evaluation.tiebreak {
        case .cheaper:
            return "Nothing much in it, so take the one that \(VerdictText.moneyEdge(for: evaluation))."
        case .quicker:
            return "Nothing much in it on money, so take the one that's quicker."
        case .nothingInIt:
            return "There is genuinely nothing between these. Pick either and don't give it another thought."
        case nil:
            return ""
        }
    }

    /// Which one that actually is, in the numbers just typed. Identifying the
    /// answer isn't explaining it, so this stays even on the bare screen.
    private var identifier: String? {
        guard evaluation.winner != .tooClose else { return nil }
        let option = evaluation.winner == .a ? decision.optionA : decision.optionB
        let numbers = VerdictText.fingerprint(option, frequency: decision.frequency)
        return numbers == "nothing" ? nil : numbers
    }

    /// Optional, and deliberately after the answer rather than before it — naming
    /// a decision is worth doing for the ones you'll want to find again, and pure
    /// friction for the rest.
    @ViewBuilder
    private var labelRow: some View {
        if labelling || !decision.title.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                TextField("Friday's trip into town", text: $decision.title)
                    .font(.subheadline)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($labelFocused)
                    .onSubmit { labelling = false }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        } else {
            Button {
                labelling = true
                labelFocused = true
            } label: {
                Label("Give it a name", systemImage: "tag")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Text(headline)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .lineLimit(3)
                    .padding(.horizontal, 24)

                if let identifier {
                    Text(identifier)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            if !notes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "moon.zzz")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                    if decision.sleepBoundaryNote != nil {
                        Button("It won't, actually") {
                            AttentionAutomation.undoSleepBoundary(on: &decision)
                        }
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground)))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            Spacer()

            VStack(spacing: 10) {
                labelRow

                Button(action: onShowWorking) {
                    Label("Why?", systemImage: "chevron.up")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button("Change the numbers", action: onBack)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        Button("I went with \(VerdictText.fullLabel(for: .a, decision: decision, evaluation: evaluation))") {
                            onChoose(.a)
                        }
                        if !decision.isYesNo {
                            Button("I went with \(VerdictText.fullLabel(for: .b, decision: decision, evaluation: evaluation))") {
                                onChoose(.b)
                            }
                        } else {
                            Button("I didn't") { onChoose(.b) }
                        }
                    } label: {
                        Text("Save what I did")
                            .font(.footnote.weight(.medium))
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
