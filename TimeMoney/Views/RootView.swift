import SwiftUI

enum Route: Hashable {
    case newDecision(ScenarioKind)
    case savedDecision(UUID)
    case rateDetail
    case settings
    case history
    case browse
    case review
    case inContext
    case attention
    case portfolio
}

struct RootView: View {
    @Environment(Store.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @State private var path: [Route] = []
    @State private var lock = AppLock()

    private var isLocked: Bool { store.profile.requireBiometricUnlock && !lock.isUnlocked }

    var body: some View {
        Group {
            if isLocked { LockedView(lock: lock) } else { content }
        }
        .task(id: store.profile.requireBiometricUnlock) { await unlockIfNeeded() }
        .onChange(of: scenePhase) { _, phase in
            // Re-locked as it leaves the screen, not when it comes back: the app
            // switcher shows a snapshot of whatever was on screen when you left.
            if phase == .background, store.profile.requireBiometricUnlock { lock.lock() }
            if phase == .active {
                Task { await unlockIfNeeded() }
                openPendingRequest()
            }
        }
    }

    private func unlockIfNeeded() async {
        guard store.profile.requireBiometricUnlock, !lock.isUnlocked else { return }
        await lock.unlock()
    }

    /// A Lock Screen control, Shortcut or Siri phrase asked for a screen.
    ///
    /// Read once and cleared, on launch and on every return to the foreground: the
    /// intent runs in another process and leaves a note, and a note nobody clears is
    /// a screen that reopens itself every time you come back to the app.
    private func openPendingRequest() {
        guard let request = TimeMoneyRequest.take() else { return }
        switch request {
        case .newDecision:
            guard path.last != .newDecision(.custom) else { return }
            path.append(.newDecision(.custom))
        case .rate:
            guard path.last != .rateDetail else { return }
            path.append(.rateDetail)
        case .review:
            guard path.last != .review else { return }
            path.append(.review)
        }
    }

    private var content: some View {
        NavigationStack(path: $path) {
            HomeView(path: $path)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .newDecision(let kind):
                        DecisionFlowView(decision: Decision.make(from: kind))
                    case .savedDecision(let id):
                        if let decision = store.decisions.first(where: { $0.id == id }) {
                            DecisionFlowView(decision: decision, startAt: .answer)
                        } else {
                            ContentUnavailableView("Not found", systemImage: "questionmark.folder")
                        }
                    case .rateDetail:  RateDetailView()
                    case .settings:    SettingsView()
                    case .history:     HistoryView(path: $path)
                    case .browse:      ScenarioBrowserView(path: $path)
                    case .review:      ReviewView()
                    case .inContext:   InContextView()
                    case .attention:   AttentionDetailView()
                    case .portfolio:   PortfolioDetailView()
                    }
                }
        }
        .fullScreenCover(isPresented: .constant(!store.profile.hasCompletedSetup)) {
            OnboardingView()
        }
        .onAppear {
            WidgetBridge.refresh(store: store)
            openPendingRequest()
        }
    }
}
