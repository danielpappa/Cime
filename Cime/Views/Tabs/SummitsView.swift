import SwiftUI

struct SummitsView: View {
    @Environment(CimeStore.self) private var store
    @State private var interactions = SummitInteractions()       // real reactions + comments
    @State private var showingAddFriends = false
    @State private var showingRequests = false
    @State private var commentTarget: CommentTarget?

    /// Your header sits close under the toolbar via a negative inset; kept as a named value.
    private let topPull: CGFloat = -38

    /// How many of MY peaks are reached. Friend slide N unlocks once I've reached N.
    private var myUnlocked: Int { CimeStore.unlockedCount(goals: store.day.goals) }

    private struct FriendGroup: Identifiable {
        let id: UUID
        let name: String
        let posts: [FriendSummit]        // earliest -> latest, at most 3
    }

    /// Ordered by each friend's most recent summit (the feed arrives newest-first).
    private var groups: [FriendGroup] {
        var order: [UUID] = []
        var byUser: [UUID: [FriendSummit]] = [:]
        for summit in store.friendSummits {
            if byUser[summit.userId] == nil { order.append(summit.userId) }
            byUser[summit.userId, default: []].append(summit)
        }
        return order.compactMap { id in
            guard let posts = byUser[id], let first = posts.first else { return nil }
            return FriendGroup(id: id, name: first.name, posts: Array(posts.reversed().suffix(3)))
        }
    }

    /// Every summit on screen: their counts get fetched together.
    private var trackedIDs: [UUID] {
        store.day.goals.filter(\.done).map(\.id) + groups.flatMap { $0.posts.map(\.id) }
    }

    private var emptyMessage: String {
        if store.following.isEmpty {
            return store.outgoingRequestCount > 0
                ? "Waiting for your follow requests to be accepted."
                : "Follow climbers to see their summits here."
        }
        return "No summits from your crew yet today."
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header

                if groups.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }

                // Lazy: tall cards, and videos only start when a card is near the screen.
                LazyVStack(spacing: 20) {
                    if !store.day.goals.isEmpty {
                        ownCard.padding(.horizontal, -SummitUI.bleed)
                    }
                    ForEach(groups) { group in
                        friendCard(group).padding(.horizontal, -SummitUI.bleed)
                    }
                }
                .scrollTargetLayout()
                .animation(.snappy, value: groups.map(\.id))      // cards glide to the top on new summits
            }
            .padding(.horizontal, 24)
            .padding(.top, topPull)
            .padding(.bottom, 100)
        }
        .scrollTargetBehavior(.viewAligned)                       // cards snap into place; delete to free-scroll
        .refreshable {
            if let id = store.userId { await store.fetchFollowing(userId: id) }
            await store.fetchIncomingRequests()
            await store.fetchFriendSummits()
            await interactions.refresh()
        }
        .riseOnAppear()
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { showingRequests = true } label: {
                    Image(systemName: "bell")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                        .overlay(alignment: .topTrailing) {
                            if !store.incomingRequests.isEmpty {
                                Circle().fill(Theme.summit).frame(width: 9, height: 9).offset(x: 4, y: -3)
                            }
                        }
                }
                .accessibilityLabel("Follow requests")

                Button { showingAddFriends = true } label: {
                    Image(systemName: "person.badge.plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.foreground)
                }
                .accessibilityLabel("Add friends")
            }
        }
        .sheet(isPresented: $showingAddFriends) { AddFriendsSearchView() }
        .sheet(isPresented: $showingRequests) { FollowRequestsView() }
        .sheet(item: $commentTarget) { CommentsSheet(target: $0) }
        .environment(interactions)          // keep this AFTER the sheets so they inherit it
        .task {
            interactions.bind(store)
            await interactions.startRealtime()
        }
        .task(id: trackedIDs) {
            interactions.bind(store)
            await interactions.track(trackedIDs)
        }
        .onDisappear { Task { await interactions.stopRealtime() } }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                .monoCaps(10)
                .foregroundStyle(Theme.glacier)
            Text("Summits")
                .displayFont(36)
        }
    }

    // MARK: - Cards (own + friends share SummitCard)

    private var ownCard: some View {
        let slides = store.day.goals.prefix(3).map { goal -> CardSlide in
            goal.done
                ? CardSlide(
                    goalID: goal.id, caption: goal.text, isLocked: false,
                    content: .proof(.init(kind: goal.proofKind, jpeg: goal.proofJPEG, path: goal.proofPath)))
                : CardSlide(
                    goalID: goal.id, caption: goal.text, isLocked: false,
                    content: .message(symbol: "mountain.2.fill", text: "Still climbing…"))
        }
        return SummitCard(
            name: "You",
            slides: Array(slides),
            isOwn: true,
            avatar: AnyView(
                AvatarView(jpeg: store.profile?.avatarJPEG,
                           url: store.profile?.avatarURL.flatMap(URL.init(string:)),
                           letter: store.profile?.username ?? "you", size: 40)
            ),
            onComments: { commentTarget = CommentTarget(slide: $0, isOwnPost: true) }
        )
    }

    private func friendCard(_ group: FriendGroup) -> some View {
        // One slide per summit they've reached. Locked slides keep their real media, blurred.
        let slides = group.posts.enumerated().map { index, post -> CardSlide in
            let locked = index >= myUnlocked
            return CardSlide(
                goalID: post.id,
                caption: locked ? "Summit locked" : post.goal,
                isLocked: locked,
                lockHint: locked ? "Reach peak \(index + 1) to unlock" : nil,
                content: .proof(.init(kind: post.proofKind, url: post.proofURL,
                                      badge: post.time, blurred: locked)))
        }
        return SummitCard(
            name: group.name,
            slides: slides,
            isOwn: false,
            avatar: AnyView(
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Text(group.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .frame(width: 40, height: 40)
            ),
            profileRoute: .person(group.name),                    // user icon -> their profile
            onComments: { commentTarget = CommentTarget(slide: $0, isOwnPost: false) }
        )
    }
}

// MARK: - Add friends

private struct AddFriendsSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CimeStore.self) private var store
    @State private var query = ""
    @State private var results: [Person] = []
    @State private var isSearching = false

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    TextField("Search climbers by username", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .padding(14)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    ForEach(results) { person in
                        PersonRow(person: person)
                    }

                    if isSearching {
                        ProgressView().frame(maxWidth: .infinity).padding(.top, 16)
                    } else if trimmed.count >= 2 && results.isEmpty {
                        Text("No climbers match \"\(trimmed)\".")
                            .font(.subheadline)
                            .foregroundStyle(Theme.mutedForeground)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 16)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 100)
            }
            .navigationTitle("Add Friends")
            .navigationBarTitleDisplayMode(.inline)
            // This sheet has its own NavigationStack, so it needs its own destination.
            .navigationDestination(for: AppRoute.self) { route in
                if case .person(let name) = route { PersonView(name: name) }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(.subheadline.weight(.semibold))
                }
            }
        }
        .task(id: trimmed) {
            guard trimmed.count >= 2 else { results = []; isSearching = false; return }
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            isSearching = true
            let found = await store.searchPeople(query: trimmed)
            guard !Task.isCancelled else { return }
            results = found
            isSearching = false
        }
    }
}

private struct PersonRow: View {
    let person: Person

    var body: some View {
        HStack(spacing: 12) {
            NavigationLink(value: AppRoute.person(person.name)) {
                HStack(spacing: 12) {
                    AvatarView(url: person.avatarURL, letter: person.name, size: 44)
                    Text(person.name)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            FollowButton(person: person)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

#Preview {
    SummitsView()
        .environment(CimeStore())
}
