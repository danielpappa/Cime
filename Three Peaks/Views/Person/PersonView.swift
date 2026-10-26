import SwiftUI

struct PersonView: View {
    @Environment(PeaksStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let name: String

    private var person: Person? { DemoContent.person(named: name) }

    var body: some View {
        Group {
            if let person {
                content(person)
            } else {
                VStack(spacing: 16) {
                    Text("Climber not found.")
                    Button("← Back") { dismiss() }
                        .foregroundStyle(Theme.summit)
                }
                .padding(.top, 80)
            }
        }
        .topoBackground()
        .navigationBarBackButtonHidden()
    }

    private func content(_ person: Person) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                Button("← Climb") { dismiss() }
                    .monoCaps(11)
                    .foregroundStyle(Theme.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(String(person.name.prefix(1)).uppercased())
                    .displayFont(36)
                    .frame(width: 96, height: 96)
                    .background(Theme.secondary)
                    .overlay(Circle().stroke(Theme.glacier, lineWidth: 2))
                    .clipShape(Circle())
                    .padding(.top, 32)

                Text("@\(person.name)")
                    .displayFont(28)
                    .padding(.top, 16)
                Text(person.full)
                    .foregroundStyle(Theme.mutedForeground)
                Text(person.bio)
                    .font(.subheadline)
                    .padding(.top, 8)

                let following = store.following.contains(person.name)
                Button(following ? "Roped in" : "Follow") {
                    store.toggleFollow(name: person.name)
                }
                .font(.headline)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(following ? Color.clear : Theme.primary)
                .foregroundStyle(following ? Theme.mutedForeground : Theme.primaryForeground)
                .overlay(Capsule().stroke(following ? Theme.border : Color.clear))
                .clipShape(Capsule())
                .padding(.top, 20)

                let today = person.streak % 4
                HStack(spacing: 12) {
                    stat("\(person.streak)", "day streak")
                    stat("\(today)/3", "today")
                    stat("\(person.summits)", "summits")
                }
                .padding(.top, 32)

                TreCimeView(done: (0..<3).map { $0 < today })
                    .padding(16)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 32)

                if !following {
                    Text("Follow \(person.name) to see their summits in your feed.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .padding(.top, 24)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .riseOnAppear()
    }

    private func stat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).displayFont(24)
            Text(label).monoCaps(10).foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MainTabView()
}
