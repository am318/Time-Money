import AppIntents

/// What the Lock Screen controls do.
///
/// Each carries no data of its own: the system launches the app and performs the
/// intent there, which is what keeps the extension free of the whole decision model.
/// The same intents are exposed to Shortcuts, Siri and Spotlight.

/// Which screen a control asked for, read once on launch.
enum TimeMoneyRequest: String {
    case newDecision, rate, review

    static let defaultsKey = "pendingWidgetRequest"

    /// Written by the intent, read and cleared by the app. `UserDefaults` in the app
    /// group rather than a file: it is one small value, written rarely.
    static func store(_ request: TimeMoneyRequest) {
        UserDefaults(suiteName: TimeMoneyWidgetSnapshot.appGroupID)?
            .set(request.rawValue, forKey: defaultsKey)
    }

    static func take() -> TimeMoneyRequest? {
        let defaults = UserDefaults(suiteName: TimeMoneyWidgetSnapshot.appGroupID)
        guard let raw = defaults?.string(forKey: defaultsKey) else { return nil }
        defaults?.removeObject(forKey: defaultsKey)
        return TimeMoneyRequest(rawValue: raw)
    }
}

struct NewDecisionIntent: AppIntent {
    static var title: LocalizedStringResource = "Weigh up a decision"
    static var description = IntentDescription("Start a new time-versus-money decision.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        TimeMoneyRequest.store(.newDecision)
        return .result()
    }
}

struct ShowRateIntent: AppIntent {
    static var title: LocalizedStringResource = "What an hour is worth"
    static var description = IntentDescription("See the rate and how it is worked out.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        TimeMoneyRequest.store(.rate)
        return .result()
    }
}

struct ReviewDecisionsIntent: AppIntent {
    static var title: LocalizedStringResource = "Look back at a decision"
    static var description = IntentDescription("Check whether a past call was the right one.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        TimeMoneyRequest.store(.review)
        return .result()
    }
}
