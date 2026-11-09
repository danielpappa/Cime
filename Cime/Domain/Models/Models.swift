import Foundation

struct Goal: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var text: String
    var proofJPEG: Data?          // local, in-memory preview / pending upload
    var proofKind: ProofKind?
    var proofPath: String?        // path in the private "proofs" bucket
    var done: Bool
}

struct Day: Codable, Equatable {
    var date: String              // "yyyy-MM-dd" in the user's local calendar
    var goals: [Goal]
}

struct Profile: Codable, Equatable {
    var username: String
    var avatarJPEG: Data?         // local cache
    var avatarURL: String?        // public URL in the "avatars" bucket
    var reminders: Bool
    var privacyLevel: SummitPrivacy
}

enum AuthProvider: String, Codable {
    case apple
    case google
    case email
}

struct AppSession: Codable, Equatable {
    var provider: AuthProvider
    var email: String?
}

struct Person: Identifiable, Equatable {
    var id: String { name }
    let userId: UUID
    let name: String              // username
    let streak: Int
    let summits: Int
    var avatarURL: URL? = nil
}

/// Someone who asked to follow ME and is waiting for my answer.
struct FollowRequest: Identifiable, Equatable {
    let id: UUID                  // the requester's user id
    let username: String
    let avatarURL: URL?
    let createdAt: Date?
}

enum ProofKind: String, Codable, CaseIterable {
    case photo
    case video
    case audio

    var label: String {
        switch self {
        case .photo: "Photo"
        case .video: "Video"
        case .audio: "Voice"
        }
    }

    var recordLimitSeconds: Int {
        switch self {
        case .photo: 0
        case .video: 10
        case .audio: 30
        }
    }
}

enum SummitPrivacy: String, Codable, CaseIterable, Identifiable {
    case publicSummits = "public"
    case friendsOnly = "friends"
    case privateSummits = "private"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .publicSummits: return "Public"
        case .friendsOnly: return "Followers"
        case .privateSummits: return "Private"
        }
    }

    var hint: String {
        switch self {
        case .publicSummits: return "Anyone can discover your summits, anonymously"
        case .friendsOnly: return "Only followers you've approved can see your proof"
        case .privateSummits: return "Hidden from everyone, including followers"
        }
    }
}

struct FriendSummit: Identifiable {
    let id: UUID
    let userId: UUID
    let name: String
    let goal: String
    let proofKind: ProofKind?
    let proofURL: URL?
    let time: String
}

/// Discover item. Deliberately has NO user identity: Discover is anonymous.
/// The signed URL is resolved lazily by the view (store.proofURL(path:)).
struct Summit: Identifiable {
    let id: UUID
    let goal: String
    let proofKind: ProofKind?
    let proofPath: String?
    let time: String
}

enum MainTab: String, CaseIterable {
    case climb
    case summits
    case crew
    case profile

    var title: String { rawValue }
}
