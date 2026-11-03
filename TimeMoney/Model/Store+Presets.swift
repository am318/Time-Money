import Foundation
import UserNotifications

/// Which situations to put in front of you, hiding the ones you never use, and the
/// weekly and per-decision review nudges. Split out of Store.swift; no new behaviour.
extension Store {

    // MARK: - Which presets to put in front of you

    /// Ranked by recency and frequency, so the handful you actually use float to
    /// the top and the other thirty-odd stay out of the way.
    var suggestedScenarios: [ScenarioKind] {
        var score: [ScenarioKind: Double] = [:]
        let now = Date()
        for d in decisions where d.scenario != .custom {
            let ageDays = max(1, now.timeIntervalSince(d.createdAt) / 86_400)
            score[d.scenario, default: 0] += 1 / sqrt(ageDays)
        }
        let ranked = score.sorted { $0.value > $1.value }.map(\.key)
        let padding = Store.defaultSuggestions.filter { !ranked.contains($0) }
        return Array((ranked + padding).filter { !isHidden($0) }.prefix(6))
    }

    // MARK: - Hiding situations you never use

    func isHidden(_ kind: ScenarioKind) -> Bool {
        profile.hiddenScenarios?.contains(kind.rawValue) ?? false
    }

    /// In declaration order, so the settings list doesn't reshuffle itself.
    var hiddenScenarios: [ScenarioKind] {
        let hidden = Set(profile.hiddenScenarios ?? [])
        return ScenarioKind.allCases.filter { hidden.contains($0.rawValue) }
    }

    func setHidden(_ hidden: Bool, for kind: ScenarioKind) {
        // "Something else" is the way in to a blank decision. Hiding it would leave
        // someone with no route to the thing the whole app is a convenience for.
        guard kind != .custom else { return }
        var set = Set(profile.hiddenScenarios ?? [])
        if hidden { set.insert(kind.rawValue) } else { set.remove(kind.rawValue) }
        profile.hiddenScenarios = set.isEmpty ? nil : Array(set).sorted()
    }

    func showAllScenarios() { profile.hiddenScenarios = nil }

    /// The browse list, minus anything shelved. Search deliberately ignores this.
    func visibleScenarios(in family: ScenarioTemplate.Family) -> [ScenarioKind] {
        ScenarioTemplate.scenarios(in: family).filter { !isHidden($0) }
    }

    var visibleScenarioCount: Int {
        ScenarioKind.allCases.filter { $0 != .custom && !isHidden($0) }.count
    }

    static let defaultSuggestions: [ScenarioKind] = [
        .fasterVsCheaper, .eatOutVsCook, .paySomeoneElse,
        .subscription, .experience, .switchProvider
    ]

    // MARK: - Weekly nudge

    func applyWeeklyReminderSetting() {
        let centre = UNUserNotificationCenter.current()
        centre.removePendingNotificationRequests(withIdentifiers: [Store.reminderID])
        guard profile.weeklyReviewEnabled else { return }

        centre.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = "How did last week go?"
            content.body = "A couple of taps each and the app can check its own maths against how things turned out."
            content.sound = .default

            var when = DateComponents()
            when.weekday = 1        // Sunday
            when.hour = 19
            when.minute = 0

            let request = UNNotificationRequest(
                identifier: Store.reminderID,
                content: content,
                trigger: UNCalendarNotificationTrigger(dateMatching: when, repeats: true))
            centre.add(request)
        }
    }

    /// Schedules (or clears) the per-decision "how did it go?" notifications.
    func syncReviewReminders(requestPermission: Bool = false) {
        if requestPermission && profile.reviewRemindersEnabled {
            let snapshot = decisions
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in
                ReviewReminders.sync(decisions: snapshot, enabled: true)
            }
        } else {
            ReviewReminders.sync(decisions: decisions, enabled: profile.reviewRemindersEnabled)
        }
    }

    private static let reminderID = "timemoney.weekly.review"
}
