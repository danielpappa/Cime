import Foundation
import SwiftUI
import AVKit

struct DiscoverView: View {
    @Environment(CimeStore.self) private var store
    @State private var query = ""
    @State private var searchResults: [Summit] = []
    @State private var selectedSummit: Summit?
    @State private var isLoading = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    /// Re-run when the query OR the recommendation keywords change.
    private var taskKey: String {
        "\(query)|\(store.userInterestKeywords.joined(separator: ","))"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .bottom) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                                .monoCaps(10)
                                .foregroundStyle(Theme.glacier)
                            Text("Discover")
                                .displayFont(36)
                        }
                    }

                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)

                        TextField("Search keywords (e.g., running, reading)...", text: $query)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)

                        if !query.isEmpty {
                            Button {
                                query = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if query.isEmpty && !store.userInterestKeywords.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                Text("Based on your goals:")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                ForEach(store.userInterestKeywords, id: \.self) { keyword in
                                    Button {
                                        query = keyword
                                    } label: {
                                        Text("#\(keyword)")
                                            .font(.caption)
                                            .fontWeight(.medium)
                                            .padding(.horizontal, 10)
                                            .padding(.vertical, 5)
                                            .background(Color.accentColor.opacity(0.12))
                                            .foregroundColor(.accentColor)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }

                    if isLoading && searchResults.isEmpty {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 120)
                    } else if !searchResults.isEmpty {
                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(searchResults) { summit in
                                AchievementGridCard(summit: summit)
                                    .onTapGesture { selectedSummit = summit }
                            }
                        }
                    } else if !query.isEmpty {
                        ContentUnavailableView(
                            "No achievements found",
                            systemImage: "text.magnifyingglass",
                            description: Text("Try searching for another keyword or topic.")
                        )
                        .padding(.top, 32)
                    } else {
                        ContentUnavailableView(
                            "Nothing to discover yet",
                            systemImage: "sparkles",
                            description: Text("Public summits from the last two weeks will show up here.")
                        )
                        .padding(.top, 32)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 100)
            }
            .refreshable { searchResults = await store.searchSummits(query: query) }
            .navigationBarHidden(true)
            .task(id: taskKey) {
                if !query.isEmpty {
                    try? await Task.sleep(for: .milliseconds(300))     // debounce typing
                    guard !Task.isCancelled else { return }
                }
                isLoading = true
                let found = await store.searchSummits(query: query)
                guard !Task.isCancelled else { return }
                searchResults = found
                isLoading = false
            }
            .sheet(item: $selectedSummit) { summit in
                AnonymousSummitDetailView(summit: summit)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

// MARK: - Media (signed URL resolved lazily, so only visible cards cost a request)

private struct ProofMedia: View {
    @Environment(CimeStore.self) private var store
    let summit: Summit
    var contentMode: ContentMode = .fill

    @State private var url: URL?
    @State private var videoThumb: UIImage?

    var body: some View {
        ZStack {
            Color(.secondarySystemBackground)
            content
        }
        .task(id: summit.proofPath) {
            guard let path = summit.proofPath else { return }
            url = await store.proofURL(path: path)
            if summit.proofKind == .video, let url {
                videoThumb = await Self.firstFrame(of: url)
            }
        }
    }

    @ViewBuilder private var content: some View {
        switch summit.proofKind {
        case .audio?:
            Image(systemName: "waveform").font(.largeTitle).foregroundColor(.secondary)
        case .video?:
            if let videoThumb {
                Image(uiImage: videoThumb).resizable().aspectRatio(contentMode: contentMode)
                    .overlay(
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.9))
                            .shadow(radius: 4)
                    )
            } else {
                Image(systemName: "video").font(.largeTitle).foregroundColor(.secondary)
            }
        default:
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().aspectRatio(contentMode: contentMode)
                    case .failure: Image(systemName: "photo.badge.exclamationmark").foregroundColor(.secondary)
                    default: ProgressView()
                    }
                }
            } else if summit.proofPath != nil {
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

// MARK: - Grid Card View (image first, caption on top of it)

private struct AchievementGridCard: View {
    let summit: Summit

    private var hasMedia: Bool { summit.proofPath != nil }

    var body: some View {
        Color.clear
            .aspectRatio(4 / 5, contentMode: .fit)
            .overlay {
                if hasMedia { ProofMedia(summit: summit) }
                else { Color(.secondarySystemBackground) }
            }
            .overlay(alignment: hasMedia ? .bottomLeading : .topLeading) { caption }
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(summit.goal)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(hasMedia ? 2 : 6)
            Text(summit.time)
                .font(.caption2)
                .opacity(0.8)
        }
        .foregroundColor(hasMedia ? .white : .primary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            if hasMedia {
                LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

// MARK: - Anonymous Detail Modal View

private struct AnonymousSummitDetailView: View {
    let summit: Summit
    @Environment(\.dismiss) private var dismiss
    @Environment(CimeStore.self) private var store
    @State private var player: AVPlayer?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Anonymous Climber", systemImage: "person.crop.circle.badge.questionmark")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)

                Spacer()

                Button("Done") { dismiss() }
                    .fontWeight(.semibold)
            }
            .padding(.bottom, 4)

            Text(summit.goal)
                .font(.title3)
                .fontWeight(.bold)
                .fixedSize(horizontal: false, vertical: true)

            if summit.proofPath != nil {
                Group {
                    if summit.proofKind == .video, let player {
                        VideoPlayer(player: player)
                    } else {
                        ProofMedia(summit: summit, contentMode: .fit)
                    }
                }
                .frame(maxHeight: 360)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            Text(summit.time)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(24)
        .task {
            guard summit.proofKind == .video, let path = summit.proofPath,
                  let url = await store.proofURL(path: path) else { return }
            player = AVPlayer(url: url)
        }
        .onDisappear { player?.pause() }
    }
}

#Preview {
    DiscoverView()
        .environment(CimeStore())
}
