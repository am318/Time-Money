import AppIntents
import Foundation

/// The logic behind the "quick answer" Shortcut, kept apart from the intent so it can
/// be tested without Siri.
enum QuickAnswer {

    /// Faster-but-dearer against slower-but-cheaper, answered with the saved profile.
    static func answer(fasterName: String, fasterPrice: Double, fasterMinutes: Double,
                       cheaperName: String, cheaperPrice: Double, cheaperMinutes: Double,
                       profile: Profile) -> String {
        var decision = Decision()
        decision.scenario = .fasterVsCheaper
        decision.optionA.name = fasterName
        decision.optionA.money = fasterPrice
        decision.optionA.minutes = fasterMinutes
        decision.optionB.name = cheaperName
        decision.optionB.money = cheaperPrice
        decision.optionB.minutes = cheaperMinutes

        let evaluation = DecisionEngine.evaluate(decision, profile: profile)
        let headline = VerdictText.headline(for: evaluation, decision: decision)
        if let tipping = VerdictText.breakEven(for: evaluation, decision: decision) {
            return "\(headline). \(tipping)"
        }
        return "\(headline). An hour of your time is worth \(Fmt.rate(evaluation.rate)) to you right now."
    }

    /// The profile as the app last saved it, or the defaults on a fresh install.
    static func savedProfile() -> Profile {
        let data = try? Data(contentsOf: Store.defaultURL())
        if case .loaded(let state) = Store.PersistedState.load(from: data) { return state.profile }
        return Profile()
    }
}

/// "Should I take the Uber?" answered by Siri or a Shortcut, without opening the app.
struct QuickAnswerIntent: AppIntent {
    static var title: LocalizedStringResource = "Quick answer"
    static var description = IntentDescription(
        "Compare a faster, dearer option with a slower, cheaper one, using what an hour of your time is worth.")
    static var openAppWhenRun = false

    @Parameter(title: "Faster option", default: "Taxi")
    var fasterName: String
    @Parameter(title: "Faster option's price")
    var fasterPrice: Double
    @Parameter(title: "Faster option's minutes")
    var fasterMinutes: Double
    @Parameter(title: "Cheaper option", default: "Bus")
    var cheaperName: String
    @Parameter(title: "Cheaper option's price")
    var cheaperPrice: Double
    @Parameter(title: "Cheaper option's minutes")
    var cheaperMinutes: Double

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$fasterName) at \(\.$fasterPrice) in \(\.$fasterMinutes) min, or \(\.$cheaperName) at \(\.$cheaperPrice) in \(\.$cheaperMinutes) min")
    }

    func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let text = QuickAnswer.answer(
            fasterName: fasterName, fasterPrice: fasterPrice, fasterMinutes: fasterMinutes,
            cheaperName: cheaperName, cheaperPrice: cheaperPrice, cheaperMinutes: cheaperMinutes,
            profile: QuickAnswer.savedProfile())
        return .result(value: text, dialog: IntentDialog(stringLiteral: text))
    }
}

/// What Siri, Spotlight and the Shortcuts gallery offer without any set-up.
struct TimeMoneyShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: NewDecisionIntent(),
            phrases: ["Weigh up a decision in \(.applicationName)",
                      "New decision in \(.applicationName)"],
            shortTitle: "New decision",
            systemImageName: "scalemass")
        AppShortcut(
            intent: ShowRateIntent(),
            phrases: ["What is my hour worth in \(.applicationName)",
                      "Show my rate in \(.applicationName)"],
            shortTitle: "My rate",
            systemImageName: "clock")
        AppShortcut(
            intent: ReviewDecisionsIntent(),
            phrases: ["Look back in \(.applicationName)",
                      "Review my decisions in \(.applicationName)"],
            shortTitle: "Look back",
            systemImageName: "arrow.uturn.backward")
    }
}
