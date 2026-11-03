import Foundation
import UserNotifications

/// "How did it go?" notifications, one per saved decision, a day after it was made.
///
/// Opt-in, local, and self-cancelling: a reminder disappears as soon as its decision is
/// reviewed or deleted, because `sync` always rebuilds the whole set from the decisions.
/// The planning is a pure function so it can be tested without a notification centre.
enum ReviewReminders {
    static let idPrefix = "timemoney.review."
    /// iOS keeps at most 64 pending requests; the weekly nudge uses one.
    static let maxPending = 20
    /// How long after a decision it is worth asking about.
    static let delay: TimeInterval = 24 * 60 * 60
    /// Decisions older than this are left to the in-app queue, not nagged about.
    static let giveUpAfter: TimeInterval = 14 * 24 * 60 * 60
    /// Notifications never land outside these hours.
    static let earliestHour = 9
    static let latestHour = 20

    struct Item: Equatable {
        let id: UUID
        let title: String
        let fireDate: Date
        var identifier: String { ReviewReminders.idPrefix + id.uuidString }
    }

    /// When to ask: a day after the decision, moved into daytime hours.
    static func fireDate(for createdAt: Date, calendar: Calendar = .current) -> Date {
        let due = createdAt.addingTimeInterval(delay)
        let hour = calendar.component(.hour, from: due)
        if hour < earliestHour {
            return calendar.date(bySettingHour: earliestHour, minute: 0, second: 0, of: due) ?? due
        }
        if hour > latestHour {
            let next = calendar.date(byAdding: .day, value: 1, to: due) ?? due
            return calendar.date(bySettingHour: earliestHour, minute: 0, second: 0, of: next) ?? next
        }
        return due
    }

    /// The reminders that should exist right now, soonest first.
    static func plan(decisions: [Decision], enabled: Bool, now: Date = Date(),
                     calendar: Calendar = .current) -> [Item] {
        guard enabled else { return [] }
        let items: [Item] = decisions.compactMap { d in
            guard d.isSaved, d.review == nil else { return nil }
            guard now.timeIntervalSince(d.createdAt) < giveUpAfter else { return nil }
            let fire = fireDate(for: d.createdAt, calendar: calendar)
            guard fire > now else { return nil }
            let name = d.title.isEmpty ? d.scenario.template.title : d.title
            return Item(id: d.id, title: name, fireDate: fire)
        }
        return Array(items.sorted { $0.fireDate < $1.fireDate }.prefix(maxPending))
    }

    /// Replaces every pending review reminder with the current plan.
    static func sync(decisions: [Decision], enabled: Bool) {
        let centre = UNUserNotificationCenter.current()
        let items = plan(decisions: decisions, enabled: enabled)
        centre.getPendingNotificationRequests { pending in
            let stale = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
            centre.removePendingNotificationRequests(withIdentifiers: stale)
            guard enabled else { return }
            for item in items {
                let content = UNMutableNotificationContent()
                content.title = "How did it go?"
                content.body = "\(item.title): three taps to look back."
                content.sound = .default
                let parts = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: item.fireDate)
                centre.add(UNNotificationRequest(
                    identifier: item.identifier, content: content,
                    trigger: UNCalendarNotificationTrigger(dateMatching: parts, repeats: false)))
            }
        }
    }
}
