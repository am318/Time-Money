import SwiftUI

/// A big, unmissable list of options. Used on every follow-up question, because
/// the whole point is that answering takes a second and needs no precision.
struct BigChoice<Value: Hashable>: View {
    let options: [Value]
    let label: (Value) -> String
    var detail: ((Value) -> String?)? = nil
    @Binding var selection: Value

    var body: some View {
        VStack(spacing: 8) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.snappy(duration: 0.15)) { selection = option }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selection == option ? "largecircle.fill.circle" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(selection == option ? Color.accentColor : Color.secondary.opacity(0.5))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(label(option))
                                .font(.body.weight(selection == option ? .semibold : .regular))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.leading)
                            if let detail = detail?(option) {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(selection == option
                                  ? Color.accentColor.opacity(0.10)
                                  : Color(.secondarySystemGroupedBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(selection == option ? Color.accentColor.opacity(0.6) : .clear,
                                          lineWidth: 1.5)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// A compact horizontal picker, for when the same question is asked of both options.
struct InlineChoice<Value: Hashable>: View {
    let options: [Value]
    let label: (Value) -> String
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options, id: \.self) { option in
                Button {
                    withAnimation(.snappy(duration: 0.15)) { selection = option }
                } label: {
                    Text(label(option))
                        .font(.footnote.weight(selection == option ? .semibold : .regular))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(selection == option
                                      ? Color.accentColor.opacity(0.16)
                                      : Color.secondary.opacity(0.09))
                        )
                        .foregroundStyle(selection == option ? Color.accentColor : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// The big primary button at the foot of every screen in the flow.
struct PrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var enabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(title).font(.headline)
                if let systemImage {
                    Image(systemName: systemImage).font(.subheadline.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(enabled ? Color.accentColor : Color.secondary.opacity(0.3))
            )
            .foregroundStyle(enabled ? Color(.systemBackground) : Color.secondary)
        }
        .disabled(!enabled)
    }
}
