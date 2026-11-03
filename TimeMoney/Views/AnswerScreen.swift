import SwiftUI

/// The answer, and nothing else. Everything that explains it is one tap away
/// and stays there until it's asked for.
struct AnswerScreen: View {
    @Binding var decision: Decision
    let evaluation: Evaluation
    let notes: [String]
    let onShowWorking: () -> Void
    let onChoose: (Side) -> Void
    let onBack: () -> Void

    @State private var labelling = false
    @FocusState private var labelFocused: Bool

    /// A yes/no decision deserves a yes or a no, not the name of an option.
    private var headline: String {
        if decision.isYesNo {
            switch evaluation.winner {
            case .a: return "Yes"
            case .b: return "No"
            case .tooClose: return "Either"
            }
        }
        return VerdictText.winnerName(for: evaluation, decision: decision) ?? "Either"
    }

    /// Only shown when there's something to add to the answer itself.
    private var subtitle: String {
        switch evaluation.tiebreak {
        case .cheaper:
            return "Nothing much in it, so take the one that \(VerdictText.moneyEdge(for: evaluation))."
        case .quicker:
            return "Nothing much in it on money, so take the one that's quicker."
        case .nothingInIt:
            return "There is genuinely nothing between these. Pick either and don't give it another thought."
        case nil:
            return ""
        }
    }

    /// Which one that actually is, in the numbers just typed. Identifying the
    /// answer isn't explaining it, so this stays even on the bare screen.
    private var identifier: String? {
        guard evaluation.winner != .tooClose else { return nil }
        let option = evaluation.winner == .a ? decision.optionA : decision.optionB
        let numbers = VerdictText.fingerprint(option, frequency: decision.frequency)
        return numbers == "nothing" ? nil : numbers
    }

    /// Optional, and deliberately after the answer rather than before it — naming
    /// a decision is worth doing for the ones you'll want to find again, and pure
    /// friction for the rest.
    @ViewBuilder
    private var labelRow: some View {
        if labelling || !decision.title.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "tag")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                TextField("Friday's trip into town", text: $decision.title)
                    .font(.subheadline)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused($labelFocused)
                    .onSubmit { labelling = false }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        } else {
            Button {
                labelling = true
                labelFocused = true
            } label: {
                Label("Give it a name", systemImage: "tag")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 14) {
                Text(headline)
                    .font(.system(size: 52, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.4)
                    .lineLimit(3)
                    .padding(.horizontal, 24)

                if let identifier {
                    Text(identifier)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
            }

            if !notes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(notes, id: \.self) { note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "moon.zzz")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                    if decision.sleepBoundaryNote != nil {
                        Button("It won't, actually") {
                            AttentionAutomation.undoSleepBoundary(on: &decision)
                        }
                        .font(.caption.weight(.medium))
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground)))
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }

            Spacer()

            VStack(spacing: 10) {
                labelRow

                Button(action: onShowWorking) {
                    Label("Why?", systemImage: "chevron.up")
                        .font(.subheadline.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color(.secondarySystemGroupedBackground)))
                }
                .buttonStyle(.plain)

                HStack(spacing: 10) {
                    Button("Change the numbers", action: onBack)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Menu {
                        Button("I went with \(VerdictText.fullLabel(for: .a, decision: decision, evaluation: evaluation))") {
                            onChoose(.a)
                        }
                        if !decision.isYesNo {
                            Button("I went with \(VerdictText.fullLabel(for: .b, decision: decision, evaluation: evaluation))") {
                                onChoose(.b)
                            }
                        } else {
                            Button("I didn't") { onChoose(.b) }
                        }
                    } label: {
                        Text("Save what I did")
                            .font(.footnote.weight(.medium))
                    }
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
