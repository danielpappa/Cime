import SwiftUI
import AVKit

struct DiscoverView: View {
    @Environment(CimeStore.self) private var store

    @State private var query = ""
    @State private var results: [Summit] = []          // what the grid shows right now
    @State private var allToday: [Summit] = []         // unfiltered, for "trending today"
    @State private var selectedSummit: Summit?
    @State private var isLoading = false
    @State private var topic: GoalIdea.Topic?          // nil = "For you" (mixed, ranked for this moment)
    @State private var forYouOnly = false
    @FocusState private var searchFocused: Bool
    @AppStorage("discover.recents") private var recentsRaw = ""

    private let context = IdeaContext.now()

    private var trimmed: String { query.trimmingCharacters(in: .whitespaces) }
    private var showSuggestions: Bool { searchFocused }
    private var forYouAvailable: Bool { !store.userInterestKeywords.isEmpty }
    private var ideas: [GoalIdea] { GoalIdeas.pick(for: context, topic: topic) }
    private var trending: [TrendingWord] { Trending.keywords(from: allToday.map(\.goal)) }
    private var recents: [String] { recentsRaw.split(separator: "\n").map(String.init) }

    /// Re-run when the query, the "for you" toggle or the interest keywords change.
    private var taskKey: String {
        "\(trimmed)|\(forYouOnly)|\(store.userInterestKeywords.joined(separator: ","))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if !searchFocused { header }

                    if showSuggestions {
                        suggestions
                    } else {
                        ideasSection
                        summitsSection
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 100)
                .animation(.snappy, value: showSuggestions)
            }
            .scrollDismissesKeyboard(.interactively)
            .refreshable { await load() }
            .navigationBarHidden(true)
            .task(id: taskKey) { await load() }
            .sheet(item: $selectedSummit) { SummitDetailSheet(summit: $0) }
        }
    }

    // MARK: - Loading

    private func load() async {
        isLoading = true
        let terms: [String] = (forYouOnly ? store.userInterestKeywords : [])
        let found = await store.discoverSummits(terms: terms)
        guard !Task.isCancelled else { return }
        results = found
        if terms.isEmpty { allToday = found }
        isLoading = false
    }

    // MARK: - Header + search

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                .monoCaps(10)
                .foregroundStyle(Theme.glacier)
            Text("Discover")
                .displayFont(36)
        }
    }

    // MARK: - Suggestions (focused, nothing typed yet): recents, trending, seeds

    private var suggestions: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !recents.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Recent").font(.headline)
                        Spacer()
                        Button("Clear") { recentsRaw = "" }
                            .font(.subheadline).foregroundStyle(Theme.mutedForeground)
                    }
                    ForEach(recents, id: \.self) { term in
                        row(icon: "clock", title: term, onTap: { run(term) }, onRemove: { forget(term) })
                    }
                }
            }

            if !trending.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Trending today").font(.headline)
                    ForEach(trending) { item in
                        row(icon: "flame.fill", title: item.word,
                            detail: "\(item.count) summits", onTap: { run(item.word) })
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Try searching").font(.headline)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(GoalIdeas.seedTerms) { seed in
                            chip(seed.label, selected: false) { run(seed.term) }
                        }
                    }
                }
            }
        }
    }

    private func row(icon: String, title: String, detail: String? = nil,
                     onTap: @escaping () -> Void, onRemove: (() -> Void)? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 24).foregroundStyle(Theme.mutedForeground)
            Text(title).foregroundStyle(Theme.foreground)
            Spacer()
            if let detail { Text(detail).font(.caption).foregroundStyle(Theme.mutedForeground) }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.mutedForeground)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    // MARK: - Ideas (text only, tuned to season, hemisphere, time of day, weekday, region)

    private var ideasSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                Text(context.headline)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.glacier)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Theme.glacier.opacity(0.14), in: Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("For you", selected: topic == nil) { withAnimation(.snappy) { topic = nil } }
                    ForEach(GoalIdea.Topic.allCases) { t in
                        chip(t.title, selected: topic == t) { withAnimation(.snappy) { topic = t } }
                    }
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(ideas) { idea in
                        IdeaCard(idea: idea, isSelected: query == idea.searchTerm)
                            .onTapGesture {
                                withAnimation(.snappy) {
                                    run(idea.searchTerm)
                                }
                            }
                            .contextMenu {
                                Button { UIPasteboard.general.string = idea.text } label: {
                                    Label("Copy goal", systemImage: "doc.on.doc")
                                }
                            }
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned)
            .contentMargins(.horizontal, 24, for: .scrollContent)
            .padding(.horizontal, -24)                       // bleed to the screen edges
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Theme.foreground : Theme.card, in: Capsule())
                .foregroundStyle(selected ? Theme.background : Theme.foreground)
                .overlay(Capsule().stroke(selected ? Color.clear : Theme.border))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Today's public summits (mosaic)

    private var summitsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeader

            if isLoading && results.isEmpty {
                ProgressView().frame(maxWidth: .infinity, minHeight: 160)
            } else if results.isEmpty {
                emptyState
            } else {
                MosaicGrid(items: results) { selectedSummit = $0 }
                    .padding(.horizontal, -SummitUI.bleed)      // grid runs a little wider than the page
            }
        }
    }

    private var sectionHeader: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Ideas for today").displayFont(20)
                Text("From public profiles · gone at midnight")
                    .font(.footnote).foregroundStyle(Theme.mutedForeground)
                }
            Spacer()
            if forYouAvailable {
                chip("Based on my goals", selected: forYouOnly) { withAnimation(.snappy) { forYouOnly.toggle() } }
            }
        }
    }

    @ViewBuilder private var emptyState: some View {
        ContentUnavailableView(
            "No public summits yet today",
            systemImage: "sparkles",
            description: Text("They show up here as people reach them. Set your Summit Privacy to Public to share yours.")
        )
    }

    // MARK: - Actions

    private func run(_ term: String) {
        query = term
        remember(term)
        searchFocused = false
    }

    private func remember(_ term: String) {
        let t = term.trimmingCharacters(in: .whitespaces).lowercased()
        guard t.count >= 2 else { return }
        var list = recents.filter { $0 != t }
        list.insert(t, at: 0)
        recentsRaw = list.prefix(8).joined(separator: "\n")
    }

    private func forget(_ term: String) {
        recentsRaw = recents.filter { $0 != term }.joined(separator: "\n")
    }
}

