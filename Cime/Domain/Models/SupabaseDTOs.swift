import Foundation
import Supabase

nonisolated enum AppConfig {
    static let supabaseURL: URL = {
        guard let s = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              let url = URL(string: s) else { fatalError("Missing SUPABASE_URL in Info.plist") }
        return url
    }()

    static let publishableKey: String = {
        guard let k = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_PUBLISHABLE_KEY") as? String,
              !k.isEmpty else { fatalError("Missing SUPABASE_PUBLISHABLE_KEY in Info.plist") }
        return k
    }()
}

nonisolated extension SupabaseClient {
    static let cime = SupabaseClient(
        supabaseURL: AppConfig.supabaseURL,
        supabaseKey: AppConfig.publishableKey,
        options: SupabaseClientOptions(
            auth: SupabaseClientOptions.AuthOptions(
                emitLocalSessionAsInitialSession: true
            )
        )
    )
}

// MARK: - Profiles

struct ProfileRow: Codable {
    let id: UUID
    var username: String
    var avatarUrl: String?
    var reminders: Bool
    var privacyLevel: SummitPrivacy?

    enum CodingKeys: String, CodingKey {
        case id, username, reminders
        case avatarUrl = "avatar_url"
        case privacyLevel = "privacy_level"
    }
}

struct ProfileUpdate: Encodable {
    var username: String
    var reminders: Bool
    var privacyLevel: SummitPrivacy

    enum CodingKeys: String, CodingKey {
        case username, reminders
        case privacyLevel = "privacy_level"
    }
}

struct AvatarUpdate: Encodable {
    var avatarUrl: String
    enum CodingKeys: String, CodingKey { case avatarUrl = "avatar_url" }
}

// MARK: - Goals / feed

struct GoalRow: Codable {
    let id: UUID
    let userId: UUID
    var day: String
    var position: Int
    var text: String
    var done: Bool
    var proofKind: String?
    var proofPath: String?

    enum CodingKeys: String, CodingKey {
        case id, day, position, text, done
        case userId = "user_id"
        case proofKind = "proof_kind"
        case proofPath = "proof_path"
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(userId, forKey: .userId)
        try c.encode(day, forKey: .day)
        try c.encode(position, forKey: .position)
        try c.encode(text, forKey: .text)
        try c.encode(done, forKey: .done)
        try c.encode(proofKind, forKey: .proofKind)
        try c.encode(proofPath, forKey: .proofPath)
    }
}

struct FeedRow: Decodable {
    let id: UUID
    let userId: UUID
    let username: String
    let goal: String
    let proofKind: String?
    let proofPath: String?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, username, goal
        case userId = "user_id"
        case proofKind = "proof_kind"
        case proofPath = "proof_path"
        case completedAt = "completed_at"
    }
}

// MARK: - Follows (request / accept)

/// A follow I sent. status = "pending" (waiting) or "accepted".
struct FollowRow: Decodable {
    struct Embedded: Decodable { let username: String }
    let followingId: UUID
    let status: String
    let profile: Embedded

    enum CodingKeys: String, CodingKey {
        case status
        case followingId = "following_id"
        case profile = "profiles"
    }
}

/// A follow request someone sent ME.
struct FollowRequestRow: Decodable {
    struct Embedded: Decodable {
        let username: String
        let avatarUrl: String?
        enum CodingKeys: String, CodingKey {
            case username
            case avatarUrl = "avatar_url"
        }
    }
    let followerId: UUID
    let createdAt: Date?
    let profile: Embedded

    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case createdAt = "created_at"
        case profile = "profiles"
    }
}

/// status is filled by the database default ('pending'); RLS rejects anything else.
struct FollowInsert: Encodable {
    let followerId: UUID
    let followingId: UUID
    enum CodingKeys: String, CodingKey {
        case followerId = "follower_id"
        case followingId = "following_id"
    }
}

struct FollowStatusUpdate: Encodable {
    let status: String
}

// MARK: - Stats / discover

struct StatsParams: Encodable {
    let user: UUID
    let today: String
    enum CodingKeys: String, CodingKey {
        case user = "p_user"
        case today = "p_today"
    }
}

struct StatsRow: Decodable {
    let streak: Int
    let summits: Int
    static let zero = StatsRow(streak: 0, summits: 0)
}

struct DiscoverParams: Encodable {
    let terms: [String]
    let limit: Int
    enum CodingKeys: String, CodingKey {
        case terms = "p_terms"
        case limit = "p_limit"
    }
}

struct DiscoverRow: Decodable {
    let id: UUID
    let goal: String
    let proofKind: String?
    let proofPath: String?
    let completedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, goal
        case proofKind = "proof_kind"
        case proofPath = "proof_path"
        case completedAt = "completed_at"
    }
}

// MARK: - Mapping

extension Goal {
    init(row: GoalRow) {
        self.init(
            id: row.id,
            text: row.text,
            proofJPEG: nil,
            proofKind: row.proofKind.flatMap(ProofKind.init(rawValue:)),
            proofPath: row.proofPath,
            done: row.done
        )
    }
}

extension Profile {
    init(row: ProfileRow, avatarJPEG: Data? = nil) {
        self.init(
            username: row.username,
            avatarJPEG: avatarJPEG,
            avatarURL: row.avatarUrl,
            reminders: row.reminders,
            privacyLevel: row.privacyLevel ?? .friendsOnly
        )
    }
}

enum StoreError: LocalizedError {
    case notSignedIn
    case invalidUsername
    case usernameTaken
    case userNotFound
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .notSignedIn: "You need to be signed in."
        case .invalidUsername: "Usernames are 3–20 characters: a–z, 0–9, _ and ."
        case .usernameTaken: "Username is taken."
        case .userNotFound: "No account found with this username or email."
        case .saveFailed: "Your changes weren't saved. Please try again."
        }
    }
}
