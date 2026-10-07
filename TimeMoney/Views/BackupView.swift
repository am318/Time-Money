import SwiftUI
import UniformTypeIdentifiers

/// Getting everything out, and putting it back.
///
/// Worth having for a reason specific to this app: it signs with a development
/// profile that stops working after a week, so reinstalling is routine. A year of
/// decisions and a carefully tuned set of anchors shouldn't live only in a container
/// that a reinstall can take away.
struct BackupSection: View {
    @Environment(Store.self) private var store

    @State private var exported: URL?
    @State private var importing = false
    @State private var pending: TimeMoneyBackup?
    @State private var failure: String?
    @State private var snapshots: [AutoBackup.Snapshot] = []
    @State private var lastSnapshot: Date?
    @State private var snapshotResult: String?

    var body: some View {
        automaticSection
        manualSection
    }

    // MARK: - The one you don't have to remember

    @ViewBuilder
    private var automaticSection: some View {
        @Bindable var store = store
        Section {
            Picker("Snapshot automatically", selection: $store.profile.autoBackupEveryDays) {
                Text("Off").tag(0)
                Text("Daily").tag(1)
                Text("Every 3 days").tag(3)
                Text("Weekly").tag(7)
                Text("Fortnightly").tag(14)
            }
            .pickerStyle(.navigationLink)

            if store.profile.autoBackupEveryDays > 0 {
                StatRow(label: "Last snapshot", value: lastSnapshotLabel)
            }

            Button {
                switch store.snapshotNow() {
                case .wrote(let url): snapshotResult = "Saved \(url.lastPathComponent)."
                case .unchanged: snapshotResult = "Nothing has changed since the last one."
                case .failed: snapshotResult = "Couldn't write a snapshot."
                case .notDue, .off: snapshotResult = nil
                }
                reload()
            } label: {
                Label("Snapshot now", systemImage: "clock.arrow.circlepath")
            }

            if let snapshotResult {
                Text(snapshotResult).font(.caption).foregroundStyle(.secondary)
            }

            ForEach(snapshots) { snapshot in
                Button {
                    pending = try? store.inspectBackup(at: snapshot.url)
                    if pending == nil { failure = BackupError.unreadable.localizedDescription }
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(snapshot.name)
                            .foregroundStyle(.primary)
                        Text("\(snapshot.decisions) decision\(snapshot.decisions == 1 ? "" : "s") · \(snapshot.bytes / 1024 == 0 ? "under 1" : String(snapshot.bytes / 1024)) KB")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .onDelete { offsets in
                for index in offsets where snapshots.indices.contains(index) {
                    AutoBackup.delete(snapshots[index])
                }
                reload()
            }
        } header: {
            Text("Automatic snapshots")
        } footer: {
            Text("Written when the app opens and one is due, keeping the last \(AutoBackup.generationsKept). A snapshot identical to the one before it isn't written, so those \(AutoBackup.generationsKept) are \(AutoBackup.generationsKept) different states rather than \(AutoBackup.generationsKept) copies of today. Tap one to restore it. They live inside the app, so they survive a rebuild but not deleting it — which is what the copy below is for.")
        }
    }

    private var lastSnapshotLabel: String {
        guard let lastSnapshot else { return "None yet" }
        let days = AutoBackup.dayDifference(from: lastSnapshot, to: Date())
        if days <= 0 { return "Today" }
        return days == 1 ? "Yesterday" : "\(days) days ago"
    }

    // MARK: - The one that leaves the phone

    @ViewBuilder
    private var manualSection: some View {
        Section {
            if let exported {
                ShareLink(item: exported) {
                    Label("Save a copy…", systemImage: "square.and.arrow.up")
                }
            } else {
                Button {
                    prepare()
                } label: {
                    Label("Save a copy…", systemImage: "square.and.arrow.up")
                }
            }

            Button {
                importing = true
            } label: {
                Label("Restore from a file…", systemImage: "arrow.counterclockwise")
            }
        } header: {
            Text("Backing it up")
        } footer: {
            Text("One file with your situation, your anchors and every decision you've saved. Plain JSON, readable by anything — worth keeping somewhere that isn't this phone, since reinstalling the app starts you over.")
        }
        .onAppear { prepare(); reload() }
        .onChange(of: store.decisions.count) { _, _ in prepare() }
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case .success(let url) = result else { return }
            do {
                pending = try store.inspectBackup(at: url)
            } catch {
                failure = error.localizedDescription
            }
        }
        .alert("Restore this backup?", isPresented: Binding(
            get: { pending != nil },
            set: { if !$0 { pending = nil } }
        ), presenting: pending) { backup in
            Button("Replace everything", role: .destructive) {
                store.restore(from: backup)
                pending = nil
                prepare()
                reload()
            }
            Button("Cancel", role: .cancel) { pending = nil }
        } message: { backup in
            let s = backup.summary
            Text("Taken \(s.age), with \(s.decisions) decision\(s.decisions == 1 ? "" : "s") and an hourly rate of \(Fmt.rate(s.rate)).\n\nThis replaces everything currently in the app, including the \(store.decisions.count) decision\(store.decisions.count == 1 ? "" : "s") you have now. It can't be undone.")
        }
        .alert("Couldn't read that", isPresented: Binding(
            get: { failure != nil },
            set: { if !$0 { failure = nil } }
        )) {
            Button("OK", role: .cancel) { failure = nil }
        } message: {
            Text(failure ?? "")
        }
    }

    /// Written ahead of the tap so the share sheet has something to offer the moment
    /// it opens, rather than a spinner.
    private func prepare() {
        exported = try? store.writeBackup()
    }

    private func reload() {
        snapshots = store.snapshots
        lastSnapshot = store.lastSnapshotDate
    }
}