// MARK: - Idea card (text only)

private struct IdeaCard: View {
    let idea: GoalIdea
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: idea.topic.symbol).font(.footnote.weight(.semibold))
                Text(idea.topic.title).monoCaps(10)
                Spacer()
                if !idea.regions.isEmpty {
                    Text("NEAR YOU")
                        .monoCaps(9)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(idea.topic.tint.opacity(0.2), in: Capsule())
                }
            }
            .foregroundStyle(idea.topic.tint)

            Text(idea.text)
                .displayFont(20, weight: .bold)
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.leading)
                .lineLimit(4)

            Spacer(minLength: 0)

            Label("See today's summits", systemImage: "arrow.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.mutedForeground)
        }
        .padding(16)
        .frame(width: 244, height: 172, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [idea.topic.tint.opacity(isSelected ? 0.45 : 0.28), Theme.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    isSelected ? idea.topic.tint : idea.topic.tint.opacity(0.35),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .animation(.snappy, value: isSelected)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

// MARK: - Instagram-style mosaic: blocks of 6 (one big 2x2 tile + 5 small), alternating sides

private struct MosaicBlockLayout: Layout {
    var mirrored: Bool
    var spacing: CGFloat = 3

    private func frames(width: CGFloat, count: Int) -> [CGRect] {
        let s = spacing
        let t = (width - 2 * s) / 3
        let big = 2 * t + s
        let c0: CGFloat = 0, c1 = t + s, c2 = 2 * (t + s)
        let r2 = 2 * (t + s)
        let all: [CGRect] = mirrored
            ? [CGRect(x: c1, y: 0, width: big, height: big),
               CGRect(x: c0, y: 0, width: t, height: t),
               CGRect(x: c0, y: t + s, width: t, height: t),
               CGRect(x: c0, y: r2, width: t, height: t),
               CGRect(x: c1, y: r2, width: t, height: t),
               CGRect(x: c2, y: r2, width: t, height: t)]
            : [CGRect(x: c0, y: 0, width: big, height: big),
               CGRect(x: c2, y: 0, width: t, height: t),
               CGRect(x: c2, y: t + s, width: t, height: t),
               CGRect(x: c0, y: r2, width: t, height: t),
               CGRect(x: c1, y: r2, width: t, height: t),
               CGRect(x: c2, y: r2, width: t, height: t)]
        return Array(all.prefix(count))
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 360
        let height = frames(width: width, count: subviews.count).map(\.maxY).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let placed = frames(width: bounds.width, count: subviews.count)
        for (index, subview) in subviews.enumerated() where index < placed.count {
            let f = placed[index]
            subview.place(at: CGPoint(x: bounds.minX + f.minX, y: bounds.minY + f.minY),
                          proposal: ProposedViewSize(f.size))
        }
    }
}

private struct MosaicGrid: View {
    let items: [Summit]
    let onSelect: (Summit) -> Void

    private var blocks: [[Summit]] {
        stride(from: 0, to: items.count, by: 6).map { Array(items[$0..<min($0 + 6, items.count)]) }
    }

    var body: some View {
        // Lazy per block: thumbnails and signed URLs are only requested as blocks scroll near.
        LazyVStack(spacing: 3) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                MosaicBlockLayout(mirrored: index % 2 == 1, spacing: 3) {
                    ForEach(Array(block.enumerated()), id: \.element.id) { i, summit in
                        MosaicTile(summit: summit, isBig: i == 0)
                            .onTapGesture { onSelect(summit) }
                    }
                }
            }
        }
    }
}

