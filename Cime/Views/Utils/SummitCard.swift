//
//  SummitCard.swift
//  Cime
//
//  Created by Daniel Pappalardo on 13/11/2026.
//

import SwiftUI
import AVKit

// MARK: - Tunables

enum SummitUI {
    static let heightFraction: CGFloat = 0.78     // Card height as a share of the visible scroll area.
    static let corner: CGFloat = 28
    static let bleed: CGFloat = 12                // cards extend this far into the 24 pt page margin
    static let blurRadius: CGFloat = 32           // locked summits
    static let emojis = ["❤️", "🔥", "💪", "🏔️", "🧢", "🤌"]
}

// MARK: - Model

struct CardSlide: Identifiable {
    struct Proof {
        var kind: ProofKind?
        var jpeg: Data?          // local capture (own)
        var url: URL?            // already-signed URL (friends)
        var path: String?        // storage path, resolved lazily (own, after relaunch)
        var badge: String?       // e.g. "2h"
        var blurred = false      // locked: real media behind a blur
    }
    enum Content {
        case proof(Proof)
        case message(symbol: String, text: String)
    }

    let goalID: UUID             // reactions and comments hang off this
    let caption: String
    let isLocked: Bool
    var lockHint: String? = nil
    let content: Content
    var id: UUID { goalID }
}

// MARK: - Card

struct SummitCard: View {
    @Environment(SummitInteractions.self) private var interactions

    let name: String
    let slides: [CardSlide]
    let isOwn: Bool
    let avatar: AnyView
    var profileRoute: AppRoute? = nil           // tapping the avatar opens this profile
    let onComments: (CardSlide) -> Void

    @State private var page = 0
    @State private var showPicker = false
    @State private var burstVisible = false
    @State private var burstTick = 0
    @State private var reactTick = 0

    private var current: CardSlide? { slides.indices.contains(page) ? slides[page] : slides.first }
    private var locked: Bool { current?.isLocked ?? true }
    private var summary: SummitSummary {
        current.map { interactions.summary(for: $0.goalID) } ?? SummitSummary()
    }

    var body: some View {
        Theme.card
            .containerRelativeFrame(.vertical) { length, _ in length * SummitUI.heightFraction }
            .frame(maxWidth: .infinity)
            .overlay { pager }                                       // media fills the whole card
            .overlay(alignment: .topTrailing) {
                PageDots(count: 3, available: slides.count, current: page)
            }
            .overlay { burstHeart }
            //.overlay(alignment: .bottom) { info }
            //.overlay(alignment: .bottomTrailing) { rail }
            .overlay(alignment: .bottom) { bottomBar }
            .overlay { picker }
            .clipShape(RoundedRectangle(cornerRadius: SummitUI.corner, style: .continuous))
            .shadow(color: .black.opacity(0.22), radius: 16, y: 8)
            .contentShape(RoundedRectangle(cornerRadius: SummitUI.corner, style: .continuous))
            .onTapGesture(count: 2, perform: doubleTap)
            .sensoryFeedback(.selection, trigger: page)
            .sensoryFeedback(.success, trigger: burstTick)
            .sensoryFeedback(.impact(weight: .light), trigger: reactTick)
    }

    // MARK: Pieces

