import SwiftUI

struct SettingsView: View {
    @Environment(Store.self) private var store
    @State private var editingCommitment: Commitment?
    @State private var importingAttention = false
    @State private var importingPortfolio = false

    var body: some View {
        @Bindable var store = store
        let b = store.breakdown

        Form {
            Section {
                NavigationLink(value: Route.rateDetail) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("An hour of your time")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(Fmt.money(b.personalHourlyRate))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
            } footer: {
                Text("Everything below feeds this one number. Tap it to see exactly how it's built.")
            }

            // MARK: Money in
            Section {
                Picker("How you'll tell us", selection: $store.profile.incomeMode) {
                    ForEach(IncomeMode.allCases) { mode in
                        Text(mode.label).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Text(store.profile.incomeMode == .netMonthly
                     ? "No tax maths involved. Type the figure that lands in your account and the app uses exactly that."
                     : "The app estimates tax, National Insurance, pension and student loan to work out your take-home.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                switch store.profile.incomeMode {
                case .netMonthly:
                    CurrencyField(title: "Take-home each month",
                                  value: $store.profile.netMonthlyIncome,
                                  caption: "Everything that reaches you — wages, benefits, rent from a lodger, anything else.")
                case .grossAnnual:
                    CurrencyField(title: "Gross salary", value: $store.profile.grossAnnualSalary)
                    NumberField(title: "Pension contribution", value: $store.profile.pensionPercent, unit: "%",
                                caption: "Treated as salary sacrifice.")
                    Picker("Student loan", selection: $store.profile.studentLoanPlan) {
                        ForEach(StudentLoanPlan.allCases) { plan in
                            Text(plan.label).tag(plan)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    Picker("Where you pay tax", selection: $store.profile.taxRegion) {
                        ForEach(TaxRegion.allCases) { region in
                            Text(region.label).tag(region)
                        }
                    }
                    .pickerStyle(.navigationLink)
                    let result = UKTax.takeHome(for: store.profile)
                    StatRow(label: "Estimated take-home",
                            value: Fmt.money(result.netMonthly) + " / month",
                            detail: "Tax \(Fmt.money(result.incomeTax, decimals: false)) · NI \(Fmt.money(result.nationalInsurance, decimals: false))"
                                + (result.studentLoan > 0 ? " · Loan \(Fmt.money(result.studentLoan, decimals: false))" : "")
                                + " a year",
                            emphasis: true)
                }
            } header: {
                Text("Money coming in")
            } footer: {
                if store.profile.incomeMode == .netMonthly {
                    Text("Add up everything that arrives, from wherever. The app never applies tax to this figure.")
                } else if store.profile.incomeMode == .grossAnnual {
                    Text("A 2025/26 estimate for a single PAYE job on a standard tax code. If your payslip disagrees, switch to take-home and type the real number.")
                }
            }

            // MARK: Time out
            Section {
                NumberField(title: "Paid hours a week", value: $store.profile.paidHoursPerWeek, unit: "h",
                            caption: workHoursCaption(b))
                NumberField(title: "Commuting hours a week", value: $store.profile.commuteHoursPerWeek, unit: "h",
                            caption: "Counted as work. It's your time and you don't get paid for it.")
                NumberField(title: "Sleep a night", value: $store.profile.sleepHoursPerNight, unit: "h")
                NumberField(title: "Chores and life admin a week", value: $store.profile.lifeAdminHoursPerWeek, unit: "h",
                            caption: "Cooking, cleaning, forms, the food shop.")
                if b.measuredFreeHoursWeekly != nil {
                    Text("Sleep and free hours are coming from Attention. These stay here as the fallback if that file goes away.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Where your hours go")
            } footer: {
                if let measured = b.measuredFreeHoursWeekly {
                    Text("Measured from your diary: \(Fmt.duration(hours: measured)) of free evenings a week, less \(Fmt.duration(hours: store.profile.lifeAdminHoursPerWeek)) of chores\(b.overspillHoursWeekly > 0 ? " and \(Fmt.duration(hours: b.overspillHoursWeekly)) of work that landed in them" : ""), leaves \(Fmt.duration(hours: b.freeHoursWeekly)) genuinely free. The figures above are no longer deciding this.")
                } else {
                    Text("That leaves \(Int(b.freeHoursWeekly)) genuinely free hours a week — about \(Int(b.freeHoursWeekly / 7)) a day.")
                }
            }

            AttentionSettingsSection(importing: $importingAttention)

            PortfolioSettingsSection(importing: $importingPortfolio)

            // MARK: Money out
            Section {
                CurrencyField(title: "Rent or mortgage", value: $store.profile.monthlyRent)
                CurrencyField(title: "Bills", value: $store.profile.monthlyBills,
                              caption: "Utilities, phone, transport, subscriptions, food.")
                CurrencyField(title: "Saving each month", value: $store.profile.monthlySavingsTarget)
                TextField("What you're saving for", text: $store.profile.savingsGoalName)
                CurrencyField(title: "Target amount", value: $store.profile.savingsGoalAmount,
                              caption: "Optional. Lets the app say how long a purchase sets you back.")
            } header: {
                Text("Money going out")
            } footer: {
                let d = b.discretionaryMonthly
                Text(d >= 0
                     ? "Leaves \(Fmt.money(d)) a month genuinely free to spend. That's the money every decision competes for."
                     : "You're \(Fmt.money(abs(d))) a month short of your commitments. The app will weight money heavily until that's fixed.")
            }

            // MARK: Things coming up
            Section {
                ForEach(store.profile.commitments) { commitment in
                    Button { editingCommitment = commitment } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(commitment.name.isEmpty ? "Untitled" : commitment.name)
                                    .foregroundStyle(.primary)
                                Text("\(Fmt.money(commitment.amount, decimals: false)) · \(commitment.daysAway) days")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            let short = commitment.shortfall(discretionaryMonthly: b.discretionaryMonthly)
                            Text(short > 0 ? "\(Fmt.money(short, decimals: false)) short" : "on track")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(short > 0 ? .orange : .green)
                        }
                    }
                }
                .onDelete { offsets in
                    store.profile.commitments.remove(atOffsets: offsets)
                }

                Button {
                    editingCommitment = Commitment()
                } label: {
                    Label("Add something coming up", systemImage: "plus.circle")
                }
            } header: {
                Text("Anything coming up")
            } footer: {
                Text("A trip, a gift, tickets — something specific you're putting money towards, over and above the monthly savings. If you're on course to fall short, the app values money more highly until you're not.")
            }

            PrivacySection()

            BackupSection()

            // MARK: Looking back
            Section {
                NavigationLink(value: Route.review) {
                    HStack {
                        Text("Looking back")
                        Spacer()
                        if !store.awaitingReview.isEmpty {
                            Text("\(store.awaitingReview.count)")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Toggle("Sunday evening nudge", isOn: $store.profile.weeklyReviewEnabled)
                    .onChange(of: store.profile.weeklyReviewEnabled) { _, _ in
                        store.applyWeeklyReminderSetting()
                    }
            } header: {
                Text("Reviewing decisions")
            } footer: {
                Text("Entirely optional, and nothing keeps score. It exists so the app can check its own rate against how things actually turned out.")
            }

            // MARK: Feel
            Section {
                Picker("Right now you have", selection: $store.profile.stance) {
                    ForEach(Stance.allCases) { s in
                        Text(s.label).tag(s)
                    }
                }
                .pickerStyle(.navigationLink)
                Text(store.profile.stance.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Right now you're", selection: $store.profile.standing) {
                    ForEach(Standing.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.navigationLink)
                Text(store.profile.standing.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Can you sell an extra hour?", selection: $store.profile.earningFlexibility) {
                    ForEach(EarningFlexibility.allCases) { f in
                        Text(f.label).tag(f)
                    }
                }
                .pickerStyle(.navigationLink)
                Text(store.profile.earningFlexibility.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if store.profile.earningFlexibility.usesMarginalRate {
                    CurrencyField(title: "What you charge an hour", value: $store.profile.marginalHourlyRate,
                                  caption: "After tax, roughly.")
                }
            } header: {
                Text("How it feels right now")
            }

            // MARK: Joy calibration
            Section {
                CurrencyField(title: "A memorable evening is worth", value: $store.profile.joyAnchor)
            } header: {
                Text("Putting a price on enjoyment")
            } footer: {
                Text("The most you'd happily pay for a genuinely good evening with someone you care about. Everything on the feel slider is measured against this, so top marks on the slider is worth exactly \(Fmt.money(store.profile.joyAnchor)).")
            }

            Section {
                CurrencyField(title: "One healthy choice is worth", value: $store.profile.healthAnchor)
                StatRow(label: "Which, done daily, comes to",
                        value: Fmt.money(store.profile.healthAnchor * 365, decimals: false) + " a year",
                        emphasis: true)
            } header: {
                Text("Putting a price on health")
            } footer: {
                Text("Kept deliberately small, because one walk really isn't worth much. It's the hundredth that is — so this stays quiet on one-off decisions and does the deciding on daily ones. Health is counted in full every time, unlike enjoyment, which fades with repetition.")
            }

            HiddenScenariosSection()

            Section {
                CurrencyField(title: "Learning something is worth", value: $store.profile.growthAnchor)
                NumberField(title: "Inflation a year", value: $store.profile.inflationPercent, unit: "%")
                NumberField(title: "What savings really return", value: $store.profile.savingsReturnPercent, unit: "%",
                            caption: "After inflation. Nominal 5% against 3% inflation is 2% real.")
                NumberField(title: "Bonus on money paid in", value: $store.profile.savingsBonusPercent, unit: "%",
                            caption: "25 for a Lifetime ISA. Leave at zero unless you'd really be putting this money there.")
            } header: {
                Text("The longer view")
            } footer: {
                Text("Learning is counted mostly for the first few goes — you don't learn a thing twice. Inflation grows future costs; the savings return is what a pound would have become had you not spent it, which is the honest cost of anything marginal. A bonus account makes that cost much larger, so it's worth setting if you have one.")
            }

            Section {
                Picker("This week is", selection: Binding(
                    get: { store.profile.effectiveLoad },
                    set: { level in
                        store.profile.loadLevel = level
                        store.profile.loadSetAt = level == .normal ? nil : Date()
                    }
                )) {
                    ForEach(LoadLevel.allCases) { Text($0.label).tag($0) }
                }
                Text(store.profile.effectiveLoad.explanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("How this week is going")
            } footer: {
                if b.loadIsMeasured {
                    Text("Currently read from your diary — the next seven days against your own normal — so this setting isn't being used. It takes over again if the file goes stale.")
                } else {
                    Text("For the weeks where everything lands at once. It resets itself after seven days — a pressure setting you have to remember to turn off is worse than none at all.")
                }
            }

            // MARK: Override
            Section {
                Toggle("Set my rate by hand", isOn: Binding(
                    get: { store.profile.rateOverride != nil },
                    set: { on in
                        store.profile.rateOverride = on ? b.personalHourlyRate.rounded() : nil
                    }
                ))
                if let override = store.profile.rateOverride {
                    CurrencyField(title: "An hour of my time is worth",
                                  value: Binding(get: { override },
                                                 set: { store.profile.rateOverride = $0 }))
                }
            } footer: {
                Text("If the derived number doesn't match your gut, overrule it. Your gut has information the form doesn't.")
            }
        }
        .navigationTitle("Your situation")
        .navigationBarTitleDisplayMode(.inline)
        .keyboardDoneToolbar()
        .sheet(item: $editingCommitment) { commitment in
            CommitmentEditor(commitment: commitment) { saved in
                if let index = store.profile.commitments.firstIndex(where: { $0.id == saved.id }) {
                    store.profile.commitments[index] = saved
                } else {
                    store.profile.commitments.append(saved)
                }
            }
        }
    }

    /// What the diary says about the working week, beside the figure you typed.
    ///
    /// Annotated rather than replaced. Unlike the busy-week selector — which was
    /// genuinely being overruled and rightly stopped looking live — this field is
    /// still doing two jobs: it sets the nominal rate an employer pays for a
    /// contracted hour, and it is the whole of the fallback if the file goes away.
    /// A live control doing real work should look live.
    private func workHoursCaption(_ b: RateBreakdown) -> String? {
        guard store.profile.attentionLinkEnabled, store.attention != nil else { return nil }
        if let note = b.workHoursNote { return note }
        guard let measured = b.measuredWorkHoursWeekly else { return nil }
        let weeks = b.measuredWorkWeeks
        return "Your diary makes this \(Fmt.duration(hours: measured)) a week in conventional hours, over \(weeks) recorded \(weeks == 1 ? "week" : "weeks"). That measured figure is what an hour of your life is priced against; this one still sets what work nominally pays."
    }
}


/// Adding something you're saving towards. Three fields, all forgiving.
struct CommitmentEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Commitment
    /// A date spotted in the name, until it is taken or the name changes.
    @State private var hintedDate: Date?
    let onSave: (Commitment) -> Void

    init(commitment: Commitment, onSave: @escaping (Commitment) -> Void) {
        _draft = State(initialValue: commitment)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Edinburgh trip, Mum's birthday…", text: $draft.name)
                    CurrencyField(title: "How much", value: $draft.amount)
                    // "Mum's birthday, 14 March" already says when. Offered, never
                    // taken on its own — the picker below is still the answer.
                    DateHintRow(date: hintedDate, action: "Needed by") { found in
                        draft.dueDate = found
                        hintedDate = nil
                    }
                    DatePicker("Needed by", selection: $draft.dueDate, displayedComponents: .date)
                    CurrencyField(title: "Put aside already", value: $draft.savedSoFar,
                                  caption: "Optional.")
                }
            }
            .navigationTitle("Coming up")
            .navigationBarTitleDisplayMode(.inline)
            .keyboardDoneToolbar()
            .detectingDate(in: draft.name, into: $hintedDate)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onSave(draft); dismiss() }
                        .fontWeight(.semibold)
                        .disabled(draft.amount <= 0)
                }
            }
        }
    }
}


/// Bringing back the situations you've shelved.
///
/// Only appears once there's something in it: an empty "nothing hidden" row is a
/// setting that exists to tell you it doesn't apply to you.
struct HiddenScenariosSection: View {
    @Environment(Store.self) private var store

    var body: some View {
        let hidden = store.hiddenScenarios
        if !hidden.isEmpty {
            Section {
                ForEach(hidden) { kind in
                    Button {
                        store.setHidden(false, for: kind)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: kind.template.symbol)
                                .font(.system(size: 15))
                                .foregroundStyle(.secondary)
                                .frame(width: 24)
                            Text(kind.template.title)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 8)
                            Text("Show")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                }
                Button("Show all of them again") { store.showAllScenarios() }
                    .font(.subheadline)
            } header: {
                Text("Hidden situations")
            } footer: {
                Text("Off the browse list, not gone: searching still finds them, and so does anything you've already saved. Long-press a situation to hide it.")
            }
        }
    }
}


/// Locking the app.
///
/// Hidden entirely on a device that cannot do biometrics, rather than offered and
/// then failing — a toggle that does nothing is worse than no toggle.
struct PrivacySection: View {
    @Environment(Store.self) private var store

    var body: some View {
        @Bindable var store = store
        if AppLock.isAvailable {
            Section {
                Toggle("Require \(AppLock.biometryName)", isOn: $store.profile.requireBiometricUnlock)
            } header: {
                Text("Privacy")
            } footer: {
                Text("Your pay, your bills and what you're saving are all on the home screen, and the rate is the first thing anyone sees. The app re-locks as soon as it leaves the screen rather than when you come back, because the app switcher shows whatever was there when you left.")
            }
        }
    }
}
