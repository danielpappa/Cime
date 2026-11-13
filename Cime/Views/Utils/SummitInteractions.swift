//
//  SummitInteractions.swift
//  Cime
//
//  Created by Daniel Pappalardo on 13/11/2026.
//

import SwiftUI
import Supabase
import OSLog

// MARK: - Models

struct SummitComment: Identifiable, Equatable {
    let id: UUID
    let goalID: UUID
    let userID: UUID
    let username: String
    let avatarURL: URL?
    let text: String
    let date: Date
}

struct SummitSummary: Equatable {
    var reactionCount = 0
    var commentCount = 0
    var myEmoji: String?
}

/// What the comments sheet needs to know about the post it was opened from.
struct CommentTarget: Identifiable {
    let slide: CardSlide
    let isOwnPost: Bool
    var id: UUID { slide.goalID }
}

// MARK: - Wire types

private struct SummaryRow: Decodable {
    let goalId: UUID
    let reactionCount: Int
    let commentCount: Int
    let myEmoji: String?

    enum CodingKeys: String, CodingKey {
        case goalId = "goal_id"
        case reactionCount = "reaction_count"
        case commentCount = "comment_count"
        case myEmoji = "my_emoji"
    }
}

nonisolated private struct CommentRow: Decodable {
    struct Author: Decodable {
        let username: String
        let avatarUrl: String?
        enum CodingKeys: String, CodingKey {
            case username
            case avatarUrl = "avatar_url"
        }
    }

    let id: UUID
    let goalId: UUID
    let userId: UUID
    let body: String
    let createdAt: Date
    let author: Author?

    enum CodingKeys: String, CodingKey {
        case id, body, author
        case goalId = "goal_id"
        case userId = "user_id"
        case createdAt = "created_at"
    }

    var model: SummitComment {
        SummitComment(id: id, goalID: goalId, userID: userId,
                      username: author?.username ?? "climber",
                      avatarURL: author?.avatarUrl.flatMap(URL.init(string:)),
                      text: body, date: createdAt)
    }
}

private struct ReactionUpsert: Encodable {
    let goalId: UUID
    let userId: UUID
    let emoji: String
    enum CodingKeys: String, CodingKey {
        case emoji
        case goalId = "goal_id"
        case userId = "user_id"
    }
}

private struct CommentInsert: Encodable {
    let goalId: UUID
    let userId: UUID
    let body: String
    enum CodingKeys: String, CodingKey {
        case body
        case goalId = "goal_id"
        case userId = "user_id"
    }
}

private struct IdRow: Decodable { let id: UUID }

private let commentSelect = "id, goal_id, user_id, body, created_at, author:profiles!user_id(username, avatar_url)"

// MARK: - Store

/// Reactions and comments for the summits currently on screen. Optimistic for reactions,
/// live (realtime) for counts and comment threads.
@MainActor
@Observable
final class SummitInteractions {
    private(set) var summaries: [UUID: SummitSummary] = [:]
    private(set) var commentsTick = 0          // bumps when any comment changes; sheets reload on it

    @ObservationIgnored private weak var store: CimeStore?
    @ObservationIgnored private var tracked: Set<UUID> = []
    @ObservationIgnored private var channel: RealtimeChannelV2?
    @ObservationIgnored private var streamTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var refreshTask: Task<Void, Never>?
    @ObservationIgnored private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Cime", category: "interactions")

    func bind(_ store: CimeStore) { self.store = store }

    func summary(for goal: UUID) -> SummitSummary { summaries[goal] ?? SummitSummary() }

    // MARK: Counts

    /// Tell the store which summits are on screen; it fetches their counts.
    func track(_ ids: [UUID]) async {
        let set = Set(ids)
        guard set != tracked else { return }
        tracked = set
        await refresh()
    }

    func refresh() async {
        guard let client = store?.client, !tracked.isEmpty else { return }
        do {
            let rows: [SummaryRow] = try await client
                .rpc("summit_interactions", params: ["p_goal_ids": tracked.map(\.uuidString)])
                .execute().value
            var next: [UUID: SummitSummary] = [:]
            for r in rows {
                next[r.goalId] = SummitSummary(reactionCount: r.reactionCount,
                                               commentCount: r.commentCount,
                                               myEmoji: r.myEmoji)
            }
            summaries = next
        } catch {
            log.error("summit_interactions failed: \(error.localizedDescription)")
        }
    }

    // MARK: Reactions

    /// emoji == nil removes my reaction. One reaction per person per summit; picking another replaces it.
    func react(goal: UUID, emoji: String?) async {
        guard let store, let me = store.userId else { return }
        let before = summary(for: goal)
        var after = before
        if before.myEmoji == nil, emoji != nil { after.reactionCount += 1 }
        if before.myEmoji != nil, emoji == nil { after.reactionCount = max(0, after.reactionCount - 1) }
        after.myEmoji = emoji
        summaries[goal] = after                              // optimistic

        do {
            if let emoji {
                try await store.client.from("reactions")
                    .upsert(ReactionUpsert(goalId: goal, userId: me, emoji: emoji), onConflict: "goal_id,user_id")
                    .execute()
            } else {
                try await store.client.from("reactions").delete()
                    .eq("goal_id", value: goal)
                    .eq("user_id", value: me)
                    .execute()
            }
        } catch {
            summaries[goal] = before                         // rollback
            store.lastError = "Couldn't update your reaction"
            log.error("react failed: \(error.localizedDescription)")
        }
    }

