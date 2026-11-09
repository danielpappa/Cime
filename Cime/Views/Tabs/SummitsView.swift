import SwiftUI
import AVKit

struct SummitsView: View {
    @Environment(CimeStore.self) private var store
    @State private var showingAddFriends = false
    @State private var showingRequests = false

    /// Your original header sat close under the toolbar via a negative inset; kept as a named value.
    private let topPull: CGFloat = -38

    /// How many of MY peaks are reached. Friend slide N unlocks once I've reached N.
    private var myUnlocked: Int { CimeStore.unlockedCount(goals: store.day.goals) }

    private struct FriendGroup: Identifiable {
        let id: UUID
        let name: String
        let posts: [FriendSummit]        // earliest -> latest, at most 3
    }

    /// Cards are ordered by each friend's MOST RECENT summit (the feed arrives newest-first, so
    /// first appearance = latest activity). Inside a card, summits run earliest -> latest.
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

                if !store.day.goals.isEmpty { ownCard }

                if groups.isEmpty {
                    Text(emptyMessage)
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedForeground)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 8)
                }

                ForEach(groups) { group in
                    friendCard(group)
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, topPull)
            .padding(.bottom, 100)
            .animation(.snappy, value: groups.map(\.id))      // cards glide to the top on new summits
        }
        .refreshable {
            if let id = store.userId { await store.fetchFollowing(userId: id) }
            await store.fetchIncomingRequests()
            await store.fetchFriendSummits()
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

    // MARK: - Cards (own + friends share SummitCard, so they always look identical)

    private var ownCard: some View {
        let slides = store.day.goals.prefix(3).map { goal in
            goal.done
                ? CardSlide(
                    id: goal.id.uuidString, caption: goal.text, isLocked: false,
                    content: .proof(.init(kind: goal.proofKind, jpeg: goal.proofJPEG, path: goal.proofPath)))
                : CardSlide(
                    id: goal.id.uuidString, caption: goal.text, isLocked: false,
                    content: .message(symbol: "mountain.2.fill", text: "Still climbing…"))
        }
        return SummitCard(
            name: "You",
            slides: Array(slides),
            progress: "\(myUnlocked)/3",
            isOwn: true,
            avatar: AnyView(
                AvatarView(jpeg: store.profile?.avatarJPEG,
                           url: store.profile?.avatarURL.flatMap(URL.init(string:)),
                           letter: store.profile?.username ?? "you", size: 38)
                    .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            )
        )
    }

    private func friendCard(_ group: FriendGroup) -> some View {
        // One slide per summit they've actually reached: nothing to wait for. A slide is
        // locked only until I've reached as many peaks as its position (1st, 2nd, 3rd).
        let slides = group.posts.enumerated().map { index, post -> CardSlide in
            let locked = index >= myUnlocked
            return CardSlide(
                id: post.id.uuidString,
                caption: locked ? "Summit locked" : post.goal,
                isLocked: locked,
                content: locked
                    ? .message(symbol: "mountain.2.fill", text: "Reach peak \(index + 1) to unlock")
                    : .proof(.init(kind: post.proofKind, url: post.proofURL, badge: post.time)))
        }
        return SummitCard(
            name: group.name,
            slides: slides,
            progress: "\(min(3, group.posts.count))/3",
            isOwn: false,
            avatar: AnyView(
                ZStack {
                    Circle().fill(Theme.glacier.opacity(0.2)).frame(width: 38, height: 38)
                    Text(group.name.prefix(1).uppercased())
                        .font(.headline)
                        .foregroundStyle(Theme.glacier)
                }
                .overlay(Circle().stroke(Theme.border, lineWidth: 1))
            )
        )
    }
}

// MARK: - Shared card

private struct CardSlide: Identifiable {
    struct Proof {
        var kind: ProofKind?
        var jpeg: Data?          // local capture (own, not yet re-downloaded)
        var url: URL?            // already-signed URL (friends)
        var path: String?        // storage path, resolved lazily (own, after relaunch)
        var badge: String?       // e.g. "2h"
    }
    enum Content {
        case proof(Proof)
        case message(symbol: String, text: String)
    }

