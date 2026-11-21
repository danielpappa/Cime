import SwiftUI
import Supabase

// MARK: - Model

struct GoalSuggestion: Identifiable, Hashable {
    enum Source: Int, CaseIterable {
        case history, crew, idea, popular            // also the priority order

        var title: String {
            switch self {
            case .history: "Yours"
            case .crew: "Crew"
            case .idea: "Ideas"
            case .popular: "Popular"
            }
        }

        var symbol: String {
            switch self {
            case .history: "clock.arrow.circlepath"
            case .crew: "person.2.fill"
            case .idea: "sparkles"
            case .popular: "flame.fill"
            }
        }

        var tint: Color {
            switch self {
            case .history, .idea: Theme.glacier
            case .crew, .popular: Theme.summit
            }
        }
    }

    let text: String
    let source: Source
    let detail: String?
    var id: String { "\(source.rawValue)|\(text.lowercased())" }
}

/// What the user did before: the most-done goals, plus the last day's peaks in order.
struct GoalHistory {
    var favorites: [GoalSuggestion] = []
    var lastPeaks: [String] = []
    var lastLabel = ""                  // "yesterday" / "Monday"
}

// MARK: - Data (extension on the store: no new tables, no new SQL)

private struct GoalHistoryRow: Decodable {
    let text: String
    let done: Bool
    let day: String
    let position: Int
}

private struct CrewGoalRow: Decodable {
    let goal: String
    let username: String
    let day: String
}

private let goalDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

private func dayKey(daysAgo: Int) -> String {
    goalDayFormatter.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: .now) ?? .now)
}

/// "today", "yesterday", or the weekday name.
private func dayLabel(_ key: String) -> String {
    if key == dayKey(daysAgo: 0) { return "today" }
    if key == dayKey(daysAgo: 1) { return "yesterday" }
    guard let date = goalDayFormatter.date(from: key) else { return "recently" }
    return date.formatted(.dateTime.weekday(.wide))
}

extension CimeStore {
    /// Your own past goals (before today), ranked by how often you actually finished them.
    func fetchGoalHistory(days: Int = 60) async -> GoalHistory {
        guard let userId else { return GoalHistory() }
        do {
            let rows: [GoalHistoryRow] = try await client.from("goals")
                .select("text, done, day, position")
                .eq("user_id", value: userId)
                .gte("day", value: dayKey(daysAgo: days))
                .lt("day", value: Self.todayKey())
                .order("day", ascending: false)
                .limit(400)
                .execute().value
            guard let latestDay = rows.first?.day else { return GoalHistory() }

            // favorites: group by normalized text
            struct Stat { var text: String; var set = 0; var done = 0; var lastDay: String }
            var stats: [String: Stat] = [:]
            for r in rows {
                let key = r.text.trimmingCharacters(in: .whitespaces).lowercased()
                guard !key.isEmpty else { continue }
                var s = stats[key] ?? Stat(text: r.text, lastDay: r.day)
                s.set += 1
                if r.done { s.done += 1 }
                if r.day > s.lastDay { s.lastDay = r.day; s.text = r.text }
                stats[key] = s
            }
            let favorites = stats.values
                .sorted { ($0.done, $0.set, $0.lastDay) > ($1.done, $1.set, $1.lastDay) }
                .prefix(10)
                .map { s -> GoalSuggestion in
                    let detail: String =
                        s.done >= 2 ? "Done \(s.done)× lately"
                        : s.done == 1 ? "You did this recently"
                        : "On your list before"
                    return GoalSuggestion(text: s.text, source: .history, detail: detail)
                }

            let last = rows.filter { $0.day == latestDay }.sorted { $0.position < $1.position }.map(\.text)
            return GoalHistory(favorites: Array(favorites), lastPeaks: Array(last.prefix(3)),
                               lastLabel: dayLabel(latestDay))
        } catch {
            return GoalHistory()
        }
    }

