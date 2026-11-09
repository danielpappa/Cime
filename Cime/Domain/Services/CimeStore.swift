import Foundation
import SwiftUI
import Supabase
import OSLog
import WidgetKit

enum FollowState { case none, requested, following }

private struct TextRow: Decodable { let text: String }

@MainActor
@Observable
final class CimeStore {
    @ObservationIgnored let client: SupabaseClient

    // Auth / user state
    var supabaseSession: Session?
    var appSession: AppSession?
    var profile: Profile?
    var isBootstrapping = true
    var lastError: String?

    // Content
    var day: Day
    var friendSummits: [FriendSummit] = []
    var stats: StatsRow = .zero
    var userInterestKeywords: [String] = []
    var celebrationToken = 0

    // Social graph
    private var followingMap: [String: UUID] = [:]          // ACCEPTED follows: username -> id
    private var pendingIds: Set<UUID> = []                  // requests I sent that aren't accepted yet
    var incomingRequests: [FollowRequest] = []              // requests waiting for MY answer

    var following: [String] { followingMap.keys.sorted() }
    var outgoingRequestCount: Int { pendingIds.count }
    var streakDisplay: Int { stats.streak }
    var userId: UUID? { supabaseSession?.user.id }

    func followState(for userId: UUID) -> FollowState {
        if followingMap.values.contains(userId) { return .following }
        if pendingIds.contains(userId) { return .requested }
        return .none
    }

