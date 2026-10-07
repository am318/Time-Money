import SwiftUI
import UniformTypeIdentifiers

/// The one switch, and everything behind it.
///
/// Deliberately a single toggle rather than a field-by-field import: the measured
/// figures only make sense together, and half of them against half of yours would
/// count some hours twice and lose others entirely. What makes it safe to be one
/// switch is that every number it changes is listed here with the days behind it.
struct AttentionSettingsSection: View {
    @Environment(Store.self) private var store
    @Binding var importing: Bool

    var body: some View {
        @Bindable var store = store
        Section {
            if store.attention != nil {
                Toggle("Use my recorded time", isOn: $store.profile.attentionLinkEnabled)

                NavigationLink(value: Route.attention) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(store.profile.attentionLinkEnabled ? "What it's using" : "What it would use")
                            .foregroundStyle(.primary)
                        if let summary = store.attention {
                            Text(freshness(summary))
                                .font(.caption)
                                .foregroundStyle(summary.forwardIsFresh ? Color.secondary : Color.orange)
                        }
                    }
                }
            } else {
                Text("No Attention backup found yet.")
                    .foregroundStyle(.secondary)
                Button {
                    importing = true
                } label: {
                    Label("Choose a backup file…", systemImage: "doc.badge.plus")
                }
            }
        } header: {
            Text("Attention")
        } footer: {
            if store.attentionIsLinkedButEmpty {
                Text("The file found doesn't carry the daily summary — it was written before Attention started including it. Export a fresh one and this will start working.")
            } else {
                Text("Attention already measures how much of your week is booked, worked and genuinely free. Switching this on uses those figures instead of the estimates above, so the rate rests on what actually happened rather than on what you meant to happen.")
            }
        }
    }

    private func freshness(_ summary: AttentionSummary) -> String {
        let days = Int(summary.ageDays.rounded())
        let age = days <= 0 ? "today" : (days == 1 ? "yesterday" : "\(days) days ago")
        guard summary.hasDigest else { return "From \(age) · no daily summary in it" }
        return "From \(age) · \(summary.knownDays) days of diary"
    }
}

/// Every measured figure, with what it rests on.
struct AttentionDetailView: View {
    @Environment(Store.self) private var store
    @State private var importing = false

