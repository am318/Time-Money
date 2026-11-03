import SwiftUI

// MARK: - Browsing the full set

struct ScenarioBrowserView: View {
    @Environment(Store.self) private var store
    @Binding var path: [Route]
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if query.isEmpty {
                    ForEach(ScenarioTemplate.Family.allCases) { family in
                        // A family everything has been hidden out of shouldn't leave
                        // its heading behind with nothing under it.
                        let kinds = store.visibleScenarios(in: family)
                        if !kinds.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label(family.rawValue, systemImage: family.symbol)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(kinds) { kind in
                                    ScenarioRow(kind: kind) { path.append(.newDecision(kind)) }
                                }
                            }
                        }
                    }
                    if !store.hiddenScenarios.isEmpty {
                        Text("\(store.hiddenScenarios.count) hidden. Search still finds them, and Settings brings them back.")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    ForEach(ScenarioTemplate.search(query)) { kind in
                        ScenarioRow(kind: kind) { path.append(.newDecision(kind)) }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .searchable(text: $query, prompt: "Search situations")
        .textInputAutocapitalization(.never)
        .autocorrectionDisabled()
        .navigationTitle("Situations")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Pieces

struct ScenarioRow: View {
    @Environment(Store.self) private var store
    let kind: ScenarioKind
    let action: () -> Void

    var body: some View {
        let t = kind.template
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: t.symbol)
                    .scaledFont(size: 16)
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    Text(t.blurb)
                        .font(.caption).foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .contextMenu { ScenarioVisibilityButton(kind: kind) }
    }
}

struct ScenarioTile: View {
    @Environment(Store.self) private var store
    let kind: ScenarioKind
    let action: () -> Void

    var body: some View {
        let t = kind.template
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: t.symbol)
                    .scaledFont(size: 17, weight: .medium)
                    .foregroundStyle(Color.accentColor)
                    .frame(height: 20)
                Text(t.title)
                    .font(.subheadline.weight(.semibold))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .contextMenu { ScenarioVisibilityButton(kind: kind) }
    }
}

struct Chip: View {
    let text: String
    var systemImage: String? = nil

    var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(text).font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8).padding(.vertical, 5)
        .background(Capsule().fill(Color.secondary.opacity(0.12)))
        .foregroundStyle(.secondary)
    }
}

struct DecisionRow: View {
    let decision: Decision

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: decision.scenario.template.symbol)
                .scaledFont(size: 15)
                .foregroundStyle(Color.accentColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(decision.title.isEmpty ? decision.scenario.template.title : decision.title)
                    .font(.subheadline.weight(.medium)).lineLimit(1)
                if let verdict = decision.recordedVerdict {
                    Text(verdict).font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Spacer(minLength: 8)
            Text(decision.createdAt, format: .dateTime.day().month(.abbreviated))
                .font(.caption).foregroundStyle(.tertiary)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }
}


/// Shelving a situation, and bringing it back.
///
/// Hidden ones stay searchable on purpose. Someone who never takes taxis shouldn't
/// have to scroll past them for a year, and someone who suddenly does shouldn't have
/// to go to settings to find out where it went.
struct ScenarioVisibilityButton: View {
    @Environment(Store.self) private var store
    let kind: ScenarioKind

    var body: some View {
        if kind != .custom {
            let hidden = store.isHidden(kind)
            Button {
                store.setHidden(!hidden, for: kind)
            } label: {
                Label(hidden ? "Show in the list again" : "Hide from the list",
                      systemImage: hidden ? "eye" : "eye.slash")
            }
        }
    }
}
