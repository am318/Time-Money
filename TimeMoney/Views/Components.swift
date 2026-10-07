import SwiftUI

// MARK: - Number entry

/// Selects what's already in a field the moment it takes focus, so typing replaces
/// the old figure instead of running on from it.
///
/// Without this, changing a salary from 38000 to 46000 means tapping the field and
/// then deleting five digits one at a time — and tapping in the wrong place gives
/// you 3800046000, which the app will cheerfully price. Every field here holds a
/// number you are far more likely to be replacing than extending.
struct SelectAllOnFocus: ViewModifier {
    let focused: Bool

    func body(content: Content) -> some View {
        content.onChange(of: focused) { _, isFocused in
            guard isFocused else { return }
            // A turn later: the field has to be first responder before it can be told
            // to select anything.
            DispatchQueue.main.async {
                UIApplication.shared.sendAction(#selector(UIResponder.selectAll(_:)),
                                                to: nil, from: nil, for: nil)
            }
        }
    }
}

extension View {
    func selectAllOnFocus(_ focused: Bool) -> some View {
        modifier(SelectAllOnFocus(focused: focused))
    }
}

/// A form row for entering an amount of money. Shows an empty field rather than a
/// stubborn "0" that has to be deleted before anything can be typed.
struct CurrencyField: View {
    let title: String
    @Binding var value: Double
    var caption: String? = nil
    var placeholder: String = "0"

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                Text("£")
                    .foregroundStyle(.secondary)
                TextField(placeholder, text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 110)
                    .monospacedDigit()
                    .focused($focused)
            }
            .frame(minHeight: 34)
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            if let caption {
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { text = Self.display(value) }
        .selectAllOnFocus(focused)
        .onChange(of: text) { _, new in
            value = Self.parse(new)
        }
        .onChange(of: value) { _, new in
            if Self.parse(text) != new { text = Self.display(new) }
        }
    }

    static func parse(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: "")
                .replacingOccurrences(of: "£", with: "")) ?? 0
    }

    static func display(_ v: Double) -> String {
        guard v != 0 else { return "" }
        return v.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(v))
            : String(format: "%.2f", v)
    }
}

/// A plain number row, for hours per week and similar.
struct NumberField: View {
    let title: String
    @Binding var value: Double
    var unit: String = ""
    var caption: String? = nil

    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer(minLength: 8)
                TextField("0", text: $text)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 70)
                    .monospacedDigit()
                    .focused($focused)
                if !unit.isEmpty {
                    Text(unit).foregroundStyle(.secondary)
                }
            }
            .frame(minHeight: 34)
            .contentShape(Rectangle())
            .onTapGesture { focused = true }
            if let caption {
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { text = CurrencyField.display(value) }
        .selectAllOnFocus(focused)
        .onChange(of: text) { _, new in value = CurrencyField.parse(new) }
        .onChange(of: value) { _, new in
            if CurrencyField.parse(text) != new { text = CurrencyField.display(new) }
        }
    }
}

/// Hours and minutes side by side. People think in "twenty minutes", not "0.33 hours".
/// Every number box on the entry form, in the order a thumb should travel through them.
///
/// One shared identity for all of them, so the keyboard can offer a next and a previous
/// instead of making somebody dismiss it and aim at the following box — eight fields on
/// a two-sided decision with a one-off leg, and eight separate taps to reach them.
enum EntryField: Hashable {
    case money(Side), hours(Side), minutes(Side)
    case setupMoney(Side), setupHours(Side), setupMinutes(Side)
}

struct DurationField: View {
    let title: String
    @Binding var minutes: Double
    var caption: String? = nil
    /// The form's own focus, so these boxes sit in its tab order rather than their own.
    var focus: FocusState<EntryField?>.Binding
    let hoursField: EntryField
    let minutesField: EntryField

    @State private var hoursText: String = ""
    @State private var minutesText: String = ""
    @State private var syncing = false