    // MARK: Comments

    func comments(for goal: UUID) async -> [SummitComment] {
        guard let client = store?.client else { return [] }
        do {
            let rows: [CommentRow] = try await client.from("comments")
                .select(commentSelect)
                .eq("goal_id", value: goal)
                .order("created_at", ascending: true)
                .limit(200)
                .execute().value
            return rows.map(\.model)
        } catch {
            log.error("comments failed: \(error.localizedDescription)")
            return []
        }
    }

    func addComment(goal: UUID, text: String) async -> SummitComment? {
        guard let store, let me = store.userId else { return nil }
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty, body.count <= 280 else { return nil }
        do {
            let row: CommentRow = try await store.client.from("comments")
                .insert(CommentInsert(goalId: goal, userId: me, body: body))
                .select(commentSelect)
                .single()
                .execute().value
            summaries[goal, default: SummitSummary()].commentCount += 1
            return row.model
        } catch {
            store.lastError = "Couldn't post your comment"
            log.error("addComment failed: \(error.localizedDescription)")
            return nil
        }
    }

    func deleteComment(_ comment: SummitComment) async -> Bool {
        guard let store else { return false }
        do {
            // ask for the deleted row back: RLS answers "204, 0 rows" for a blocked delete
            let rows: [IdRow] = try await store.client.from("comments").delete()
                .eq("id", value: comment.id)
                .select("id")
                .execute().value
            guard !rows.isEmpty else { return false }
            summaries[comment.goalID, default: SummitSummary()].commentCount =
                max(0, summary(for: comment.goalID).commentCount - 1)
            return true
        } catch {
            store.lastError = "Couldn't delete the comment"
            return false
        }
    }

    // MARK: Realtime

    func startRealtime() async {
        guard channel == nil, let client = store?.client else { return }
        let ch = client.channel("cime-interactions")
        let reactionChanges = ch.postgresChange(AnyAction.self, schema: "public", table: "reactions")
        let commentChanges = ch.postgresChange(AnyAction.self, schema: "public", table: "comments")
        channel = ch
        do {
            try await ch.subscribeWithError()
        } catch {
            channel = nil
            log.error("interactions realtime failed: \(error.localizedDescription)")
            return
        }
        streamTasks = [
            Task { [weak self] in
                for await _ in reactionChanges { self?.scheduleRefresh() }
            },
            Task { [weak self] in
                for await _ in commentChanges {
                    self?.commentsTick += 1
                    self?.scheduleRefresh()
                }
            }
        ]
    }

    func stopRealtime() async {
        streamTasks.forEach { $0.cancel() }
        streamTasks = []
        refreshTask?.cancel(); refreshTask = nil
        if let ch = channel {
            await store?.client.removeChannel(ch)
            channel = nil
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await self?.refresh()
        }
    }
}

// MARK: - Comments sheet

struct CommentsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(CimeStore.self) private var store
    @Environment(SummitInteractions.self) private var interactions
    let target: CommentTarget

    @State private var comments: [SummitComment] = []
    @State private var isLoading = true
    @State private var draft = ""
    @State private var isSending = false

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading && comments.isEmpty {
                    ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if comments.isEmpty {
                    ContentUnavailableView(
                        "No comments yet",
                        systemImage: "bubble.right",
                        description: Text("Be the first to cheer this summit on.")
                    )
                } else {
                    list
                }
            }
            .navigationTitle("Comments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.font(.subheadline.weight(.semibold))
                }
            }
            .safeAreaInset(edge: .bottom) { composer }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        // loads on open and again whenever anyone adds/removes a comment (realtime)
        .task(id: interactions.commentsTick) {
            comments = await interactions.comments(for: target.slide.goalID)
            isLoading = false
        }
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    ForEach(comments) { comment in
                        row(comment).id(comment.id)
                    }
                }
                .padding(20)
            }
            .onChange(of: comments.count) { _, _ in
                if let last = comments.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
            }
        }
    }

    private func row(_ comment: SummitComment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(url: comment.avatarURL, letter: comment.username, size: 34)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(comment.username).font(.subheadline.weight(.semibold))
                    Text(comment.date, style: .relative)
                        .font(.caption)
                        .foregroundStyle(Theme.mutedForeground)
                }
                Text(comment.text).font(.subheadline)
            }
            Spacer(minLength: 0)
        }
        .contextMenu {
            // your own comments, or anything on your own summit
            if comment.userID == store.userId || target.isOwnPost {
                Button(role: .destructive) {
                    Task {
                        if await interactions.deleteComment(comment) {
                            comments.removeAll { $0.id == comment.id }
                        }
                    }
                } label: { Label("Delete", systemImage: "trash") }
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Add a comment…", text: $draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Theme.card)
                .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.border))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                .onChange(of: draft) { _, new in
                    if new.count > 280 { draft = String(new.prefix(280)) }
                }

            Button(action: send) {
                Group {
                    if isSending { ProgressView() }
                    else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(canSend ? Theme.summit : Theme.mutedForeground.opacity(0.4))
                    }
                }
                .frame(width: 34, height: 34)
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isSending else { return }
        isSending = true
        Task {
            defer { isSending = false }
            if let comment = await interactions.addComment(goal: target.slide.goalID, text: text) {
                if !comments.contains(where: { $0.id == comment.id }) { comments.append(comment) }
                draft = ""
            }
        }
    }
}