    private var pager: some View {
        TabView(selection: $page) {
            ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                SlideView(slide: slide).tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }

    private var info: some View {
        HStack(alignment: .bottom, spacing: 12) {
            avatarButton

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.semibold))
                Text(current?.caption ?? "")
                    .font(.footnote)
                    .opacity(0.9)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 4)
        .padding(16)
        .padding(.top, 56)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        )
    }

    /// The user icon opens that person's profile (your own card has no destination).
    @ViewBuilder private var avatarButton: some View {
        let icon = avatar.overlay(Circle().stroke(.white.opacity(0.85), lineWidth: 1.5))
        if let profileRoute {
            NavigationLink(value: profileRoute) { icon }.buttonStyle(.plain)
        } else {
            icon
        }
    }

    // MARK: Actions rail (Snap / TikTok style, down the right edge)

    private var rail: some View {
        VStack(spacing: 22) {
            reactionControl
            commentButton
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.45), radius: 6)
        .padding(.trailing, 16)
        .padding(.bottom, 112)
    }

    private func railItem<Icon: View>(count: Int, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 6) {
            icon()
            if count > 0 {
                Text("\(count)").font(.footnote.weight(.semibold))
            }
        }
        .frame(minWidth: 40, minHeight: 40)
        .contentShape(Rectangle())
    }
    
    private var bottomBar: some View {
        HStack(alignment: .center, spacing: 12) {
            avatarButton

            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline.weight(.semibold))
                Text(current?.caption ?? "")
                    .font(.footnote)
                    .opacity(0.9)
                    .lineLimit(2)
            }

            Spacer(minLength: 12)

            // Horizontal action buttons
            HStack(spacing: 16) {
                reactionControl
                commentButton
            }
        }
        .foregroundStyle(.white)
        .shadow(color: .black.opacity(0.35), radius: 4)
        .padding(16)
        .background(
            LinearGradient(colors: [.clear, .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
        )
    }

    @ViewBuilder private var reactionControl: some View {
        let count = locked ? 0 : summary.reactionCount
        if isOwn {
            // you can't react to your own summit, but you see how many reactions it got
            if count > 0 {
                railItem(count: count) { Image(systemName: "heart.fill").font(.system(size: 26)) }
            }
        } else {
            railItem(count: count) {
                if let emoji = summary.myEmoji { Text(emoji).font(.system(size: 32)) }
                else { Image(systemName: "heart").font(.system(size: 28, weight: .semibold)) }
            }
            .onTapGesture(perform: toggleReaction)                            // tap = ❤️ on/off
            .onLongPressGesture(minimumDuration: 0.35) {                      // hold = emoji picker
                guard !locked else { return }
                withAnimation(.spring(duration: 0.3)) { showPicker = true }
            }
            .opacity(locked ? 0.4 : 1)
            .allowsHitTesting(!locked)
            .accessibilityLabel("React")
            .accessibilityAddTraits(.isButton)
        }
    }

    private var commentButton: some View {
        Button {
            if let slide = current { onComments(slide) }
        } label: {
            railItem(count: locked ? 0 : summary.commentCount) {
                Image(systemName: "bubble.right").font(.system(size: 26, weight: .semibold))
            }
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.4 : 1)
        .accessibilityLabel("Comments")
    }

    @ViewBuilder private var picker: some View {
        if showPicker {
            ZStack(alignment: .bottomTrailing) {
                Color.black.opacity(0.001)                                    // tap anywhere to dismiss
                    .onTapGesture { withAnimation(.spring(duration: 0.25)) { showPicker = false } }

                HStack(spacing: 14) {
                    ForEach(SummitUI.emojis, id: \.self) { emoji in
                        Text(emoji)
                            .font(.system(size: 30))
                            .scaleEffect(summary.myEmoji == emoji ? 1.25 : 1)
                            .onTapGesture { pick(emoji) }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.trailing, 72)
                .padding(.bottom, 112)
                .transition(.scale(scale: 0.6, anchor: .bottomTrailing).combined(with: .opacity))
            }
        }
    }

    private var burstHeart: some View {
        Image(systemName: "heart.fill")
            .font(.system(size: 110))
            .foregroundStyle(.white)
            .shadow(color: .black.opacity(0.35), radius: 16)
            .scaleEffect(burstVisible ? 1 : 0.4)
            .opacity(burstVisible ? 1 : 0)
            .animation(.spring(response: 0.35, dampingFraction: 0.55), value: burstVisible)
            .allowsHitTesting(false)
    }

    // MARK: Behaviour (all real now: goes through SummitInteractions)

    private func toggleReaction() {
        guard let slide = current, !locked, !isOwn else { return }
        reactTick += 1
        let emoji: String? = summary.myEmoji == nil ? "❤️" : nil
        Task { await interactions.react(goal: slide.goalID, emoji: emoji) }
    }

    private func pick(_ emoji: String) {
        guard let slide = current else { return }
        reactTick += 1
        let next: String? = summary.myEmoji == emoji ? nil : emoji
        Task { await interactions.react(goal: slide.goalID, emoji: next) }
        withAnimation(.spring(duration: 0.25)) { showPicker = false }
    }

    private func doubleTap() {
        guard !isOwn, !locked, let slide = current else { return }
        if summary.myEmoji == nil {
            Task { await interactions.react(goal: slide.goalID, emoji: "❤️") }
        }
        burstTick += 1
        burstVisible = true
        Task {
            try? await Task.sleep(for: .milliseconds(750))
            burstVisible = false
        }
    }
}

extension View {
    /// Focused card at full size; cards that are only partly in view shrink toward it and dim.
    func focusCarousel() -> some View {
        scrollTransition(axis: .vertical) { content, phase in
            content
                .scaleEffect(1 - 0.14 * abs(phase.value), anchor: phase.value < 0 ? .bottom : .top)
                .opacity(1 - 0.45 * abs(phase.value))
        }
    }
    
    /// Tapping a card that isn't focused scrolls to it. The focused card keeps its buttons.
    func focusOnTap(id: String, focused: Binding<String?>) -> some View {
        overlay {
            if let current = focused.wrappedValue, current != id {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture { withAnimation(.snappy) { focused.wrappedValue = id } }
            }
        }
    }
}

// MARK: - Three dots, top right: one per peak. Brighter = reached, big = current page.

private struct PageDots: View {
    let count: Int
    let available: Int
    let current: Int

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Circle()
                    .fill(.white.opacity(i == current ? 1 : (i < available ? 0.5 : 0.2)))
                    .frame(width: i == current ? 8 : 6, height: i == current ? 8 : 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(14)
        .animation(.snappy, value: current)
        .allowsHitTesting(false)
    }
}

// MARK: - One page (always fills the whole card)

private struct SlideView: View {
    @Environment(CimeStore.self) private var store
    let slide: CardSlide

    @State private var resolvedURL: URL?
    @State private var resolveFailed = false

    private var pathToResolve: String? {
        if case .proof(let p) = slide.content, p.jpeg == nil, p.url == nil { return p.path }
        return nil
    }

    var body: some View {
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay { content }
            .overlay { lockPill }
            .overlay(alignment: .topLeading) { timeBadge }
            .clipped()
            .task(id: pathToResolve) {
                guard let path = pathToResolve else { return }
                resolvedURL = await store.proofURL(path: path)
                resolveFailed = resolvedURL == nil
            }
    }

    @ViewBuilder private var lockPill: some View {
        if let hint = slide.lockHint {
            VStack(spacing: 10) {
                Image(systemName: "lock.fill").font(.title2)
                Text(hint).font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    @ViewBuilder private var timeBadge: some View {
        if case .proof(let p) = slide.content, let badge = p.badge {
            Text(badge)
                .monoCaps(10)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(14)
        }
    }

    @ViewBuilder private var content: some View {
        switch slide.content {
        case .message(let symbol, let text): message(symbol, text)
        case .proof(let p): proof(p)
        }
    }

    @ViewBuilder private func proof(_ p: CardSlide.Proof) -> some View {
        if let data = p.jpeg { local(data, p) } else { remote(p) }
    }

    @ViewBuilder private func local(_ data: Data, _ p: CardSlide.Proof) -> some View {
        switch p.kind ?? .photo {
        case .photo:
            if let ui = UIImage(data: data) { Image(uiImage: ui).resizable().scaledToFill() }
            else { message("photo", "No proof yet") }
        case .video:
            LocalVideo(data: data)
        case .audio:
            ProofMediaView(jpeg: data, kind: .audio)
        }
    }

    @ViewBuilder private func remote(_ p: CardSlide.Proof) -> some View {
        let url = p.url ?? resolvedURL
        switch (p.kind, url) {
        case (.video?, let url?):
            FeedVideo(url: url, playing: !p.blurred)
                .blur(radius: p.blurred ? SummitUI.blurRadius : 0)
                .scaleEffect(p.blurred ? 1.2 : 1)           // hides the soft edges a blur leaves
        case (.audio?, let url?) where !p.blurred: AudioSlide(url: url)
        case (.audio?, _): message("waveform", "")
        case (_, let url?):
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image.resizable().scaledToFill()
                        .blur(radius: p.blurred ? SummitUI.blurRadius : 0)
                        .scaleEffect(p.blurred ? 1.2 : 1)
                } else if phase.error != nil {
                    message("exclamationmark.triangle", "Couldn't load")
                } else {
                    ProgressView()
                }
            }
        default:
            if p.path != nil && !resolveFailed { ProgressView() }
            else { message("photo", "No proof yet") }
        }
    }

    private func message(_ symbol: String, _ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.system(size: 40))
                .foregroundStyle(Theme.glacier)
            if !text.isEmpty {
                Text(text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.mutedForeground)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct AudioSlide: View {
    let url: URL
    @State private var player: AVPlayer?
    @State private var playing = false

    var body: some View {
        VStack(spacing: 14) {
            Button(action: toggle) {
                Image(systemName: playing ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 76)).foregroundStyle(Theme.summit)
            }
            Text("Voice note").font(.subheadline.weight(.medium)).foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear { player?.pause(); playing = false }
        .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { note in
            guard let item = note.object as? AVPlayerItem, item === player?.currentItem else { return }
            playing = false
            player?.seek(to: .zero)
        }
    }

    private func toggle() {
        try? AVAudioSession.sharedInstance().setCategory(.playback)    // audible even on silent
        if player == nil { player = AVPlayer(url: url) }
        if playing { player?.pause() } else { player?.play() }
        playing.toggle()
    }
}

// MARK: - Video that fills the card (VideoPlayer letterboxes and leaves side strips)

private struct FillPlayerView: UIViewRepresentable {
    let player: AVPlayer?

    final class PlayerLayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> PlayerLayerView {
        let view = PlayerLayerView()
        view.playerLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PlayerLayerView, context: Context) {
        view.playerLayer.player = player
    }
}

/// Muted, looping, autoplays while visible. `playing: false` shows the paused first frame.
private struct FeedVideo: View {
    let url: URL
    var playing = true
    @State private var player: AVPlayer?

    var body: some View {
        FillPlayerView(player: player)
            .onAppear {
                let p = AVPlayer(url: url)
                p.isMuted = true
                p.actionAtItemEnd = .none
                player = p
                if playing { p.play() }
            }
            .onDisappear { player?.pause() }
            .onChange(of: playing) { _, on in on ? player?.play() : player?.pause() }
            .onReceive(NotificationCenter.default.publisher(for: .AVPlayerItemDidPlayToEndTime)) { note in
                guard let item = note.object as? AVPlayerItem, item === player?.currentItem else { return }
                player?.seek(to: .zero)
                if playing { player?.play() }
            }
    }
}

private struct LocalVideo: View {
    let data: Data
    @State private var url: URL?

    var body: some View {
        Group {
            if let url { FeedVideo(url: url) } else { Color.clear }
        }
        .task {
            let tmp = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
            try? data.write(to: tmp)
            url = tmp
        }
    }
}
