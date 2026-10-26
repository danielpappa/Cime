import Foundation
import Observation

@MainActor
@Observable
final class PeaksStore {
    private enum Key {
        static let day = "three-peaks-day"
        static let profile = "three-peaks-profile"
        static let session = "three-peaks-session"
        static let following = "three-peaks-following"
    }

    private let defaults: UserDefaults

    var session: Session?
    var profile: Profile
    var day: Day
    var following: [String]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.session = Self.loadSession(from: defaults)
        self.profile = Self.loadProfile(from: defaults)
        self.day = Self.loadDay(from: defaults)
        self.following = Self.loadFollowing(from: defaults)
    }

    static func todayKey(calendar: Calendar = .current) -> String {
        let d = calendar.startOfDay(for: Date())
        let y = calendar.component(.year, from: d)
        let m = calendar.component(.month, from: d)
        let day = calendar.component(.day, from: d)
        return String(format: "%04d-%02d-%02d", y, m, day)
    }

    static func unlockedCount(goals: [Goal]) -> Int {
        min(3, goals.filter(\.done).count)
    }

    func refreshDayIfNeeded() {
        let key = Self.todayKey()
        if day.date != key {
            day = Day(date: key, goals: [])
            saveDay()
        }
    }

    func signIn(_ session: Session) {
        self.session = session
        persistSession()
    }

    func signOut() {
        session = nil
        persistSession()
    }

    func saveProfile(_ profile: Profile) {
        self.profile = profile
        if let data = try? JSONEncoder().encode(profile) {
            defaults.set(data, forKey: Key.profile)
        }
    }

    func saveDay(_ day: Day) {
        self.day = day
        saveDay()
    }

    func updateDay(_ mutate: (inout Day) -> Void) {
        var copy = day
        mutate(&copy)
        day = copy
        saveDay()
    }

    func resetDay() {
        defaults.removeObject(forKey: Key.day)
        day = Day(date: Self.todayKey(), goals: [])
    }

    @discardableResult
    func toggleFollow(name: String) -> [String] {
        if following.contains(name) {
            following.removeAll { $0 == name }
        } else {
            following.append(name)
        }
        if let data = try? JSONEncoder().encode(following) {
            defaults.set(data, forKey: Key.following)
        }
        return following
    }

    func searchPeople(query: String) -> [Person] {
        let s = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !s.isEmpty else { return DemoContent.people }
        return DemoContent.people.filter {
            $0.name.lowercased().contains(s) || $0.full.lowercased().contains(s)
        }
    }

    var streakDisplay: Int {
        4 + (Self.unlockedCount(goals: day.goals) == 3 ? 1 : 0)
    }

    // MARK: - Persistence

    private func saveDay() {
        if let data = try? JSONEncoder().encode(day) {
            defaults.set(data, forKey: Key.day)
        }
    }

    private func persistSession() {
        if let session {
            if let data = try? JSONEncoder().encode(session) {
                defaults.set(data, forKey: Key.session)
            }
        } else {
            defaults.removeObject(forKey: Key.session)
        }
    }

    private static func loadSession(from defaults: UserDefaults) -> Session? {
        guard let data = defaults.data(forKey: Key.session) else { return nil }
        return try? JSONDecoder().decode(Session.self, from: data)
    }

    private static func loadProfile(from defaults: UserDefaults) -> Profile {
        let base = Profile(username: "you", avatarJPEG: nil, reminders: true, privateSummits: false)
        guard let data = defaults.data(forKey: Key.profile),
              let decoded = try? JSONDecoder().decode(Profile.self, from: data) else { return base }
        return Profile(
            username: decoded.username,
            avatarJPEG: decoded.avatarJPEG,
            reminders: decoded.reminders,
            privateSummits: decoded.privateSummits
        )
    }

    private static func loadDay(from defaults: UserDefaults) -> Day {
        let key = todayKey()
        guard let data = defaults.data(forKey: Key.day),
              let decoded = try? JSONDecoder().decode(Day.self, from: data),
              decoded.date == key else {
            return Day(date: key, goals: [])
        }
        return decoded
    }

    private static func loadFollowing(from defaults: UserDefaults) -> [String] {
        guard let data = defaults.data(forKey: Key.following),
              let decoded = try? JSONDecoder().decode([String].self, from: data) else {
            return ["maya.k", "jonas", "ari_lane"]
        }
        return decoded
    }
}