    private var isFocused: Bool {
        focus.wrappedValue == hoursField || focus.wrappedValue == minutesField
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 2) {
                Text(title)
                Spacer(minLength: 8)
                TextField("0", text: $hoursText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 42)
                    .monospacedDigit()
                    .focused(focus, equals: hoursField)
                Text("h").foregroundStyle(.secondary).padding(.trailing, 8)
                TextField("0", text: $minutesText)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 42)
                    .monospacedDigit()
                    .focused(focus, equals: minutesField)
                Text("m").foregroundStyle(.secondary)
            }
            .frame(minHeight: 38)
            .contentShape(Rectangle())
            .onTapGesture { focus.wrappedValue = minutesField }
            if let caption {
                Text(caption).font(.caption).foregroundStyle(.secondary)
            }
        }
        .onAppear { push(minutes) }
        .selectAllOnFocus(isFocused)
        .onChange(of: hoursText) { _, _ in pull() }
        .onChange(of: minutesText) { _, _ in pull() }
        .onChange(of: minutes) { _, new in
            guard !syncing else { return }
            push(new)
        }
    }

    private func push(_ total: Double) {
        let t = max(0, total)
        let h = Int(t) / 60
        let m = Int(t.rounded()) % 60
        hoursText = h == 0 ? "" : String(h)
        minutesText = m == 0 ? "" : String(m)
    }

    private func pull() {
        syncing = true
        let h = Double(hoursText) ?? 0
        let m = Double(minutesText) ?? 0
        minutes = max(0, h * 60 + m)
        DispatchQueue.main.async { syncing = false }
    }
}

/// A small numeric field for counts, styled like the money one.
struct NumberEntry: View {
    @Binding var value: Double
    @State private var text: String = ""
    @FocusState private var focused: Bool

    var body: some View {
        TextField("1", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 70)
            .monospacedDigit()
            .focused($focused)
            .selectAllOnFocus(focused)
            .onAppear { text = value == 1 ? "" : CurrencyField.display(value) }
            .onChange(of: text) { _, new in
                value = new.isEmpty ? 1 : max(0, CurrencyField.parse(new))
            }
    }
}

/// The money field used inside an option card, where the label lives outside the row.
struct MoneyEntry: View {
    @Binding var value: Double
    @State private var text: String = ""

    var body: some View {
        TextField("0", text: $text)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 110)
            .monospacedDigit()
            .onAppear { text = CurrencyField.display(value) }
            .onChange(of: text) { _, new in value = CurrencyField.parse(new) }
            .onChange(of: value) { _, new in
                if CurrencyField.parse(text) != new { text = CurrencyField.display(new) }
            }
    }
}

// MARK: - Feel

/// The subjective term. Seven steps, anchored so that +3 is worth exactly the
/// amount the user said they'd happily pay for a genuinely memorable evening.
struct FeelPicker: View {
    @Binding var feel: Int
    var anchor: Double

    static func descriptor(_ feel: Int) -> String {
        switch feel {
        case -3: return "I'd dread it"
        case -2: return "A real drag"
        case -1: return "Mildly annoying"
        case 0: return "Neutral"
        case 1: return "Quite nice"
        case 2: return "Really good"
        default: return "Genuinely memorable"
        }
    }

    static func symbol(_ feel: Int) -> String {
        switch feel {
        case -3: return "cloud.heavyrain.fill"
        case -2: return "cloud.rain.fill"
        case -1: return "cloud.fill"
        case 0: return "circle"
        case 1: return "sun.min.fill"
        case 2: return "sun.max.fill"
        default: return "sparkles"
        }
    }

    static func tint(_ feel: Int) -> Color {
        if feel < 0 { return .orange }
        if feel == 0 { return .secondary }
        return .green
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(-3...3, id: \.self) { level in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) { feel = level }
                    } label: {
                        Image(systemName: FeelPicker.symbol(level))
                            .font(.system(size: 15))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(level == feel
                                          ? FeelPicker.tint(level).opacity(0.22)
                                          : Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(level == feel ? FeelPicker.tint(level) : .clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(level == feel ? FeelPicker.tint(level) : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text(FeelPicker.descriptor(feel))
                    .font(.subheadline.weight(.medium))
                Spacer()
                if feel != 0 {
                    Text(Fmt.money(Double(feel) / 3 * anchor))
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(FeelPicker.tint(feel))
                }
            }
        }
    }
}

/// The health term, shaped like the feel picker so the two read as siblings —
/// which they are, and which is exactly why they need to be asked separately.
struct HealthPicker: View {
    @Binding var health: HealthEffect
    var anchor: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                ForEach(HealthEffect.allCases) { level in
                    Button {
                        withAnimation(.snappy(duration: 0.18)) { health = level }
                    } label: {
                        Image(systemName: level.symbol)
                            .font(.system(size: 15))
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(level == health
                                          ? HealthPicker.tint(level).opacity(0.22)
                                          : Color.secondary.opacity(0.08))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .strokeBorder(level == health ? HealthPicker.tint(level) : .clear, lineWidth: 1.5)
                            )
                            .foregroundStyle(level == health ? HealthPicker.tint(level) : Color.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text(health.label)
                    .font(.subheadline.weight(.medium))
                Spacer()
                if health != .neutral {
                    Text(Fmt.money(health.points / 2 * anchor) + " each time")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(HealthPicker.tint(health))
                }
            }
        }
    }

