import Foundation
import WidgetKit

/// Keeps the widget's snapshot in step with the app.
///
/// The widget cannot read the app's state and has no chance to recompute anything, so
/// the app writes the finished figures out and the widget only draws them. Shaped
/// like Attention's bridge of the same name, and for the same reason: written on
/// every save, but only actually written *and* WidgetKit only actually asked to
/// reload when something on screen would change. Almost no save moves the rate, and a
/// reload request per keystroke is how a widget gets throttled into staleness.
enum WidgetBridge {

    static func snapshot(store: Store) -> TimeMoneyWidgetSnapshot {
        let breakdown = store.breakdown
        var snapshot = TimeMoneyWidgetSnapshot()
        snapshot.generatedAt = Date()
        snapshot.hourlyRate = store.rate
        snapshot.effectiveEarnedRate = breakdown.effectiveEarnedRate
        snapshot.discretionaryMonthly = max(0, breakdown.discretionaryMonthly)
        snapshot.freeHoursWeekly = max(0, breakdown.freeHoursWeekly)
        snapshot.stance = breakdown.stance.shortLabel
        snapshot.usingPortfolioFigures = store.profile.portfolioLinkEnabled && store.portfolio != nil
        snapshot.awaitingReview = store.awaitingReview.count
        return snapshot
    }

    /// What was last written from this process, so an unchanged snapshot costs nothing.
    private static var lastWritten: TimeMoneyWidgetSnapshot?

    static func refresh(store: Store) {
        let fresh = snapshot(store: store)
        // `generatedAt` moves every time and is not what the widget draws, so it is
        // excluded from the comparison — otherwise nothing would ever match.
        if var previous = lastWritten {
            previous.generatedAt = fresh.generatedAt
            guard previous != fresh else { return }
        }
        guard fresh.write() else { return }
        lastWritten = fresh
        WidgetCenter.shared.reloadAllTimelines()
    }
}