    var body: some View {
        @Bindable var store = store
        List {
            if let summary = store.attention {
                Section {
                    Toggle("Use my recorded time", isOn: $store.profile.attentionLinkEnabled)
                } footer: {
                    Text(store.profile.attentionLinkEnabled
                         ? "On. The figures below are feeding your rate."
                         : "Off. The figures below are shown for comparison only and change nothing.")
                }

                Section {
                    StatRow(label: "Exported", value: age(summary))
                    if store.attentionOrigin != nil {
                        StatRow(label: "Source", value: "A file you chose")
                    }
                    StatRow(label: "Days of diary", value: "\(summary.knownDays)")
                    if !summary.hoursConfirmed {
                        Label("Attention's working hours haven't been confirmed, so anything derived from them is built on its default nine-to-five.",
                              systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if !summary.forwardIsFresh {
                        Label("More than a week old, so the week ahead isn't being used. The past still is.",
                              systemImage: "clock.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } header: {
                    Text("Where this comes from")
                }

                Section {
                    if let free = summary.freeLifeHoursPerWeek {
                        StatRow(label: "Free evening hours a week", value: Fmt.duration(hours: free), emphasis: true)
                    }
                    if let busy = summary.busyInWorkWindowMinutes {
                        StatRow(label: "Booked in a working day", value: Fmt.minutes(busy))
                    }
                    if let overspill = summary.overspillHoursPerWeek, overspill > 0 {
                        if let hours = summary.conventionalWorkHoursPerWeek {
                            StatRow(label: "Work, in conventional hours",
                                    value: Fmt.duration(hours: hours) + " a week",
                                    emphasis: true)
                        }
                        StatRow(label: "Work escaping into evenings", value: Fmt.duration(hours: overspill) + " a week")
                    }
                    if let sleep = summary.sleepHoursPerNight {
                        StatRow(label: "Sleep a night", value: Fmt.duration(hours: sleep))
                    }
                    if let line = summary.windDownStartMinutes {
                        StatRow(label: "Winding down from", value: AttentionAutomation.clockLabel(minutesFromMidnight: line))
                    }
                } header: {
                    Text("The shape of your week")
                } footer: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Free evenings are counted only in stretches of twenty minutes or more, and only on days the diary was actually read — an evening nobody looked at reports itself as entirely free, which is the one answer that would push the wrong way. Medians, not averages: one day spent in a corridor shouldn't redefine an ordinary day.")

                        if let multiplier = summary.conventionalMultiplier,
                           summary.conventionalWorkHoursPerWeek != nil {
                            Text("Your working week is your strictly timed deep work at \u{00D7}\(String(format: "%.2f", multiplier)), with timed meetings added as they are \u{2014} Attention's own conversion, over the last \(summary.conventionalWeeks) recorded weeks. Work typed in afterwards is left out, and holidays with it. That figure is what an hour of your life is priced against\(summary.conventionalConfidence < 1 ? ", though only \(Int((summary.conventionalConfidence * 100).rounded()))% of the way — your days have been varying enough lately for the rest to fall back on the hours you typed" : ""); the paid hours you typed still set what work nominally pays.")
                        } else if let refusal = summary.conventionalRefusal {
                            Text(refusal.note)
                        }
                    }
                }

                if summary.weekAhead != nil || summary.freeTodayMinutes != nil {
                    Section {
                        if let load = summary.weekAhead {
                            StatRow(label: "The week ahead", value: load.shortLabel, emphasis: true)
                        }
                        if let ratio = summary.weekAheadRatio {
                            StatRow(label: "Against your normal", value: "\(Int((ratio * 100).rounded()))%")
                        }
                        if let today = summary.freeTodayMinutes {
                            StatRow(label: "Free tonight", value: Fmt.minutes(Double(today)))
                        }
                        if let tomorrow = summary.freeTomorrowMinutes {
                            StatRow(label: "Free tomorrow evening", value: Fmt.minutes(Double(tomorrow)))
                        }
                        if summary.holidayAhead {
                            StatRow(label: "Holiday", value: "in the next week")
                        }
                    } header: {
                        Text("The week ahead")
                    } footer: {
                        Text("Compared against your own weekday and weekend normals rather than against a flat total, so a forward stretch that happens to be weekend-heavy doesn't read as a quiet week. This replaces the busy-week setting entirely while the file is fresh.")
                    }
                }

                if summary.estimateMultiplier != nil || summary.realisedShare != nil {
                    Section {
                        if let multiplier = summary.estimateMultiplier {
                            let drift = Int(((multiplier - 1) * 100).rounded())
                            StatRow(label: "Your under-an-hour jobs run",
                                    value: drift == 0 ? "about right"
                                        : (drift > 0 ? "\(drift)% over" : "\(-drift)% under"),
                                    emphasis: true)
                        }
                        if let share = summary.realisedShare {
                            StatRow(label: "Of a free working hour, worked", value: "\(Int((share * 100).rounded()))%")
                            StatRow(label: "Days behind that", value: "\(summary.timedDays)")
                        }
                    } header: {
                        Text("What Attention has learned about you")
                    } footer: {
                        Text("The first is the median of what your \"under an hour\" work actually took, against the forty minutes Attention assumes — so it is your own estimate measured against your own timer. It's applied to setup time — the getting ready, the going to fetch it — and deliberately not to the main duration, which is as often a looked-up fact as a guess. Attention throws out jobs that turned out to belong in a bigger bucket, so this understates the drift rather than inventing one. The second floors how much of an hour the app will let you claim back as usable.")
                    }
                }

                if summary.outstandingEveningIdeas > 0 || summary.bookedIdeasAhead > 0 {
                    Section {
                        StatRow(label: "Evening-sized ideas waiting", value: "\(summary.outstandingEveningIdeas)")
                        StatRow(label: "Already booked in", value: "\(summary.bookedIdeasAhead)")
                    } header: {
                        Text("What free time is for")
                    } footer: {
                        Text("Your shortlist. Buying back an evening is worth more when something is waiting for it, and that's worth saying rather than quietly assuming.")
                    }
                }
            } else {
                ContentUnavailableView {
                    Label("Nothing found", systemImage: "tray")
                } description: {
                    Text("Attention writes a backup every few days. If this app can reach the shared folder it will pick one up by itself; otherwise export one from Attention and choose it here.")
                }
            }

            Section {
                Button {
                    importing = true
                } label: {
                    Label("Choose a backup file…", systemImage: "doc.badge.plus")
                }
                if store.attentionOrigin == .imported {
                    Button(role: .destructive) {
                        store.clearAttentionImport()
                    } label: {
                        Label("Forget the file I chose", systemImage: "trash")
                            .foregroundStyle(Color.red)
                    }
                }
            } footer: {
                Text("Only ever read. This app writes nothing into Attention, and the backup carries no event titles — minute counts and spans only.")
            }
        }
        .navigationTitle("Attention")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            try? store.importAttentionFile(at: url)
        }
    }

    private func age(_ summary: AttentionSummary) -> String {
        let days = Int(summary.ageDays.rounded())
        if days <= 0 { return "today" }
        return days == 1 ? "yesterday" : "\(days) days ago"
    }
}
