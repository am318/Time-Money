import SwiftUI

@main
struct TimeMoneyApp: App {
    @State private var store = Store()
    @Environment(\.scenePhase) private var scenePhase

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
                store.runAutoBackupIfDue()
            }
        }
    }
}
