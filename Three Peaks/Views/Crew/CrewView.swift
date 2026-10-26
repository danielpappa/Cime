import SwiftUI

struct CrewView: View {
    @Environment(PeaksStore.self) private var store
    @State private var query = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your rope team")
                    .displayFont(24)

                TextField("Search climbers by name", text: $query)
                    .padding(14)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                let results = store.searchPeople(query: query)
                ForEach(results) { person in
                    CrewRow(person: person)
                }

                if results.isEmpty {
                    Text("No climbers match \"\(query)\".")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedForeground)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 16)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 100)
        }
        .riseOnAppear()
    }
}

private struct CrewRow: View {
    @Environment(PeaksStore.self) private var store
    let person: Person

    private var isFollowing: Bool { store.following.contains(person.name) }

    var body: some View {
        HStack {
            NavigationLink(value: AppRoute.person(person.name)) {
                HStack(spacing: 12) {
                    Text(String(person.name.prefix(1)).uppercased())
                        .displayFont(18)
                        .frame(width: 40, height: 40)
                        .background(Theme.secondary)
                        .clipShape(Circle())
                    VStack(alignment: .leading) {
                        Text(person.name)
                        Text(person.full)
                            .font(.caption)
                            .foregroundStyle(Theme.mutedForeground)
                    }
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button(isFollowing ? "Roped in" : "Follow") {
                store.toggleFollow(name: person.name)
            }
            .font(.subheadline.weight(.semibold))
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(isFollowing ? Color.clear : Theme.accent)
            .foregroundStyle(isFollowing ? Theme.mutedForeground : Theme.accentForeground)
            .overlay(Capsule().stroke(isFollowing ? Theme.border : Color.clear))
            .clipShape(Capsule())
        }
        .padding(14)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    MainTabView()
}
