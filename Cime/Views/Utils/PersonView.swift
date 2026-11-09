import SwiftUI

struct PersonView: View {
    @Environment(CimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let name: String

    @State private var loaded: (person: Person, today: Int)?
    @State private var isLoading = true

    var body: some View {
        Group {
            if let loaded {
                content(loaded.person, today: loaded.today)
            } else if isLoading {
                ProgressView().padding(.top, 80)
            } else {
                VStack(spacing: 16) {
                    Text("Climber not found.")
                }
                .padding(.top, 80)
            }
        }
        .topoBackground()
        .task(id: name) {
            isLoading = true
            loaded = await store.fetchPerson(username: name)
            isLoading = false
        }
    }

    private func content(_ person: Person, today: Int) -> some View {
        let following = store.following.contains(person.name)

        return ScrollView {
            VStack(spacing: 0) {

                AvatarView(url: person.avatarURL, letter: person.name, size: 96)
                    .overlay(Circle().stroke(Theme.glacier, lineWidth: 2))
                    .padding(.top, 32)

                Text(person.name)
                    .displayFont(28)

                Button(following ? "Roped in" : "Follow") {
                    Task {
                        await store.toggleFollow(person)
                        loaded = await store.fetchPerson(username: person.name)
                    }
                }
                .font(.headline)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(following ? Color.clear : Theme.primary)
                .foregroundStyle(following ? Theme.mutedForeground : Theme.primaryForeground)
                .overlay(Capsule().stroke(following ? Theme.border : Color.clear))
                .clipShape(Capsule())
                .padding(.top, 20)

                HStack(spacing: 12) {
                    stat("\(person.streak)", "day streak")
                    stat("\(today)/3", "today")
                    stat("\(person.summits)", "summits")
                }
                .padding(.top, 32)

                LogoView(done: (0..<3).map { $0 < today })
                    .padding(16)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 32)
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
    PersonView(name: "steph")
        .environment(CimeStore())
}