    static func tint(_ health: HealthEffect) -> Color {
        switch health {
        case .bad, .slightlyBad: return .red
        case .neutral: return .secondary
        case .slightlyGood, .good: return .teal
        }
    }
}

// MARK: - Layout furniture

struct Card<Content: View>: View {
    var tint: Color = .clear
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(tint.opacity(tint == .clear ? 0 : 0.5), lineWidth: 1.5)
            )
    }
}

struct StatRow: View {
    let label: String
    let value: String
    var detail: String? = nil
    var emphasis: Bool = false
    var tint: Color? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(alignment: .firstTextBaseline) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 12)
                Text(value)
                    .font(emphasis ? .headline.monospacedDigit() : .subheadline.monospacedDigit())
                    .foregroundStyle(tint ?? .primary)
            }
            if let detail {
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Dismisses the number pads, which have no return key of their own.
struct KeyboardDoneToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                                    to: nil, from: nil, for: nil)
                }
                .fontWeight(.semibold)
            }
        }
    }
}

extension View {
    func keyboardDoneToolbar() -> some View { modifier(KeyboardDoneToolbar()) }
}

// MARK: - Dates already written down

/// Finds the date somebody has already typed.
///
/// Ported from Attention, where it was written for capture: "send Maria the draft by
/// Friday" is how people write things down, and making them then find a date picker
/// is how the date gets lost. The same is true of anything you are saving towards —
/// "Mum's birthday, 14 March" and "Edinburgh in October" carry their own deadline,
/// and the picker underneath is a second go at something already said.
///
/// Only ever *offers*: the commitment is saved the same way whether or not the offer
/// is taken.
enum DateHint {
    private static let detector = try? NSDataDetector(
        types: NSTextCheckingResult.CheckingType.date.rawValue)

    /// The first date in the text that is still ahead of us, or `nil`.
    ///
    /// Past dates are ignored on purpose. Here that is not just noise-reduction but
    /// correctness: a commitment is something coming up, and `isActive` is false for
    /// anything whose date has gone — so offering a date in the past would offer to
    /// make the thing disappear from the list that it was being added to.
    static func firstDate(in text: String,
                          notBefore now: Date = Date(),
                          calendar: Calendar = .current) -> Date? {
        guard let detector, !text.isEmpty else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let today = calendar.startOfDay(for: now)

        for match in detector.matches(in: text, options: [], range: range) {
            guard let date = match.date else { continue }
            if calendar.startOfDay(for: date) >= today { return date }
        }
        return nil
    }
}

/// A row offering the date found in what has been typed. Tapping it takes the offer.
struct DateHintRow: View {
    let date: Date?
    var action: String = "Set the date to"
    let accept: (Date) -> Void

    var body: some View {
        if let date {
            Button {
                accept(date)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(action).font(.footnote)
                        Text(date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }
            }
            .buttonStyle(.plain)
            .accessibilityHint("Spotted a date in what you wrote")
        }
    }
}

extension View {
    /// Watches `text` for a date and hands back what it finds.
    ///
    /// Debounced and off the main thread, as Attention does it: scanning a sentence
    /// for a date is linguistic work, and running it between one keystroke and the
    /// next makes typing stutter. It only has to be right once you stop.
    func detectingDate(in text: String, into found: Binding<Date?>) -> some View {
        task(id: text) {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let typed = text
            let date = await Task.detached(priority: .userInitiated) {
                DateHint.firstDate(in: typed)
            }.value
            guard !Task.isCancelled else { return }
            found.wrappedValue = date
        }
    }
}
