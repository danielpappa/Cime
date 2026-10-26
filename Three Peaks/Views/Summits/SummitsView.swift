import SwiftUI

struct SummitsView: View {
    @Environment(PeaksStore.self) private var store

    private var unlocked: Int { PeaksStore.unlockedCount(goals: store.day.goals) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Friends' summits")
                    .displayFont(24)

                ForEach(Array(DemoContent.friendSummits.filter { store.following.contains($0.name) }.enumerated()), id: \.element.id) { index, summit in
                    if index < unlocked {
                        VStack(spacing: 0) {
                            Image(summit.imageName)
                                .resizable()
                                .scaledToFill()
                                .frame(maxWidth: .infinity)
                                .aspectRatio(4 / 5, contentMode: .fit)
                                .clipped()

                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(summit.name).font(.headline)
                                    Text("▲ \(summit.goal)")
                                        .font(.subheadline)
                                        .foregroundStyle(Theme.mutedForeground)
                                }
                                Spacer()
                                Text(summit.time)
                                    .monoCaps(11)
                                    .foregroundStyle(Theme.glacier)
                            }
                            .padding(16)
                        }
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    } else {
                        VStack(spacing: 8) {
                            Text("▲").displayFont(32)
                            Text("Reach peak \(index + 1) to reveal \(summit.name)'s summit")
                                .font(.subheadline)
                                .foregroundStyle(Theme.mutedForeground)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                        }
                        .frame(maxWidth: .infinity)
                        .aspectRatio(2, contentMode: .fit)
                        .background(Theme.card.opacity(0.5))
                        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Theme.border, style: StrokeStyle(lineWidth: 1, dash: [6])))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 100)
        }
        .riseOnAppear()
    }
}

#Preview {
    MainTabView()
}
