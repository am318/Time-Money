import WidgetKit
import SwiftUI
import AppIntents

@main
struct TimeMoneyWidgetBundle: WidgetBundle {
    var body: some Widget {
        RateWidget()
        if #available(iOS 18.0, *) {
            NewDecisionControl()
            RateControl()
        }
    }
}

// MARK: - The rate, without opening anything

/// What an hour of your life is worth, on the Lock Screen or the Home Screen.
///
/// The app exists to derive one number and then apply it. Putting that number where
/// it is seen without being asked for is most of the value — a rate you have to open
/// an app to remember is a rate you do not use.
struct RateWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "TimeMoneyRate", provider: RateProvider()) { entry in
            RateWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Your rate")
        .description("What an hour of your time is worth, and what you have spare.")
        .supportedFamilies([.systemSmall, .accessoryRectangular, .accessoryInline, .accessoryCircular])
    }
}

struct RateEntry: TimelineEntry {
    let date: Date
    let snapshot: TimeMoneyWidgetSnapshot?
}

struct RateProvider: TimelineProvider {
    func placeholder(in context: Context) -> RateEntry {
        RateEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (RateEntry) -> Void) {
        completion(RateEntry(date: Date(), snapshot: TimeMoneyWidgetSnapshot.read()))
    }

    /// Refreshed a few times a day. The rate moves when the profile changes, and the
    /// app asks WidgetKit to reload then — this is only a backstop so a stale figure
    /// cannot sit there indefinitely.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RateEntry>) -> Void) {
        let entry = RateEntry(date: Date(), snapshot: TimeMoneyWidgetSnapshot.read())
        let next = Calendar.current.date(byAdding: .hour, value: 6, to: Date()) ?? Date()
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

struct RateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: RateEntry

    private var snapshot: TimeMoneyWidgetSnapshot? { entry.snapshot }

    var body: some View {
        switch family {
        case .accessoryInline: Text(inlineText)
        case .accessoryCircular: circular
        case .accessoryRectangular: rectangular
        default: small
        }
    }

    // MARK: Layouts

    private var small: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("An hour of your time")
                .font(.caption2)
                .foregroundStyle(.secondary)

            if let snapshot, snapshot.hasRate {
                Text(money(snapshot.hourlyRate))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer(minLength: 0)

                if !snapshot.stance.isEmpty {
                    Text(snapshot.stance)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.tint)
                }
                Text("\(money(snapshot.discretionaryMonthly, decimals: false)) spare · \(Int(snapshot.freeHoursWeekly))h free")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            } else {
                Spacer(minLength: 0)
                Text("Set up the app to see your rate")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rectangular: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("An hour of your time").font(.caption2).foregroundStyle(.secondary)
            if let snapshot, snapshot.hasRate {
                Text(money(snapshot.hourlyRate)).font(.headline)
                Text("\(money(snapshot.discretionaryMonthly, decimals: false)) spare · \(Int(snapshot.freeHoursWeekly))h free")
                    .font(.caption2).foregroundStyle(.secondary)
            } else {
                Text("Not set up yet").font(.caption)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var circular: some View {
        VStack(spacing: 0) {
            Image(systemName: "clock.badge.checkmark").font(.caption2)
            if let snapshot, snapshot.hasRate {
                Text(money(snapshot.hourlyRate, decimals: false))
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
            }
        }
    }

    private var inlineText: String {
        guard let snapshot, snapshot.hasRate else { return "Time / Money" }
        return "\(money(snapshot.hourlyRate)) an hour"
    }

    /// Formatted here rather than carried as a string, so an accessory family can
    /// drop the pennies that would not fit.
    private func money(_ value: Double, decimals: Bool = true) -> String {
        value.formatted(
            .currency(code: "GBP")
                .locale(Locale(identifier: "en_GB"))
                .precision(.fractionLength(decimals ? 2 : 0))
        )
    }
}

// MARK: - Controls

/// The one that matters: a decision starts wherever you are, not after finding the app.
@available(iOS 18.0, *)
struct NewDecisionControl: ControlWidget {
    static let kind = "com.example.timemoney.control.newDecision"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: NewDecisionIntent()) {
                Label("Weigh it up", systemImage: "scalemass.fill")
            }
        }
        .displayName("Weigh up a decision")
        .description("Time or money — settle it where you are.")
    }
}

@available(iOS 18.0, *)
struct RateControl: ControlWidget {
    static let kind = "com.example.timemoney.control.rate"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ShowRateIntent()) {
                Label("Your rate", systemImage: "clock.badge.checkmark")
            }
        }
        .displayName("What an hour is worth")
        .description("The rate, and how it is worked out.")
    }
}