private struct MosaicTile: View {
    let summit: Summit
    let isBig: Bool

    private var hasMedia: Bool { summit.proofPath != nil }

    var body: some View {
        ZStack {
            if hasMedia { ProofMedia(summit: summit) } else { TextTile(summit: summit) }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .topTrailing) { kindBadge }
        .overlay(alignment: .bottomLeading) {
            if isBig && hasMedia { caption }
        }
        .clipped()
        .contentShape(Rectangle())
    }

    @ViewBuilder private var kindBadge: some View {
        switch summit.proofKind {
        case .video?: badge("play.fill")
        case .audio?: badge("waveform")
        default: EmptyView()
        }
    }

    private func badge(_ symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.5), radius: 3)
            .padding(8)
    }

    private var caption: some View {
        Text(summit.goal)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white)
            .lineLimit(2)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }
}

/// Summits without proof still get a tile: the goal as a typographic card.
private struct TextTile: View {
    let summit: Summit

    var body: some View {
        let warm = summit.id.uuid.0 % 2 == 0                  // stable per summit (hashValue isn't)
        ZStack {
            LinearGradient(colors: [(warm ? Theme.summit : Theme.glacier).opacity(0.35), Theme.card],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Text(summit.goal)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.foreground)
                .multilineTextAlignment(.center)
                .lineLimit(5)
                .padding(10)
        }
    }
}

// MARK: - Media (signed URL resolved lazily, so only visible tiles cost a request)

private enum ThumbCache {
    nonisolated(unsafe) static let images = NSCache<NSString, UIImage>()
}

private struct ProofMedia: View {
    @Environment(CimeStore.self) private var store
    let summit: Summit
    var contentMode: ContentMode = .fill

    @State private var url: URL?
    @State private var videoThumb: UIImage?

    var body: some View {
        ZStack {
            Theme.card
            content
        }
        .task(id: summit.proofPath) {
            guard let path = summit.proofPath else { return }
            if let cached = ThumbCache.images.object(forKey: path as NSString) { videoThumb = cached }
            url = await store.proofURL(path: path)
            if summit.proofKind == .video, videoThumb == nil, let url,
               let frame = await Self.firstFrame(of: url) {
                ThumbCache.images.setObject(frame, forKey: path as NSString)
                videoThumb = frame
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch summit.proofKind {
        case .audio?:
            ZStack {
                LinearGradient(colors: [Theme.glacier.opacity(0.35), Theme.card],
                               startPoint: .top, endPoint: .bottom)
                Image(systemName: "waveform").font(.title).foregroundStyle(Theme.glacier)
            }
        case .video?:
            if let videoThumb {
                Image(uiImage: videoThumb).resizable().aspectRatio(contentMode: contentMode)
            } else {
                Image(systemName: "video").font(.title2).foregroundStyle(Theme.mutedForeground)
            }
        default:
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure: Image(systemName: "photo.badge.exclamationmark").foregroundStyle(Theme.mutedForeground)
                    default: ProgressView()
                    }
                }
            } else {
                ProgressView()
            }
        }
    }

    private static func firstFrame(of url: URL) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        guard let cg = try? await generator.image(at: .zero).image else { return nil }
        return UIImage(cgImage: cg)
    }
}

// MARK: - Detail (anonymous)

private struct SummitDetailSheet: View {
    let summit: Summit
    @Environment(\.dismiss) private var dismiss
    @Environment(CimeStore.self) private var store
    @State private var url: URL?
    @State private var player: AVPlayer?
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Anonymous Climber", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.mutedForeground)
                Spacer()
                Button("Done") { dismiss() }.fontWeight(.semibold)
            }

            Text(summit.goal)
                .font(.title3.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            if summit.proofPath != nil {
                media
                    .frame(maxWidth: .infinity)
                    .frame(maxHeight: 380)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            HStack {
                Text(summit.time).font(.caption).foregroundStyle(Theme.mutedForeground)
                Spacer()
                // borrow the goal for your own day
                Button {
                    UIPasteboard.general.string = summit.goal
                    copied = true
                } label: {
                    Label(copied ? "Copied" : "Copy goal", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.bordered)
                .sensoryFeedback(.success, trigger: copied)
            }

            Spacer()
        }
        .padding(24)
        .task {
            guard let path = summit.proofPath, summit.proofKind != .photo else { return }
            url = await store.proofURL(path: path)
            if summit.proofKind == .video, let url { player = AVPlayer(url: url) }
        }
        .onDisappear { player?.pause() }
    }

    @ViewBuilder private var media: some View {
        switch summit.proofKind {
        case .video?:
            if let player { VideoPlayer(player: player) } else { ProgressView() }
        case .audio?:
            if let url { AudioSlide(url: url) } else { ProgressView() }       // AudioSlide lives in SummitCard.swift
        default:
            ProofMedia(summit: summit, contentMode: .fit)
        }
    }
}

#Preview {
    DiscoverView()
        .environment(CimeStore())
}