    // Internals
    @ObservationIgnored private var authTask: Task<Void, Never>?
    @ObservationIgnored private var realtimeTasks: [Task<Void, Never>] = []
    @ObservationIgnored private var realtimeChannel: RealtimeChannelV2?
    @ObservationIgnored private var syncChain: Task<Void, Never>?
    @ObservationIgnored private var feedRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var socialRefreshTask: Task<Void, Never>?
    @ObservationIgnored private var historyTexts: [String] = []
    @ObservationIgnored private var signedURLCache: [String: (url: URL, expires: Date)] = [:]
    @ObservationIgnored private let log = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "Cime", category: "store")

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(client: SupabaseClient = .cime) {
        self.client = client
        self.day = Day(date: Self.todayKey(), goals: [])

        let changes = client.auth.authStateChanges
        authTask = Task { [weak self] in
            for await (event, session) in changes {
                await self?.handleAuth(event: event, session: session)
            }
        }
        
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(8))
            guard let self, self.isBootstrapping, self.supabaseSession == nil else { return }
            self.isBootstrapping = false
        }
    }

    // MARK: - Auth lifecycle

    @ObservationIgnored private var needsReload = false

    private func handleAuth(event: AuthChangeEvent, session: Session?) async {
        switch event {
        case .initialSession:
            guard let stored = session else { clearState(); isBootstrapping = false; return }
            do {
                let valid: Session
                if stored.isExpired { valid = try await client.auth.session }   // refreshes explicitly
                else { valid = stored }
                await activate(valid)
            } catch is AuthError {
                // the refresh token itself was rejected (revoked, signed out elsewhere): log out
                clearState(); isBootstrapping = false
            } catch {
                // offline or a network problem: stay logged in, reload once the token refreshes
                needsReload = true
                await activate(stored)
            }

        case .signedIn, .userUpdated:
            guard let session, !session.isExpired else { return }
            await activate(session)

        case .tokenRefreshed:
            guard let session else { return }
            supabaseSession = session
            if appSession == nil { await activate(session) }
            else if needsReload { needsReload = false; await bootstrap(userId: session.user.id) }

        case .signedOut:
            await stopRealtime()
            clearState()
            isBootstrapping = false

        default:
            break
        }
    }

    private func activate(_ session: Session) async {
        let userChanged = supabaseSession?.user.id != session.user.id
        supabaseSession = session
        appSession = AppSession(provider: Self.provider(of: session.user), email: session.user.email)
        if userChanged { await bootstrap(userId: session.user.id) } else { isBootstrapping = false }
    }

    private static func provider(of user: User) -> AuthProvider {
        switch user.appMetadata["provider"]?.stringValue {
        case "apple": .apple
        case "google": .google
        default: .email
        }
    }

    private func publishWidgetState() {
        Shared.defaults?.set(day.date, forKey: Shared.dayKey)
        Shared.defaults?.set(Self.unlockedCount(goals: day.goals), forKey: Shared.countKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    private func clearState() {
        supabaseSession = nil
        appSession = nil
        profile = nil
        day = Day(date: Self.todayKey(), goals: [])
        followingMap = [:]
        pendingIds = []
        incomingRequests = []
        friendSummits = []
        userInterestKeywords = []
        historyTexts = []
        stats = .zero
        signedURLCache = [:]
        
        Task { await ReminderScheduler.apply(enabled: false) }
        publishWidgetState()
    }

    private func bootstrap(userId: UUID) async {
        isBootstrapping = true
        defer { isBootstrapping = false }
        async let p: Void = fetchProfile(userId: userId)
        async let g: Void = fetchTodayGoals(userId: userId)
        async let f: Void = fetchFollowing(userId: userId)
        async let r: Void = fetchIncomingRequests()
        async let s: Void = fetchFriendSummits()
        async let st: Void = refreshStats()
        async let k: Void = fetchRecentGoalTexts()
        _ = await (p, g, f, r, s, st, k)
        await startRealtime()
    }

    /// Call from `.onChange(of: scenePhase)` when becoming .active.
    func refreshOnForeground() async {
        guard let userId else { return }
        await syncChain?.value
        await fetchTodayGoals(userId: userId)
        async let f: Void = fetchFollowing(userId: userId)
        async let r: Void = fetchIncomingRequests()
        async let s: Void = fetchFriendSummits()
        async let st: Void = refreshStats()
        _ = await (f, r, s, st)
    }

    func refreshDayIfNeeded() {
        guard day.date != Self.todayKey(), let userId else { return }
        Task { await fetchTodayGoals(userId: userId) }
    }

    // MARK: - Auth actions

    func signIn(identifier: String, password: String) async throws {
        let cleaned = identifier.trimmingCharacters(in: .whitespaces)
        var emailToUse = cleaned

        // Username login: usernames are stored lowercase, so look them up lowercase.
        if !cleaned.contains("@") {
            let email: String? = try await client
                .rpc("get_email_by_username", params: ["p_username": cleaned.lowercased()])
                .execute()
                .value
            guard let resolved = email else { throw StoreError.userNotFound }
            emailToUse = resolved
        }
        try await client.auth.signIn(email: emailToUse, password: password)
    }

    /// Call before signUp so the user gets a clear error instead of a silent fallback name.
    func isUsernameAvailable(_ username: String) async -> Bool {
        let u = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard Self.isValid(username: u) else { return false }
        do {
            let ok: Bool = try await client
                .rpc("username_available", params: ["p_username": u])
                .execute().value
            return ok
        } catch {
            return true     // the database constraint remains the source of truth
        }
    }

    /// Returns true when email confirmation is required (no session yet).
    @discardableResult
    func signUp(email: String, username: String, password: String) async throws -> Bool {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: ["username": .string(username.trimmingCharacters(in: .whitespaces).lowercased())]
        )
        return response.session == nil
    }

    func signInWithApple(idToken: String, nonce: String) async throws {
        try await client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: nonce))
    }

    func signInWithGoogle() async throws {
        try await client.auth.signInWithOAuth(
            provider: .google,
            redirectTo: URL(string: "cime://login-callback")
        )
    }

    func sendPasswordReset(email: String) async throws {
        try await client.auth.resetPasswordForEmail(email)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    func deleteAccount() async throws {
        guard let userId else { throw StoreError.notSignedIn }
        let folder = userId.uuidString.lowercased()
        for bucket in ["avatars", "proofs"] {
            let files = (try? await client.storage.from(bucket).list(path: folder)) ?? []
            let paths = files.map { "\(folder)/\($0.name)" }
            if !paths.isEmpty { _ = try? await client.storage.from(bucket).remove(paths: paths) }
        }
        try await client.rpc("delete_my_account").execute()
        try? await client.auth.signOut(scope: .local)
    }

    // MARK: - Profile

    func fetchProfile(userId: UUID) async {
        do {
            let rows: [ProfileRow] = try await client
                .from("profiles").select().eq("id", value: userId).limit(1).execute().value
            guard let row = rows.first else {
                report("Your profile is missing", StoreError.saveFailed)
                return
            }
            profile = Profile(row: row, avatarJPEG: profile?.avatarJPEG)
            await ReminderScheduler.apply(enabled: profile?.reminders ?? false)
        } catch {
            report("Couldn't load your profile", error)
        }
    }

    static func isValid(username: String) -> Bool {
        username.range(of: "^[a-z0-9_.]{3,20}$", options: .regularExpression) != nil
    }

    /// FIX: PostgREST answers "204, 0 rows" when RLS blocks an UPDATE, which looked like a
    /// success and left the old username in the database. We now ask for the updated row back
    /// and treat "no row" as a failure, and we take the saved state from the server.
    func saveProfile(_ new: Profile) async throws {
        guard let userId else { throw StoreError.notSignedIn }
        let username = new.username.trimmingCharacters(in: .whitespaces).lowercased()
        guard Self.isValid(username: username) else { throw StoreError.invalidUsername }
        let privacyChanged = new.privacyLevel != profile?.privacyLevel

        do {
            let rows: [ProfileRow] = try await client.from("profiles")
                .update(ProfileUpdate(username: username,
                                      reminders: new.reminders,
                                      privacyLevel: new.privacyLevel))
                .eq("id", value: userId)
                .select()
                .execute().value
            guard let row = rows.first else { throw StoreError.saveFailed }
            profile = Profile(row: row, avatarJPEG: profile?.avatarJPEG)
        } catch let e as PostgrestError where e.code == "23505" {
            throw StoreError.usernameTaken
        }
        if privacyChanged { scheduleFeedRefresh() }
        
        await ReminderScheduler.apply(enabled: profile?.reminders ?? false)
    }

    func updateAvatar(_ jpeg: Data) async throws {
        guard let userId else { throw StoreError.notSignedIn }
        let path = "\(userId.uuidString.lowercased())/avatar.jpg"
        try await client.storage.from("avatars").upload(
            path, data: jpeg,
            options: FileOptions(cacheControl: "3600", contentType: "image/jpeg", upsert: true))
        let base = try client.storage.from("avatars").getPublicURL(path: path)
        let url = "\(base.absoluteString)?v=\(Int(Date().timeIntervalSince1970))"
        try await client.from("profiles").update(AvatarUpdate(avatarUrl: url))
            .eq("id", value: userId).execute()
        profile?.avatarJPEG = jpeg
        profile?.avatarURL = url
    }

    // MARK: - Daily goals

    static func todayKey() -> String { dayFormatter.string(from: Date()) }

    static func unlockedCount(goals: [Goal]) -> Int {
        min(3, goals.filter(\.done).count)
    }

    func fetchTodayGoals(userId: UUID) async {
        let today = Self.todayKey()
        do {
            let rows: [GoalRow] = try await client.from("goals").select()
                .eq("user_id", value: userId)
                .eq("day", value: today)
                .order("position", ascending: true)
                .order("created_at", ascending: true)
                .execute().value

            let localMedia = Dictionary(
                day.goals.compactMap { g in g.proofJPEG.map { (g.id, $0) } },
                uniquingKeysWith: { a, _ in a })
            day = Day(date: today, goals: rows.map {
                var g = Goal(row: $0)
                g.proofJPEG = localMedia[g.id]
                return g
            })
            updateInterestKeywords(from: day.goals)
            publishWidgetState()
        } catch {
            report("Couldn't load today's goals", error)
        }
    }

    /// Optimistic local mutation, then a serialized background sync (writes never race).
    func updateDay(_ mutate: (inout Day) -> Void) {
        let old = day
        var new = day
        mutate(&new)
        guard new != old else { return }
        day = new
        if Self.unlockedCount(goals: old.goals) < 3 && Self.unlockedCount(goals: new.goals) == 3 {
            celebrationToken += 1
        }
        publishWidgetState()
        updateInterestKeywords(from: new.goals)
        guard let userId else { return }

        let previous = syncChain
        syncChain = Task { [weak self] in
            await previous?.value
            await self?.push(old: old, new: new, userId: userId)
        }
    }

    private func push(old: Day, new: Day, userId: UUID) async {
        do {
            var goals = new.goals
            for i in goals.indices {
                let g = goals[i]
                guard let data = g.proofJPEG, g.proofPath == nil, let kind = g.proofKind else { continue }
                do {
                    let path = try await uploadProof(data, kind: kind, userId: userId, goalId: g.id)
                    goals[i].proofPath = path
                    if let idx = day.goals.firstIndex(where: { $0.id == g.id }) {
                        day.goals[idx].proofPath = path
                    }
                } catch {
                    report("Couldn't upload proof", error)
                }
            }

            let newIds = Set(new.goals.map(\.id))
            let removed = old.goals.filter { !newIds.contains($0.id) }
            if !removed.isEmpty {
                try await client.from("goals").delete()
                    .in("id", values: removed.map { $0.id.uuidString })
                    .execute()
                let paths = removed.compactMap(\.proofPath)
                if !paths.isEmpty { _ = try? await client.storage.from("proofs").remove(paths: paths) }
            }

            if !goals.isEmpty {
                let rows = goals.enumerated().map { index, g in
                    GoalRow(id: g.id, userId: userId, day: new.date, position: index,
                            text: g.text, done: g.done,
                            proofKind: g.proofKind?.rawValue, proofPath: g.proofPath)
                }
                try await client.from("goals").upsert(rows, onConflict: "id").execute()
            }

            await refreshStats()
        } catch {
            report("Couldn't sync your goals", error)
        }
    }

    func resetDay() {
        let today = Self.todayKey()
        let paths = day.goals.compactMap(\.proofPath)
        day = Day(date: today, goals: [])
        publishWidgetState()
        guard let userId else { return }
        let previous = syncChain
        syncChain = Task { [weak self] in
            await previous?.value
            guard let self else { return }
            do {
                try await client.from("goals").delete()
                    .eq("user_id", value: userId).eq("day", value: today).execute()
                if !paths.isEmpty { _ = try? await client.storage.from("proofs").remove(paths: paths) }
                await refreshStats()
            } catch {
                report("Couldn't reset your day", error)
            }
        }
    }

    // MARK: - Interest keywords (Discover recommendations)

    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "your", "have", "today", "tomorrow",
        "finish", "complete", "make", "some", "into", "about", "more", "than", "then", "also",
        "need", "want", "work", "time", "hour", "hours", "minutes", "daily", "every", "each"
    ]

    func updateInterestKeywords(from goals: [Goal]) {
        var counts: [String: Int] = [:]
        for text in historyTexts + goals.map(\.text) {
            for word in text.lowercased().split(whereSeparator: { !$0.isLetter }) {
                let w = String(word)
                guard w.count >= 4, !Self.stopwords.contains(w) else { continue }
                counts[w, default: 0] += 1
            }
        }
        let top = counts
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(5).map(\.key)
        if top != userInterestKeywords { userInterestKeywords = top }
    }

    private func fetchRecentGoalTexts() async {
        guard let userId else { return }
        let since = Calendar.current.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        do {
            let rows: [TextRow] = try await client.from("goals").select("text")
                .eq("user_id", value: userId)
                .gte("day", value: Self.dayFormatter.string(from: since))
                .order("created_at", ascending: false)
                .limit(150)
                .execute().value
            historyTexts = rows.map(\.text)
            updateInterestKeywords(from: day.goals)
        } catch {
            log.error("recent goal texts failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Storage (proofs)

    func uploadProof(_ data: Data, kind: ProofKind, userId: UUID, goalId: UUID) async throws -> String {
        let (ext, mime): (String, String) = switch kind {
        case .photo: ("jpg", "image/jpeg")
        case .video: ("mp4", "video/mp4")
        case .audio: ("m4a", "audio/mp4")
        }
        let path = "\(userId.uuidString.lowercased())/\(goalId.uuidString.lowercased()).\(ext)"
        try await client.storage.from("proofs").upload(
            path, data: data,
            options: FileOptions(cacheControl: "3600", contentType: mime, upsert: true))
        return path
    }

    func proofURL(path: String) async -> URL? {
        if let c = signedURLCache[path], c.expires > Date().addingTimeInterval(60) { return c.url }
        do {
            let ttl = 3600
            let url = try await client.storage.from("proofs").createSignedURL(path: path, expiresIn: ttl)
            signedURLCache[path] = (url, Date().addingTimeInterval(TimeInterval(ttl)))
            return url
        } catch {
            log.error("Signed URL failed for \(path, privacy: .public): \(error.localizedDescription)")
            return nil
        }
    }

    // MARK: - Following (request -> accept)

    func fetchFollowing(userId: UUID) async {
        do {
            let rows: [FollowRow] = try await client.from("follows")
                .select("following_id, status, profiles!following_id(username)")
                .eq("follower_id", value: userId)
                .execute().value

            var accepted: [String: UUID] = [:]
            var pending: Set<UUID> = []
            for r in rows {
                if r.status == "accepted" { accepted[r.profile.username] = r.followingId }
                else { pending.insert(r.followingId) }
            }
            followingMap = accepted
            pendingIds = pending
        } catch {
            report("Couldn't load who you follow", error)
        }
    }

    /// none -> sends a request; requested -> cancels it; following -> unfollows.
    func toggleFollow(_ person: Person) async {
        guard let me = userId, person.userId != me else { return }
        let state = followState(for: person.userId)
        let previousMap = followingMap
        let previousPending = pendingIds

        do {
            switch state {
            case .none:
                pendingIds.insert(person.userId)
                try await client.from("follows")
                    .insert(FollowInsert(followerId: me, followingId: person.userId))
                    .execute()
            case .requested, .following:
                followingMap[person.name] = nil
                pendingIds.remove(person.userId)
                try await client.from("follows").delete()
                    .eq("follower_id", value: me)
                    .eq("following_id", value: person.userId)
                    .execute()
                if state == .following { await fetchFriendSummits() }
            }
        } catch {
            followingMap = previousMap
            pendingIds = previousPending
            report("Couldn't update follow", error)
        }
    }

    func fetchIncomingRequests() async {
        guard let me = userId else { return }
        do {
            let rows: [FollowRequestRow] = try await client.from("follows")
                .select("follower_id, created_at, profiles!follower_id(username, avatar_url)")
                .eq("following_id", value: me)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute().value
            incomingRequests = rows.map {
                FollowRequest(id: $0.followerId,
                              username: $0.profile.username,
                              avatarURL: $0.profile.avatarUrl.flatMap(URL.init(string:)),
                              createdAt: $0.createdAt)
            }
        } catch {
            report("Couldn't load follow requests", error)
        }
    }

    func acceptRequest(_ request: FollowRequest) async {
        guard let me = userId else { return }
        incomingRequests.removeAll { $0.id == request.id }
        do {
            try await client.from("follows")
                .update(FollowStatusUpdate(status: "accepted"))
                .eq("follower_id", value: request.id)
                .eq("following_id", value: me)
                .execute()
            await fetchFollowing(userId: me)
            await fetchFriendSummits()
        } catch {
            incomingRequests.insert(request, at: 0)
            report("Couldn't accept request", error)
        }
    }

    /// Declines a pending request, or removes an existing follower.
    func declineRequest(_ request: FollowRequest) async {
        guard let me = userId else { return }
        incomingRequests.removeAll { $0.id == request.id }
        do {
            try await client.from("follows").delete()
                .eq("follower_id", value: request.id)
                .eq("following_id", value: me)
                .execute()
        } catch {
            incomingRequests.insert(request, at: 0)
            report("Couldn't decline request", error)
        }
    }

    // MARK: - Feed (summits from people whose request I had accepted)

    func fetchFriendSummits() async {
        guard let me = userId else { return }
        do {
            let rows: [FeedRow] = try await client.from("friend_summits").select()
                .eq("day", value: Self.todayKey())
                .neq("user_id", value: me)
                .order("completed_at", ascending: false)
                .limit(50)
                .execute().value
            log.debug("feed rows: \(rows.count)")

            let urls = await withTaskGroup(of: (UUID, URL?).self) { group in
                for r in rows {
                    guard let p = r.proofPath else { continue }
                    group.addTask { (r.id, await self.proofURL(path: p)) }
                }
                var out: [UUID: URL] = [:]
                for await (id, url) in group { if let url { out[id] = url } }
                return out
            }

            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .short
            friendSummits = rows.map { r in
                FriendSummit(
                    id: r.id, userId: r.userId, name: r.username, goal: r.goal,
                    proofKind: r.proofKind.flatMap(ProofKind.init(rawValue:)),
                    proofURL: urls[r.id],
                    time: r.completedAt.map { rel.localizedString(for: $0, relativeTo: Date()) } ?? "")
            }
        } catch {
            report("Couldn't load summits", error)
        }
    }

    // MARK: - Search, stats, discover

    func fetchStats(userId: UUID) async -> StatsRow {
        do {
            let rows: [StatsRow] = try await client
                .rpc("get_stats", params: StatsParams(user: userId, today: Self.todayKey()))
                .execute().value
            return rows.first ?? .zero
        } catch {
            log.error("get_stats failed: \(error.localizedDescription)")
            return .zero
        }
    }

    func refreshStats() async {
        guard let userId else { return }
        stats = await fetchStats(userId: userId)
    }

    func searchPeople(query: String) async -> [Person] {
        let q = String(query.lowercased().filter {
            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "_" || $0 == ".")
        })
        guard q.count >= 2, let me = userId else { return [] }
        let pattern = "%" + q.replacingOccurrences(of: "_", with: "\\_") + "%"
        do {
            let rows: [ProfileRow] = try await client.from("profiles").select()
                .ilike("username", pattern: pattern)
                .neq("id", value: me)
                .limit(20)
                .execute().value

            return await withTaskGroup(of: Person.self) { group in
                for r in rows {
                    group.addTask {
                        let s = await self.fetchStats(userId: r.id)
                        return Person(userId: r.id, name: r.username,
                                      streak: s.streak, summits: s.summits,
                                      avatarURL: r.avatarUrl.flatMap(URL.init(string:)))
                    }
                }
                var out: [Person] = []
                for await p in group { out.append(p) }
                return out.sorted { $0.name < $1.name }
            }
        } catch {
            log.error("search failed: \(error.localizedDescription)")
            return []
        }
    }

    /// Anonymous Discover. Empty query = recommendations from your own goal keywords
    /// (or just the latest public summits if you have none).
    func searchSummits(query: String) async -> [Summit] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let terms = q.isEmpty ? userInterestKeywords : [q]
        do {
            let rows: [DiscoverRow] = try await client
                .rpc("discover_summits", params: DiscoverParams(terms: terms, limit: 40))
                .execute().value

            let rel = RelativeDateTimeFormatter()
            rel.unitsStyle = .short
            return rows.map { r in
                Summit(id: r.id, goal: r.goal,
                       proofKind: r.proofKind.flatMap(ProofKind.init(rawValue:)),
                       proofPath: r.proofPath,
                       time: r.completedAt.map { rel.localizedString(for: $0, relativeTo: Date()) } ?? "")
            }
        } catch {
            if !(error is CancellationError) { log.error("discover failed: \(error.localizedDescription)") }
            return []
        }
    }

    // MARK: - Realtime

    private func startRealtime() async {
        await stopRealtime()
        let channel = client.channel("cime-live")
        // Register listeners BEFORE subscribing.
        let goalChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "goals")
        let followChanges = channel.postgresChange(AnyAction.self, schema: "public", table: "follows")
        realtimeChannel = channel
        do {
            try await channel.subscribeWithError()
        } catch {
            report("Live updates unavailable", error)
            return
        }
        realtimeTasks = [
            Task { [weak self] in
                for await _ in goalChanges { self?.scheduleFeedRefresh() }
            },
            Task { [weak self] in
                for await _ in followChanges { self?.scheduleSocialRefresh() }
            }
        ]
    }

    private func stopRealtime() async {
        realtimeTasks.forEach { $0.cancel() }
        realtimeTasks = []
        feedRefreshTask?.cancel(); feedRefreshTask = nil
        socialRefreshTask?.cancel(); socialRefreshTask = nil
        if let channel = realtimeChannel {
            await client.removeChannel(channel)
            realtimeChannel = nil
        }
    }

    private func scheduleFeedRefresh() {
        feedRefreshTask?.cancel()
        feedRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            guard !Task.isCancelled else { return }
            await self?.fetchFriendSummits()
        }
    }

    /// Someone requested me, accepted me, or unfollowed: refresh the graph, then the feed.
    private func scheduleSocialRefresh() {
        socialRefreshTask?.cancel()
        socialRefreshTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled, let self, let id = self.userId else { return }
            await self.fetchFollowing(userId: id)
            await self.fetchIncomingRequests()
            await self.fetchFriendSummits()
        }
    }

    // MARK: - Errors

    private func report(_ message: String, _ error: Error) {
        if error is CancellationError { return }
        log.error("\(message, privacy: .public): \(error.localizedDescription)")
        lastError = message
    }
}
