import SwiftUI

@main
struct TimeMoneyApp: App {
    @State private var store = TimeMoneyApp.makeStore()
    @Environment(\.scenePhase) private var scenePhase

    /// UI tests launch with `-uitest-demo`: a throwaway state file and the demo profile
    /// already set up, so a test never touches real data or has to click through
    /// onboarding.
    private static func makeStore() -> Store {
        guard ProcessInfo.processInfo.arguments.contains("-uitest-demo") else { return Store() }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("uitest-state-\(UUID().uuidString).json")
        let store = Store(fileURL: url)
        store.profile.hasCompletedSetup = true
        return store
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                store.saveNow()
            } else {
                // Attention writes a snapshot every few days. Coming back to the app is
                // the only moment worth looking, and it costs one file read.
                store.refreshAttention()
                store.settleSavingsBaseline()
                store.recordRatePoint()
                store.runAutoBackupIfDue()
            }
        }
    }
}
