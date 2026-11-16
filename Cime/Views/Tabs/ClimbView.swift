import SwiftUI
import UIKit

struct ClimbView: View {
    @Environment(CimeStore.self) private var store
    @Binding var proveGoalIndex: Int?

    @State private var drafts = ["", "", ""]
    @State private var suggestions = GoalSuggestionsModel()
    @State private var tab: GoalSuggestion.Source?               // nil = "For you"
    @State private var fillTick = 0
    @FocusState private var focus: Int?

    private let placeholders = ["e.g. Run 10k", "e.g. Submit the Algebra Assignment", "e.g. Do Laundry"]

    private var unlocked: Int { CimeStore.unlockedCount(goals: store.day.goals) }

    private func clean(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var draftsIncomplete: Bool { drafts.contains { clean($0).isEmpty } }
    private var allEmpty: Bool { drafts.allSatisfy { clean($0).isEmpty } }
    private var used: Set<String> { Set(drafts.map { clean($0).lowercased() }.filter { !$0.isEmpty }) }

    // MARK: - Body

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .center, spacing: 0) {
                    LogoView(done: (0..<3).map { store.day.goals.indices.contains($0) && store.day.goals[$0].done })
                        .padding(.top, 32)

                    if store.isBootstrapping && store.day.goals.isEmpty {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 48)
                    } else if store.day.goals.isEmpty {
                        setupSection
                    } else {
                        goalsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 100)
            }
            .scrollDismissesKeyboard(.interactively)
            // bring the active field to the top so the suggestions below stay above the keyboard
            .onChange(of: focus) { _, new in
                guard let new else { return }
                withAnimation(.snappy) { proxy.scrollTo("field\(new)", anchor: .top) }
            }
        }
        .riseOnAppear()
        .sensoryFeedback(.selection, trigger: fillTick)
        .task(id: store.day.goals.isEmpty) {
            guard store.day.goals.isEmpty else { return }
            await suggestions.load(store)
        }
    }

    // MARK: - Setup: three fields, one tap to repeat, one button to lock, suggestions below

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose today's three peaks.")
                .displayFont(24)
            Text("No more, no less. They lock until midnight.")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)

            VStack(spacing: 12) {
                ForEach(0..<3, id: \.self) { goalField($0) }
            }

            repeatButton
            lockButton
            suggestionsSection
        }
        .padding(.top, 32)
    }

    private func goalField(_ i: Int) -> some View {
        HStack(spacing: 12) {
            Text("\(i + 1)")
                .monoCaps(12)
                .foregroundStyle(Theme.summit)

            TextField(placeholders[i], text: $drafts[i])
                .focused($focus, equals: i)
                .submitLabel(i == 2 ? .done : .next)
                .onSubmit { focus = i < 2 ? i + 1 : nil }          // Return moves to the next peak
                .onChange(of: drafts[i]) { _, new in
                    if new.count > 60 { drafts[i] = String(new.prefix(60)) }
                }

            if !drafts[i].isEmpty {
                Button { drafts[i] = ""; focus = i } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.mutedForeground)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(focus == i ? Theme.summit.opacity(0.6) : Theme.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .id("field\(i)")
    }

    /// Only offered while the form is empty and you have a previous day.
    @ViewBuilder private var repeatButton: some View {
        if allEmpty, !suggestions.lastPeaks.isEmpty {
            Button {
                for (i, text) in suggestions.lastPeaks.prefix(3).enumerated() { drafts[i] = String(text.prefix(60)) }
                fillTick += 1
                focus = nil
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.counterclockwise")
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Repeat \(suggestions.lastLabel)'s peaks").font(.subheadline.weight(.semibold))
                        Text(suggestions.lastPeaks.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(Theme.mutedForeground)
                            .lineLimit(1)
                    }
                    Spacer()
                }
                .foregroundStyle(Theme.foreground)
                .padding(14)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [5, 4])))
            }
            .buttonStyle(.plain)
        }
    }

    private var lockButton: some View {
        Button("Lock in my peaks") {
            let goals = drafts.map { Goal(text: clean($0), done: false) }
            focus = nil
            store.updateDay { $0.goals = goals }
            drafts = ["", "", ""]
        }
        .font(.headline)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Theme.primary)
        .foregroundStyle(Theme.primaryForeground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .emberGlow()
        .disabled(draftsIncomplete)
        .opacity(draftsIncomplete ? 0.3 : 1)
    }

    // MARK: - Suggestions: typeahead while typing, otherwise tabs (For you / Yours / Crew / Ideas / Popular)

    @ViewBuilder private var suggestionsSection: some View {
        let typed = focus.flatMap { drafts.indices.contains($0) ? clean(drafts[$0]) : nil } ?? ""
        let isTypeahead = !typed.isEmpty
        let items = isTypeahead
            ? suggestions.matches(typed, excluding: used)
            : suggestions.list(tab, excluding: used)

        if !items.isEmpty || !isTypeahead {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(isTypeahead ? "Matches" : "Need a push?").font(.headline)
                    Spacer()
                    if !isTypeahead { Text("Tap to add").font(.caption).foregroundStyle(Theme.mutedForeground) }
                }

                if !isTypeahead { tabChips }

                if !items.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(items) { item in
                            suggestionRow(item)
                            if item.id != items.last?.id {
                                Divider().overlay(Theme.border).padding(.leading, 48)
                            }
                        }
                    }
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
            }
            .padding(.top, 8)
            .animation(.snappy, value: items.map(\.id))
        }
    }

    private var tabChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip("For you", selected: tab == nil) { tab = nil }
                ForEach(suggestions.availableSources, id: \.self) { source in
                    chip(source.title, selected: tab == source) { tab = source }
                }
            }
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.snappy) { action() }
        } label: {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(selected ? Theme.foreground : Theme.card, in: Capsule())
                .foregroundStyle(selected ? Theme.background : Theme.foreground)
                .overlay(Capsule().stroke(selected ? Color.clear : Theme.border))
        }
        .buttonStyle(.plain)
    }

    private func suggestionRow(_ item: GoalSuggestion) -> some View {
        HStack(spacing: 12) {
            Image(systemName: item.source.symbol)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(item.source.tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.foreground)
                    .multilineTextAlignment(.leading)
                if let detail = item.detail {
                    Text(detail).font(.caption).foregroundStyle(Theme.mutedForeground)
                }
            }
            Spacer(minLength: 8)
            Image(systemName: "plus.circle.fill").foregroundStyle(Theme.summit)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .onTapGesture { apply(item) }
    }

    /// Fills the field you're in (replacing what you were typing), otherwise the first empty one.
    private func apply(_ item: GoalSuggestion) {
        guard let slot = focus ?? drafts.firstIndex(where: { clean($0).isEmpty }) else { return }
        drafts[slot] = String(item.text.prefix(60))
        fillTick += 1
        if focus != nil {
            focus = drafts.firstIndex { clean($0).isEmpty }          // jump to the next empty peak, or close the keyboard
        }
    }

    // MARK: - After locking: unchanged

    private var goalsSection: some View {
        let copy = PeakCopy.make(unlocked: unlocked)
        return VStack(alignment: .leading, spacing: 16) {
            Text(copy.heading)
                .displayFont(24)
            Text(copy.sub)
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)

            ForEach(Array(store.day.goals.enumerated()), id: \.element.id) { index, goal in
                GoalRowView(index: index, goal: goal) {
                    proveGoalIndex = index
                }
            }

            Text(copy.footer)
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .animation(.easeInOut, value: unlocked)
        .padding(.top, 24)
    }
}

