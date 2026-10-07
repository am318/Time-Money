import SwiftUI
import UniformTypeIdentifiers

/// The Portfolio link, in Settings. Shaped exactly like the Attention one, because
/// they answer the same question about two different files and a switch whose
/// behaviour you have to learn twice is a switch you will not trust.
struct PortfolioSettingsSection: View {
    @Environment(Store.self) private var store
    @Binding var importing: Bool

    var body: some View {
        @Bindable var store = store
        Section {
            if store.portfolio != nil {
                Toggle("Use my Portfolio figures", isOn: $store.profile.portfolioLinkEnabled)

                NavigationLink(value: Route.portfolio) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.profile.portfolioLinkEnabled ? "What it's using" : "What it would use")
                            .foregroundStyle(.primary)
                        if let calibration = portfolioCalibration, let age = calibration.ageDescription {
                            Text("From \(age)\(originNote)")
                                .font(.caption)
                                .foregroundStyle(isStale ? Color.orange : Color.secondary)
                        }
                    }
                }
                Button {
                    var profile = store.profile
                    MoneyCalibration(snapshot: store.portfolio).seed(into: &profile)
                    store.profile = profile
                } label: {
                    Label("Fill in my settings from Portfolio", systemImage: "square.and.arrow.down")
                }
            } else {
                Text("No Portfolio snapshot found yet.")
                    .foregroundStyle(.secondary)
                Button {
                    importing = true
                } label: {
                    Label("Choose a snapshot file…", systemImage: "doc.badge.plus")
                }
            }
        } header: {
            Text("Portfolio")
        } footer: {
            if store.portfolioIsLinkedButEmpty {
                Text("The link is on but no snapshot has been found. Switch sharing on in Portfolio, or hand a file over here.")
            } else {
                Text("Portfolio already knows your pay, your actual bills, what the plan puts away each month, and whether the next pound saved earns a Lifetime ISA bonus. Switching this on uses those figures instead of the ones typed above, so a decision rests on what your money is really doing. Filling the settings in copies them across once and leaves them editable.")
            }
        }
    }

    /// Always built, even when the link is off, so the screen can show what it *would*
    /// use before you commit to it.
    private var portfolioCalibration: MoneyCalibration? {
        guard store.portfolio != nil else { return nil }
        return MoneyCalibration(snapshot: store.portfolio)
    }

    private var isStale: Bool {
        (portfolioCalibration?.ageInDays ?? 0) > 14
    }

    private var originNote: String {
        guard let origin = store.portfolioOrigin else { return "" }
        return origin == .imported ? " · from a file you shared" : ""
    }
}

/// What the link is actually changing, itemised. A figure you can't interrogate is a
/// figure you won't act on — the same principle the rate breakdown is built on.
struct PortfolioDetailView: View {
    @Environment(Store.self) private var store

    private var calibration: MoneyCalibration {
        MoneyCalibration(snapshot: store.portfolio)
    }

