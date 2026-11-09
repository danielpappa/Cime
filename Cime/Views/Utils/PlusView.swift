//
//  PlusView.swift
//  Cime
//
//  Created by Daniel Pappalardo on 03/11/2026.
//

import Foundation
import Supabase

private struct DayOnlyRow: Decodable { let day: String }
private struct IdOnlyRow: Decodable { let id: UUID }

private let keyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.calendar = Calendar(identifier: .gregorian)
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"
    return f
}()

extension CimeStore {
    /// Done-goal count (capped at 3) for each of the last `days` days, oldest first.
    func fetchHistory(days: Int = 14) async -> [Int] {
        guard let userId else { return Array(repeating: 0, count: days) }
        let cal = Calendar(identifier: .gregorian)
        let dates = (0..<days).compactMap { cal.date(byAdding: .day, value: -(days - 1 - $0), to: Date()) }
        guard let first = dates.first else { return [] }
        do {
            let rows: [DayOnlyRow] = try await client.from("goals").select("day")
                .eq("user_id", value: userId)
                .eq("done", value: true)
                .gte("day", value: keyFormatter.string(from: first))
                .execute().value
            var counts: [String: Int] = [:]
            for r in rows { counts[r.day, default: 0] += 1 }
            return dates.map { min(3, counts[keyFormatter.string(from: $0)] ?? 0) }
        } catch {
            return Array(repeating: 0, count: days)
        }
    }

    /// `today` is only non-zero if row-level security lets you see their done goals
    /// (they're public, or they're followers-only and you're an accepted follower).
    func fetchPerson(username: String) async -> (person: Person, today: Int)? {
        do {
            let rows: [ProfileRow] = try await client.from("profiles").select()
                .eq("username", value: username.lowercased()).limit(1).execute().value
            guard let r = rows.first else { return nil }

            async let s = fetchStats(userId: r.id)
            async let t: [IdOnlyRow] = client.from("goals").select("id")
                .eq("user_id", value: r.id)
                .eq("day", value: Self.todayKey())
                .eq("done", value: true)
                .execute().value
            let stats = await s
            let today = min(3, (try? await t.count) ?? 0)

            let person = Person(userId: r.id, name: r.username,
                                streak: stats.streak, summits: stats.summits,
                                avatarURL: r.avatarUrl.flatMap(URL.init(string:)))
            return (person, today)
        } catch {
            return nil
        }
    }
}