// MARK: - Copy for 0...3 peaks (same text as before, moved out of the view)

private struct PeakCopy {
    let heading: String
    let sub: String
    let footer: String

    static func make(unlocked: Int) -> PeakCopy {
        let day = Calendar.current.ordinality(of: .day, in: .year, for: .now) ?? 0
        func pick(_ options: [PeakCopy]) -> PeakCopy { options[day % options.count] }

        switch unlocked {
        case 0:
            return pick([
                PeakCopy(heading: "The mountain's waiting.",
                         sub: "Three goals, zero summits so far. Pick one and take the first step.",
                         footer: "0/3 · Every climb starts at the trailhead."),
                PeakCopy(heading: "Boots on, phone down.",
                         sub: "Your peaks won't climb themselves. Start with the easiest one and build momentum.",
                         footer: "0/3 · Friends' summits stay locked until you climb."),
                PeakCopy(heading: "Good morning, climber.",
                         sub: "Today's three peaks are set. Which one are you taking first?",
                         footer: "0/3 · Prove one peak to start unlocking your crew's summits.")
            ])
        case 1:
            return pick([
                PeakCopy(heading: "First peak: bagged.",
                         sub: "One down. The view only gets better from here.",
                         footer: "1/3 · One friend summit unlocked. Keep climbing."),
                PeakCopy(heading: "Off the trailhead.",
                         sub: "Momentum is real. Ride it straight to the next one.",
                         footer: "1/3 · You've started. Two peaks to go."),
                PeakCopy(heading: "One down, two to go.",
                         sub: "The hardest step was the first one, and you already took it.",
                         footer: "1/3 · Your crew's first summit is unlocked.")
            ])
        case 2:
            return pick([
                PeakCopy(heading: "Almost at the top.",
                         sub: "Two summits behind you. One last push.",
                         footer: "2/3 · The final peak is calling."),
                PeakCopy(heading: "Don't stop now.",
                         sub: "You can see the summit from here. Finish what you started.",
                         footer: "2/3 · One goal between you and a perfect day."),
                PeakCopy(heading: "So close you can taste it.",
                         sub: "Two peaks conquered. The last one is yours for the taking.",
                         footer: "2/3 · Almost there. Don't let it slip.")
            ])
        default:
            return pick([
                PeakCopy(heading: "Three peaks. Zero excuses.",
                         sub: "You climbed everything you set out to. Go enjoy the view.",
                         footer: "3/3 · All three peaks conquered. See you at dawn."),
                PeakCopy(heading: "Perfect day.",
                         sub: "All three goals proven. Your streak just got stronger.",
                         footer: "3/3 · Rest up. New peaks arrive at midnight.")
            ])
        }
    }
}

// MARK: - Goal row

private struct GoalRowView: View {
    let index: Int
    let goal: Goal
    let onProve: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            if goal.proofJPEG != nil || goal.proofPath != nil {
                ProofThumb(goal: goal)
                    .frame(width: 56, height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                Text("\(index + 1)")
                    .displayFont(20)
                    .frame(width: 56, height: 56)
                    .background(Theme.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(goal.text)
                    .font(.body.weight(.medium))
            }

            Spacer()

            if goal.done {
                Text("REACHED")
                    .monoCaps(11)
                    .foregroundStyle(Theme.summit)
            } else {
                Button("Prove", action: onProve)
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Theme.primary)
                    .foregroundStyle(Theme.primaryForeground)
                    .clipShape(Capsule())
            }
        }
        .padding(16)
        .background(goal.done ? Theme.summit.opacity(0.1) : Theme.card)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(goal.done ? Theme.summit.opacity(0.5) : Theme.border)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    ClimbView(proveGoalIndex: .constant(nil))
        .environment(CimeStore())
}