    var body: some View {
        List {
            if let age = calibration.ageDescription {
                Section {
                    LabeledContent("Written", value: age)
                    if let name = store.portfolioFileName {
                        LabeledContent("File", value: name)
                    }
                    if let origin = store.portfolioOrigin {
                        LabeledContent("Source", value: origin.label)
                    }
                } footer: {
                    if (calibration.ageInDays ?? 0) > 14 {
                        Text("This is getting old. Open Portfolio and it will write a fresh one.")
                    }
                }
            }

            Section("Income") {
                row("Take-home a month", calibration.netMonthlyIncome)
                row("Gross a year", calibration.grossAnnualSalary)
                if let pension = calibration.pensionPercent {
                    LabeledContent("Into a pension", value: String(format: "%.1f%%", pension))
                }
                if let plan = calibration.studentLoanPlan {
                    LabeledContent("Student loan", value: plan.label)
                }
            }

            Section {
                row("Bills and sinking funds", calibration.committedOutgoings)
                row("Of which housing", calibration.monthlyRent)
                row("Savings target", calibration.monthlySavingsTarget)
                row("Safe to spend", calibration.discretionary)
                row("Of which the floor", calibration.discretionaryFloor)
                row("Held back from the goal", calibration.heldBackByFloor)
                row("A London life costs", calibration.livingWageFloorMonthly)
                row("Room above that", calibration.headroomAboveLivingWage)
            } header: {
                Text("Committed each month")
            } footer: {
                Text("Safe to spend counts only changes Portfolio has confirmed, so a raise you are hoping for cannot widen it. The floor is a level you have actually lived on, which the budget protects even where the goal would take every penny. The London Living Wage is the other kind of floor: not what you have lived on, but what an independent calculation says living takes — so a commitment can be weighed against it without the answer depending on how frugal last year happened to be.")
            }

            Section {
                if let bonus = calibration.savingsBonusPercent {
                    LabeledContent("Bonus on the next pound", value: "\(Int(bonus))%")
                }
                if let rate = calibration.savingsReturnPercent {
                    LabeledContent("Return after inflation", value: String(format: "%.1f%%", rate))
                }
            } header: {
                Text("What a pound not spent does")
            } footer: {
                if let reason = calibration.bonusReason {
                    Text(reason)
                }
            }

            if let slack = calibration.hasSlack {
                Section {
                    LabeledContent("Genuinely spare money", value: slack ? "Yes" : "No")
                    if let goal = calibration.goalName, let year = calibration.goalTargetYear {
                        LabeledContent(goal, value: String(year))
                    }
                    row("What it needs", calibration.savingsGoalAmount)
                    if let onTrack = calibration.isOnTrack {
                        LabeledContent("On track", value: onTrack ? "Yes" : "Not yet")
                    }
                } header: {
                    Text("Standing")
                } footer: {
                    Text("Only the money half. Whether you feel ahead takes in work and everything else, and stays yours to say — this just stops 'ahead' loosening things when the money isn't there.")
                }
            }

            if let previous = calibration.previousNetMonthlyIncome,
               let changed = calibration.incomeChangedAt,
               calibration.netMonthlyIncome ?? 0 > previous {
                Section {
                    LabeledContent(calibration.incomeChangeName ?? "Pay rise",
                                   value: changed.formatted(.dateTime.month(.abbreviated).year()))
                    LabeledContent("Was", value: Fmt.money(previous))
                    LabeledContent("Now", value: Fmt.money(calibration.netMonthlyIncome ?? 0))
                } header: {
                    Text("What changed")
                } footer: {
                    Text("A dated record of a change that actually happened, which is a better answer than noticing a figure here had moved — that also happens when a typo is corrected. Keeping savings in step with pay is measured from this.")
                }
            }

            if accuracy.isUsable {
                Section {
                    LabeledContent("Decisions booked", value: "\(accuracy.spent) of \(accuracy.counted)")
                    LabeledContent("You estimated", value: Fmt.money(accuracy.totalEstimated))
                    LabeledContent("Actually charged", value: Fmt.money(accuracy.totalActual))
                    if accuracy.isNoteworthy {
                        LabeledContent(
                            accuracy.overspendShare > 0 ? "Under-estimated by" : "Over-estimated by",
                            value: String(format: "%.0f%%", abs(accuracy.overspendShare) * 100)
                        )
                    }
                } header: {
                    Text("How good your estimates are")
                } footer: {
                    Text(accuracyFooter)
                }
            }

            if !calibration.commitments.isEmpty {
                Section {
                    ForEach(calibration.commitments) { commitment in
                        LabeledContent(commitment.name) {
                            Text(Fmt.money(commitment.amount))
                        }
                    }
                } header: {
                    Text("Sinking funds")
                } footer: {
                    Text("Added to anything you've listed here rather than replacing it.")
                }
            }
        }
        .navigationTitle("From Portfolio")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var accuracy: EstimateAccuracy { EstimateAccuracy.measure(calibration.settled) }

    /// Every verdict this app reaches rests on two figures typed into a form, and
    /// until Portfolio started booking them nothing had ever checked one.
    private var accuracyFooter: String {
        guard accuracy.isNoteworthy else {
            return "Across \(accuracy.spent) purchases Portfolio has booked, what you typed in here has been close to what was actually charged. Every verdict rests on those figures, so this is the one thing that checks them."
        }
        if accuracy.overspendShare > 0 {
            return "Things have cost about \(String(format: "%.0f%%", accuracy.overspendShare * 100)) more than you expected. Worth knowing when you type the next figure in: a verdict is only as good as the number underneath it."
        }
        return "Things have cost about \(String(format: "%.0f%%", -accuracy.overspendShare * 100)) less than you expected, so options are being judged a little harshly on the money side."
    }

    @ViewBuilder
    private func row(_ label: String, _ value: Double?) -> some View {
        if let value {
            LabeledContent(label, value: Fmt.money(value))
        }
    }
}
