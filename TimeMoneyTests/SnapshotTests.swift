import SwiftUI
import XCTest
@testable import TimeMoney

/// Layout regression snapshots for views that do not need a Store, at the default and at
/// the largest accessibility text size, light and dark. See SnapshotSupport.swift for
/// how baselines are recorded.
@MainActor
final class SnapshotTests: XCTestCase {

    private func padded<V: View>(_ view: V) -> some View {
        view.padding(16)
    }

    func testTippingPointScale() throws {
        let view = padded(BreakEvenScale(yourRate: 6.86, breakEven: 27.10))
        try assertSnapshot(view, named: "BreakEvenScale-large", size: CGSize(width: 390, height: 110))
        try assertSnapshot(view, named: "BreakEvenScale-ax5", size: CGSize(width: 390, height: 160),
                           dynamicType: .accessibility5)
        try assertSnapshot(view, named: "BreakEvenScale-dark", size: CGSize(width: 390, height: 110),
                           scheme: .dark)
    }

    func testRateTrendChart() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let points = (0..<12).map { RatePoint(date: start.addingTimeInterval(Double($0) * 7 * 86_400),
                                              rate: 6 + Double($0 % 5) * 0.4) }
        try assertSnapshot(padded(RateTrendChart(points: points)), named: "RateTrendChart",
                           size: CGSize(width: 390, height: 200))
    }

    func testStatRowSurvivesTheLargestTextSize() throws {
        let view = padded(StatRow(label: "Money the better option avoided", value: "£1,235", emphasis: true))
        try assertSnapshot(view, named: "StatRow-large", size: CGSize(width: 390, height: 80))
        try assertSnapshot(view, named: "StatRow-ax5", size: CGSize(width: 390, height: 220),
                           dynamicType: .accessibility5)
    }
}
