import SwiftUI

/// First run. Five short pages, then the number it all produces.
struct OnboardingView: View {
    @Environment(Store.self) private var store
    @State private var page = 0

    private let lastPage = 4

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            TabView(selection: $page) {
                welcome.tag(0)
                moneyIn(store: store).tag(1)
                hours(store: store).tag(2)
                moneyOut(store: store).tag(3)
                feel(store: store).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            footer
        }
        .background(Color(.systemGroupedBackground))
        .keyboardDoneToolbar()
    }

    // MARK: Pages

    private var welcome: some View {
        page(title: "Time or money?",
             subtitle: "Every day you swap one for the other. This works out your exchange rate, then uses it to settle the argument quickly.") {
            VStack(alignment: .leading, spacing: 14) {
                bullet("clock", "An hour of your life gets a price")
                bullet("scalemass", "Any two options get weighed against it")
                bullet("heart", "And what actually makes you happy counts too")
                Spacer(minLength: 0)
                Text("Four short questions. Under a minute.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func moneyIn(store: Store) -> some View {
        @Bindable var store = store
        return page(title: "What comes in",
                    subtitle: "Take-home is the simpler one: no tax maths, just the figure that arrives.") {
            VStack(spacing: 16) {
                Picker("", selection: $store.profile.incomeMode) {
                    ForEach(IncomeMode.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                Card {
                    VStack(spacing: 12) {
                        if store.profile.incomeMode == .netMonthly {
                            CurrencyField(title: "Take-home each month", value: $store.profile.netMonthlyIncome)
                        } else {
                            CurrencyField(title: "Gross salary a year", value: $store.profile.grossAnnualSalary)
                            Divider()
                            NumberField(title: "Pension", value: $store.profile.pensionPercent, unit: "%")
                            Divider()
                            Picker("Student loan", selection: $store.profile.studentLoanPlan) {
                                ForEach(StudentLoanPlan.allCases) { Text($0.label).tag($0) }
                            }
                            Divider()
                            StatRow(label: "That's about",
                                    value: Fmt.money(UKTax.takeHome(for: store.profile).netMonthly) + " / month",
                                    emphasis: true)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func hours(store: Store) -> some View {
        @Bindable var store = store
        return page(title: "Where the hours go",
                    subtitle: "Commuting counts. It's your time and nobody pays you for it.") {
            VStack(spacing: 16) {
                Card {
                    VStack(spacing: 12) {
                        NumberField(title: "Paid hours a week", value: $store.profile.paidHoursPerWeek, unit: "h")
                        Divider()
                        NumberField(title: "Commuting a week", value: $store.profile.commuteHoursPerWeek, unit: "h")
                    }
                }
                Card {
                    let free = store.breakdown.freeHoursWeekly
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(Int(free)) free hours a week")
                            .font(.title3.weight(.semibold))
                        Text("After sleep, work and the usual chores. Sleep and chores are assumed — adjust them later if yours are unusual.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func moneyOut(store: Store) -> some View {
        @Bindable var store = store
        return page(title: "What's already spoken for",
                    subtitle: "What's left over is the money every decision competes for.") {
            VStack(spacing: 16) {
                Card {
                    VStack(spacing: 12) {
                        CurrencyField(title: "Rent or mortgage", value: $store.profile.monthlyRent)
                        Divider()
                        CurrencyField(title: "Bills and food", value: $store.profile.monthlyBills)
                        Divider()
                        CurrencyField(title: "Saving each month", value: $store.profile.monthlySavingsTarget)
                    }
                }
                Card {
                    let d = store.breakdown.discretionaryMonthly
                    VStack(alignment: .leading, spacing: 4) {
                        Text(Fmt.money(d, decimals: false) + " free each month")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(d < 0 ? .red : .primary)
                        Text(d < 0
                             ? "You're short. The app will lean hard towards saving money."
                             : "Spread over your free hours, that's \(Fmt.rate(store.breakdown.leisureRate)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    private func feel(store: Store) -> some View {
        @Bindable var store = store
        return page(title: "Which one's tight?",
                    subtitle: "Two people with identical finances can value an hour completely differently. This is the part only you know.") {
            VStack(spacing: 16) {
                Card {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(Stance.allCases) { s in
                            Button {
                                store.profile.stance = s
                            } label: {
                                HStack {
                                    Image(systemName: store.profile.stance == s ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(store.profile.stance == s ? Color.accentColor : .secondary)
                                    Text(s.label)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Your rate")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(Fmt.money(store.breakdown.personalHourlyRate))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("You can change any of this later, and overrule it entirely if it doesn't feel right.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }

    // MARK: Chrome

    @ViewBuilder
    private func page<Content: View>(title: String, subtitle: String, @ViewBuilder content: () -> Content) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.largeTitle.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 40)

                content()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func bullet(_ symbol: String, _ text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 17))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            Text(text)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0...lastPage, id: \.self) { i in
                    Capsule()
                        .fill(i == page ? Color.accentColor : Color.secondary.opacity(0.25))
                        .frame(width: i == page ? 20 : 6, height: 6)
                        .animation(.snappy(duration: 0.2), value: page)
                }
            }

            Button {
                if page < lastPage {
                    withAnimation { page += 1 }
                } else {
                    store.profile.hasCompletedSetup = true
                    store.runAutoBackupIfDue()
                    store.saveNow()
                }
            } label: {
                Text(page < lastPage ? "Next" : "Start deciding")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.accentColor))
                    .foregroundStyle(Color(.systemBackground))
            }

            Button("Skip, I'll set it up later") {
                store.profile.hasCompletedSetup = true
                store.runAutoBackupIfDue()
                store.saveNow()
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
            .opacity(page == 0 ? 1 : 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 12)
    }
}
