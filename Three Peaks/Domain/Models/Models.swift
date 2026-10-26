import Foundation

struct Goal: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var text: String
    var proofJPEG: Data?
    var proofKind: ProofKind?
    var done: Bool
}

struct Day: Codable, Equatable {
    var date: String
    var goals: [Goal]
}

struct Profile: Codable, Equatable {
    var username: String
    var avatarJPEG: Data?
    var reminders: Bool
    var privateSummits: Bool
}

enum AuthProvider: String, Codable {
    case apple
    case google
    case email
}

struct Session: Codable, Equatable {
    var provider: AuthProvider
    var email: String?
}

struct Person: Identifiable, Equatable {
    var id: String { name }
    let name: String
    let full: String
    let bio: String
    let streak: Int
    let summits: Int
}

enum ProofKind: String, Codable, CaseIterable {
    case photo
    case loop
    case video
    case audio

    var label: String {
        switch self {
        case .photo: "Photo"
        case .loop: "Loop"
        case .video: "Video"
        case .audio: "Voice"
        }
    }

    var recordLimitSeconds: Int {
        switch self {
        case .photo: 0
        case .loop: 3
        case .video: 10
        case .audio: 30
        }
    }
}

struct FriendSummit: Identifiable {
    var id: String { name }
    let name: String
    let goal: String
    let imageName: String
    let time: String
}

enum MainTab: String, CaseIterable {
    case climb
    case summits
    case crew
    case profile

    var title: String { rawValue }
}
