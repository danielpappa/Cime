import SwiftUI
import UIKit

struct ClimbView: View {
    @Environment(PeaksStore.self) private var store
    @Binding var proveGoalIndex: Int?
    @State private var drafts = ["", "", ""]

    private var unlocked: Int { PeaksStore.unlockedCount(goals: store.day.goals) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                TreCimeView(done: (0..<3).map { store.day.goals.indices.contains($0) && store.day.goals[$0].done })
                    .padding(.top, 32)

                if store.day.goals.isEmpty {
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
            Text("Exactly three. No more, no less. They lock until midnight.")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)

            ForEach(0..<3, id: \.self) { i in
                HStack(spacing: 12) {
                    Text(String(format: "0%d", i + 1))
                        .monoCaps(11)
                        .foregroundStyle(Theme.summit)
                    TextField(["e.g. Run 5k", "e.g. Ship the draft", "e.g. Call grandma"][i], text: $drafts[i])
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
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.primary)
            .foregroundStyle(Theme.primaryForeground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .emberGlow()
            .disabled(drafts.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty })
            .opacity(drafts.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty } ? 0.3 : 1)
            .padding(.top, 8)
        }
        .padding(.top, 32)
    }

    private var goalsSection: some View {
        VStack(spacing: 12) {
            ForEach(Array(store.day.goals.enumerated()), id: \.element.id) { index, goal in
                HStack(spacing: 16) {
                    if let jpeg = goal.proofJPEG, let ui = UIImage(data: jpeg) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
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
                        Text(DemoContent.peakNames[index])
                            .monoCaps(10)
                            .foregroundStyle(Theme.mutedForeground)
                        Text(goal.text)
                            .font(.body.weight(.medium))
                    }
                    Spacer()
                    if goal.done {
                        Text("REACHED")
                            .monoCaps(11)
                            .foregroundStyle(Theme.summit)
                    } else {
                        Button("Prove") { proveGoalIndex = index }
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

            Text(unlocked == 3
                 ? "All three peaks conquered. See you at dawn."
                 : "\(unlocked)/3 friend summits unlocked")
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)
                .frame(maxWidth: .infinity)
                .padding(.top, 8)
        }
        .padding(.top, 24)
    }
}

#Preview {
    MainTabView()
}