    let id: String
    let caption: String          // shown under the name; follows the page you're on
    let isLocked: Bool
    let content: Content
}

private struct SummitCard: View {
    let name: String
    let slides: [CardSlide]
    let progress: String
    let isOwn: Bool
    let avatar: AnyView

    @State private var page = 0

    private var current: CardSlide? { slides.indices.contains(page) ? slides[page] : slides.first }

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                    SlideView(slide: slide).tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: slides.count > 1 ? .automatic : .never))
            .frame(maxWidth: .infinity)
            .frame(height: 380)

            bar
        }
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private var bar: some View {
        HStack(spacing: 12) {
            avatar

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.headline).foregroundStyle(Theme.foreground)
                Text(current?.caption ?? "")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
                    .lineLimit(1)
            }

            Spacer()

            Text(progress)
                .monoCaps(10)
                .foregroundStyle(Theme.mutedForeground)

            if !isOwn {
                HStack(spacing: 16) {
                    Button { /* TODO reactions */ } label: {
                        Image(systemName: "heart.fill").font(.system(size: 18))
                    }
                    Button { /* TODO comments */ } label: {
                        Image(systemName: "bubble.right").font(.system(size: 18))
                    }
                }
                .foregroundStyle((current?.isLocked ?? true) ? Theme.mutedForeground : Theme.foreground)
                .disabled(current?.isLocked ?? true)
                .opacity((current?.isLocked ?? true) ? 0.4 : 1)
            }
        }
        .padding(16)
        .background(Theme.card)
    }
}

/// One page. Content, locked and placeholder states all fill the page edge to edge.
private struct SlideView: View {
    @Environment(CimeStore.self) private var store
    let slide: CardSlide

    @State private var resolvedURL: URL?
    @State private var resolveFailed = false

    /// Only slides that carry a storage path (no local data, no URL yet) need a signed URL.
    private var pathToResolve: String? {
        if case .proof(let p) = slide.content, p.jpeg == nil, p.url == nil { return p.path }
        return nil
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { content }
            .overlay(alignment: .topTrailing) {
                if case .proof(let p) = slide.content, let badge = p.badge {
                    Text(badge)
                        .monoCaps(10)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(.black.opacity(0.6))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .padding(12)
                }
            }
            .clipped()
            .task(id: pathToResolve) {
                guard let path = pathToResolve else { return }
                resolvedURL = await store.proofURL(path: path)
                resolveFailed = resolvedURL == nil
            }
    }

    @ViewBuilder private var content: some View {
        switch slide.content {
        case .message(let symbol, let text):
            message(symbol, text)
        case .proof(let p):
            proof(p)
        }
    }

    @ViewBuilder private func proof(_ p: CardSlide.Proof) -> some View {
        if let jpeg = p.jpeg {
            ProofMediaView(jpeg: jpeg, kind: p.kind ?? .photo)          // local, instant
        } else {
            let url = p.url ?? resolvedURL
            switch (p.kind, url) {
            case (.video?, let url?):
                FeedVideo(url: url)
            case (.audio?, _):
                message("waveform", "Voice note")
            case (_, let url?):
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() }
                    else if phase.error != nil { message("exclamationmark.triangle", "Couldn't load") }
                    else { ProgressView() }
                }
            default:
                if p.path != nil && !resolveFailed { ProgressView() }
                else { message("photo", "No proof yet") }
            }
        }
    }

    private func message(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(Theme.glacier)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.mutedForeground)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.card.opacity(0.5))
    }
}

private struct FeedVideo: View {
    let url: URL
    @State private var player: AVPlayer?

    var body: some View {
        VideoPlayer(player: player)
            .onAppear { player = AVPlayer(url: url) }
            .onDisappear { player?.pause() }
            // Only react to THIS player's item.
            .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { note in
                guard let item = note.object as? AVPlayerItem, item === player?.currentItem else { return }
                player?.seek(to: .zero)
            }
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
