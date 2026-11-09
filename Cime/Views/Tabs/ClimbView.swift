import SwiftUI
import UIKit

struct ClimbView: View {
    @Environment(CimeStore.self) private var store
    @Binding var proveGoalIndex: Int?
    @State private var drafts = ["", "", ""]

    private var unlocked: Int { CimeStore.unlockedCount(goals: store.day.goals) }
    private var draftsIncomplete: Bool {
        drafts.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
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
        .riseOnAppear()
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Choose today's three peaks.")
                .displayFont(24)
            Text("No more, no less. They lock until midnight.")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)

            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 12) {
                    Text(String(format: "%d", i + 1))
                        .monoCaps(12)
                        .foregroundStyle(Theme.summit)
                    TextField(["e.g. Run 10k", "e.g. Submit the Algebra Assignment", "e.g. Do Laundry"][i], text: $drafts[i])
                        .onChange(of: drafts[i]) { _, new in
                            if new.count > 60 { drafts[i] = String(new.prefix(60)) }
                        }
                }
                .padding(14)
                .background(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Button("Lock in my peaks") {
                let goals = drafts.map { Goal(text: $0.trimmingCharacters(in: .whitespacesAndNewlines), done: false) }
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
            .padding(.top, 8)
        }
        .padding(.top, 32)
    }
    
    private struct PeakCopy { let heading: String; let sub: String; let footer: String }

    private var copy: PeakCopy {
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

    private var goalsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
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

// MARK: - Isolated Row Subview to prevent compiler timeout
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
    
}