    /// What the people you follow actually finished in the last few days.
    /// (Row-level security only shows DONE goals of accepted follows, so their plans stay private.)
    func fetchCrewGoals(days: Int = 3) async -> [GoalSuggestion] {
        guard userId != nil else { return [] }
        do {
            let rows: [CrewGoalRow] = try await client.from("friend_summits")
                .select("goal, username, day")
                .gte("day", value: dayKey(daysAgo: days))
                .order("completed_at", ascending: false)
                .limit(60)
                .execute().value
            var seen = Set<String>()
            var out: [GoalSuggestion] = []
            for r in rows {
                let key = r.goal.trimmingCharacters(in: .whitespaces).lowercased()
                guard !key.isEmpty, seen.insert(key).inserted else { continue }
                out.append(GoalSuggestion(text: r.goal, source: .crew,
                                          detail: "@\(r.username) · \(dayLabel(r.day))"))
                if out.count == 10 { break }
            }
            return out
        } catch {
            return []
        }
    }
}

// MARK: - Suggestion engine (observable, one per screen)

@MainActor
@Observable
final class GoalSuggestionsModel {
    private(set) var all: [GoalSuggestion] = []
    private(set) var lastPeaks: [String] = []
    private(set) var lastLabel = ""

    var availableSources: [GoalSuggestion.Source] {
        GoalSuggestion.Source.allCases.filter { source in all.contains { $0.source == source } }
    }

    func load(_ store: CimeStore) async {
        let ctx = IdeaContext.now()
        let ideas = GoalIdeas.pick(for: ctx, topic: nil, limit: 12).map {
            GoalSuggestion(text: $0.text, source: .idea, detail: "Idea · \($0.topic.title)")
        }
        if all.isEmpty { all = ideas }                        // ideas need no network: show instantly

        async let history = store.fetchGoalHistory()
        async let crew = store.fetchCrewGoals()
        async let popular = store.discoverSummits(terms: [])
        let (h, c, p) = await (history, crew, popular)

        let pop = p.prefix(10).map { GoalSuggestion(text: $0.goal, source: .popular, detail: "Public today") }

        var seen = Set<String>()
        var merged: [GoalSuggestion] = []
        for s in h.favorites + c + ideas + pop where seen.insert(s.text.lowercased()).inserted {
            merged.append(s)
        }
        all = merged
        lastPeaks = h.lastPeaks
        lastLabel = h.lastLabel
    }

    /// "For you": one from each source in turn, so the list stays varied.
    func forYou(excluding used: Set<String>, limit: Int = 8) -> [GoalSuggestion] {
        var buckets: [GoalSuggestion.Source: [GoalSuggestion]] = [:]
        for s in all where !used.contains(s.text.lowercased()) { buckets[s.source, default: []].append(s) }
        var out: [GoalSuggestion] = []
        var index = 0
        while out.count < limit {
            var added = false
            for source in GoalSuggestion.Source.allCases {
                if let b = buckets[source], index < b.count, out.count < limit {
                    out.append(b[index]); added = true
                }
            }
            if !added { break }
            index += 1
        }
        return out
    }

    func list(_ source: GoalSuggestion.Source?, excluding used: Set<String>) -> [GoalSuggestion] {
        guard let source else { return forYou(excluding: used) }
        return all.filter { $0.source == source && !used.contains($0.text.lowercased()) }.prefix(8).map { $0 }
    }

    /// Typeahead across every source: prefix matches first, then your own history before the rest.
    func matches(_ query: String, excluding used: Set<String>, limit: Int = 6) -> [GoalSuggestion] {
        let q = query.lowercased()
        return all
            .filter {
                let t = $0.text.lowercased()
                return t != q && t.contains(q) && !used.contains(t)
            }
            .sorted { a, b in
                let ap = a.text.lowercased().hasPrefix(q), bp = b.text.lowercased().hasPrefix(q)
                if ap != bp { return ap }
                return a.source.rawValue < b.source.rawValue
            }
            .prefix(limit).map { $0 }
    }
}
