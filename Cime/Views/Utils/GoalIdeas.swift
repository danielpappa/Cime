//
//  GoalIdeasa.swift
//  Cime
//
//  Created by Daniel Pappalardo on 15/11/2026.
//

import SwiftUI

// MARK: - Context (season, hemisphere, time of day, locale)

enum Hemisphere {
    case north, south

    /// Approximate, from the time zone: no location permission needed.
    /// (Swap in CoreLocation's coarse latitude later if you want it exact.)
    static var current: Hemisphere {
        let id = TimeZone.current.identifier
        let southern = [
            "Australia/", "Pacific/Auckland", "Pacific/Fiji", "Pacific/Tahiti",
            "America/Sao_Paulo", "America/Argentina/", "America/Santiago", "America/Montevideo",
            "America/Asuncion", "America/La_Paz", "America/Lima",
            "Africa/Johannesburg", "Africa/Maputo", "Africa/Harare", "Africa/Lusaka", "Africa/Windhoek",
            "Indian/Mauritius", "Indian/Reunion", "Indian/Antananarivo"
        ]
        return southern.contains { id.hasPrefix($0) } ? .south : .north
    }
}

enum Season: String {
    case winter, spring, summer, autumn

    static func current(_ date: Date = .now, hemisphere: Hemisphere = .current) -> Season {
        let month = Calendar.current.component(.month, from: date)
        let northern: Season = switch month {
        case 12, 1, 2: .winter
        case 3, 4, 5: .spring
        case 6, 7, 8: .summer
        default: .autumn
        }
        guard hemisphere == .south else { return northern }
        switch northern {
        case .winter: return .summer
        case .spring: return .autumn
        case .summer: return .winter
        case .autumn: return .spring
        }
    }
}

enum DayPart: String {
    case morning, afternoon, evening, night

    static func from(hour: Int) -> DayPart {
        switch hour {
        case 5..<12: .morning
        case 12..<17: .afternoon
        case 17..<22: .evening
        default: .night
        }
    }
}

struct IdeaContext {
    let season: Season
    let part: DayPart
    let isWeekend: Bool
    let region: String?          // "AT", "US"... from the device locale
    let seed: UInt64             // same for the whole day, so the ideas don't reshuffle on every redraw

    static func now(_ date: Date = .now) -> IdeaContext {
        let cal = Calendar.current
        let weekday = cal.component(.weekday, from: date)             // 1 = Sunday
        let year = cal.component(.year, from: date)
        let day = cal.ordinality(of: .day, in: .year, for: date) ?? 1
        return IdeaContext(
            season: .current(date),
            part: .from(hour: cal.component(.hour, from: date)),
            isWeekend: weekday == 1 || weekday == 7,
            region: Locale.current.region?.identifier,
            seed: UInt64(year * 1000 + day))
    }

    /// "Crisp autumn morning"
    var headline: String {
        let adjective: String = switch season {
        case .winter: "Cozy"
        case .spring: "Fresh"
        case .summer: "Golden"
        case .autumn: "Crisp"
        }
        let partName = part == .night ? "late night" : part.rawValue
        return "\(adjective) \(season.rawValue) \(partName)"
    }
}

// MARK: - Idea model

struct GoalIdea: Identifiable, Hashable {
    enum Topic: String, CaseIterable, Identifiable {
        case move, mind, create, learn, home, outdoors, social
        var id: String { rawValue }

        var title: String { rawValue.capitalized }

        var symbol: String {
            switch self {
            case .move: "figure.run"
            case .mind: "brain.head.profile"
            case .create: "paintbrush.pointed.fill"
            case .learn: "book.fill"
            case .home: "house.fill"
            case .outdoors: "leaf.fill"
            case .social: "person.2.fill"
            }
        }

        var tint: Color {
            switch self {
            case .move, .create, .outdoors, .social: Theme.summit
            case .mind, .learn, .home: Theme.glacier
            }
        }
    }

    enum Days { case any, weekend, weekday }

    let text: String
    let topic: Topic
    let searchTerm: String               // tapping the idea searches today's summits for this
    var seasons: Set<Season> = []        // empty = any season
    var parts: Set<DayPart> = []         // empty = any time of day (soft preference)
    var days: Days = .any
    var regions: Set<String> = []        // empty = everywhere
    var id: String { text }
}

struct SeedTerm: Identifiable {
    let label: String
    let term: String
    var id: String { term }
}

// MARK: - Picking

private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {          // SplitMix64
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

enum GoalIdeas {
    /// Ranked for this moment: season and weekend/weekday are hard filters, time of day and
    /// locale are boosts, a daily seeded jitter keeps it fresh. Max 2 per topic in the mixed view.
    static func pick(for ctx: IdeaContext, topic: GoalIdea.Topic?, limit: Int = 10) -> [GoalIdea] {
        var rng = SeededRNG(seed: ctx.seed)

        let candidates = all.filter { idea in
            (topic == nil || idea.topic == topic)
            && (idea.seasons.isEmpty || idea.seasons.contains(ctx.season))
            && (idea.days == .any || (idea.days == .weekend) == ctx.isWeekend)
            && (idea.regions.isEmpty || (ctx.region.map(idea.regions.contains) ?? false))
        }

        let scored = candidates.map { idea -> (idea: GoalIdea, score: Double) in
            var s = Double.random(in: 0..<1, using: &rng)
            if idea.parts.contains(ctx.part) { s += 1.5 } else if !idea.parts.isEmpty { s -= 1 }
            if !idea.seasons.isEmpty { s += 0.8 }       // seasonal ideas float up
            if !idea.regions.isEmpty { s += 1.2 }       // so do local ones
            if idea.days != .any { s += 0.5 }
            return (idea, s)
        }
        .sorted { $0.score > $1.score }

        var picked: [GoalIdea] = []
        var perTopic: [GoalIdea.Topic: Int] = [:]
        let cap = topic == nil ? 2 : limit
        for entry in scored where picked.count < limit {
            if perTopic[entry.idea.topic, default: 0] < cap {
                picked.append(entry.idea)
                perTopic[entry.idea.topic, default: 0] += 1
            }
        }
        for entry in scored where picked.count < limit && !picked.contains(entry.idea) {
            picked.append(entry.idea)
        }
        return picked
    }

    static let seedTerms: [SeedTerm] = [
        SeedTerm(label: "Running", term: "run"),
        SeedTerm(label: "Reading", term: "read"),
        SeedTerm(label: "Meditation", term: "meditat"),
        SeedTerm(label: "Cooking", term: "cook"),
        SeedTerm(label: "Workout", term: "workout"),
        SeedTerm(label: "Writing", term: "write"),
        SeedTerm(label: "Studying", term: "study"),
        SeedTerm(label: "Walking", term: "walk"),
        SeedTerm(label: "Cleaning", term: "clean"),
        SeedTerm(label: "Journaling", term: "journal")
    ]

    static let all: [GoalIdea] = [
        // MOVE
        idea("Run or brisk-walk 5 km before breakfast", .move, "run", seasons: [.spring, .summer, .autumn], parts: [.morning]),
        idea("30 minutes of strength training, phone in another room", .move, "strength"),
        idea("10,000 steps. Take every detour.", .move, "steps"),
        idea("Stretch for 15 minutes before bed", .move, "stretch", parts: [.evening, .night]),
        idea("Bike somewhere you'd normally drive", .move, "bike", seasons: [.spring, .summer, .autumn]),
        idea("Take the stairs. All of them. All day.", .move, "stairs"),
        idea("Do 50 push-ups, in as many sets as you need", .move, "push"),
        idea("Bundle up and walk for 30 minutes in the cold", .move, "walk", seasons: [.winter]),
        idea("20-minute home workout, no equipment", .move, "workout", seasons: [.winter]),
        idea("Swim before work", .move, "swim", seasons: [.summer], parts: [.morning]),
        idea("Catch the sunrise on a run", .move, "run", seasons: [.spring, .summer], parts: [.morning]),
        idea("Walk until the leaves crunch: 45 minutes", .move, "walk", seasons: [.autumn]),
        idea("Trail run through the nearest forest", .move, "trail", seasons: [.spring, .autumn], days: .weekend),
        idea("Try a class you've never taken: yoga, climbing, boxing", .move, "yoga", days: .weekend),

        // MIND
        idea("Meditate for 10 quiet minutes", .mind, "meditat", parts: [.morning]),
        idea("Write three pages in a journal", .mind, "journal"),
        idea("No phone for the first hour of the day", .mind, "phone", parts: [.morning]),
        idea("Write down three wins from this week", .mind, "wins", parts: [.evening]),
        idea("Screens off 30 minutes before bed", .mind, "sleep", parts: [.evening, .night]),
        idea("Five minutes of box breathing, twice today", .mind, "breath"),
        idea("Plan tomorrow's three peaks before 9 pm", .mind, "plan", parts: [.evening]),
        idea("Light a candle and journal for 15 minutes", .mind, "journal", seasons: [.winter], parts: [.evening]),
        idea("Read outside for 30 minutes", .mind, "read", seasons: [.spring, .summer]),
        idea("Lights out by 22:30. Protect your sleep.", .mind, "sleep", seasons: [.winter, .autumn]),

        // CREATE
        idea("Write 500 words of anything", .create, "write"),
        idea("Sketch what's on your desk right now", .create, "sketch"),
        idea("Cook a recipe you've never tried", .create, "cook"),
        idea("Practice an instrument for 25 focused minutes", .create, "music"),
        idea("Take 10 photos of a single street", .create, "photo"),
        idea("Ship one small piece of your side project", .create, "project"),
        idea("Bake something with apples or pumpkin", .create, "bake", seasons: [.autumn]),
        idea("Make a soup from scratch", .create, "soup", seasons: [.winter]),
        idea("Paint, knit or draw for 30 cozy minutes", .create, "draw", seasons: [.winter], parts: [.evening]),
        idea("Cook a meal with whatever is in season at the market", .create, "cook", seasons: [.spring, .summer]),

        // LEARN
        idea("Read 20 pages of a real book", .learn, "read"),
        idea("Learn 10 new words in a language", .learn, "language"),
        idea("Study for 45 deep-focus minutes", .learn, "study"),
        idea("Watch a lecture and write down three takeaways", .learn, "lecture"),
        idea("Teach a friend something you just learned", .learn, "learn"),
        idea("Finish one online lesson or tutorial", .learn, "course"),

        // HOME
        idea("Declutter one drawer. Just one.", .home, "declutter"),
        idea("Clean your desk and clear your inbox", .home, "clean"),
        idea("Meal-prep lunches for the next three days", .home, "meal"),
        idea("Fix the one thing you keep avoiding", .home, "fix"),
        idea("Open every window and spring-clean one room", .home, "clean", seasons: [.spring]),
        idea("Swap your wardrobe for the cold months", .home, "wardrobe", seasons: [.autumn]),
        idea("Clear out five things you never use", .home, "declutter", seasons: [.winter]),
        idea("Water the plants and start a tiny herb garden", .home, "plants", seasons: [.spring, .summer]),

        // OUTDOORS
        idea("One hour outside, no headphones", .outdoors, "outside"),
        idea("Visit a park you've never been to", .outdoors, "park"),
        idea("Watch the sunset from somewhere new", .outdoors, "sunset", seasons: [.spring, .summer, .autumn], parts: [.evening]),
        idea("Hike up the nearest hill", .outdoors, "hike", seasons: [.spring, .summer, .autumn], days: .weekend),
        idea("Go sledding or build a snowman", .outdoors, "snow", seasons: [.winter], days: .weekend),
        idea("Stargaze for 15 minutes", .outdoors, "stars", parts: [.evening, .night]),
        idea("Swim in a lake or river", .outdoors, "swim", seasons: [.summer], days: .weekend),
        idea("Collect the most colorful leaves you can find", .outdoors, "leaves", seasons: [.autumn]),
        idea("Find the first spring flowers", .outdoors, "flowers", seasons: [.spring]),

        // SOCIAL
        idea("Call someone you haven't spoken to in a month", .social, "call"),
        idea("Send three genuine thank-you messages", .social, "thank"),
        idea("Invite a friend on a walk", .social, "walk"),
        idea("Cook dinner for someone", .social, "cook", parts: [.evening]),
        idea("Plan a weekend adventure with friends", .social, "plan", days: .weekday),
        idea("Long breakfast with someone you like", .social, "breakfast", parts: [.morning], days: .weekend),

        // NEAR YOU (matched on the device's region)
        idea("Take a Waldspaziergang: an hour in the woods", .outdoors, "forest", regions: ["AT", "DE", "CH"]),
        idea("Kaffeehaus hour: a Melange and 30 minutes of writing", .create, "write", regions: ["AT"]),
        idea("Climb your nearest Hausberg", .outdoors, "hike", seasons: [.spring, .summer, .autumn], regions: ["AT", "CH"]),
        idea("Explore a trail you've never hiked", .outdoors, "trail", regions: ["US", "CA"]),
        idea("A long walk, then a proper cup of tea", .outdoors, "walk", regions: ["GB", "IE"]),
        idea("Cook a long, slow dinner from scratch", .create, "cook", regions: ["FR", "IT", "ES"]),
        idea("Cycle instead of taking the car or tram", .move, "cycle", regions: ["NL", "DK"])
    ]
}

private func idea(_ text: String, _ topic: GoalIdea.Topic, _ term: String,
                  seasons: Set<Season> = [], parts: Set<DayPart> = [],
                  days: GoalIdea.Days = .any, regions: Set<String> = []) -> GoalIdea {
    GoalIdea(text: text, topic: topic, searchTerm: term,
             seasons: seasons, parts: parts, days: days, regions: regions)
}

// MARK: - Trending words in today's public summits

struct TrendingWord: Identifiable {
    let word: String
    let count: Int
    var id: String { word }
}

enum Trending {
    private static let stopwords: Set<String> = [
        "the", "and", "for", "with", "that", "this", "from", "your", "have", "today", "tomorrow",
        "finish", "complete", "make", "some", "into", "about", "more", "than", "then", "also",
        "need", "want", "work", "time", "hour", "hours", "minutes", "daily", "every", "each",
        "minute", "before", "after", "over", "just", "get", "got", "done", "start"
    ]

    /// Words that show up in at least two different summits, most common first.
    static func keywords(from texts: [String], limit: Int = 6) -> [TrendingWord] {
        var counts: [String: Int] = [:]
        for text in texts {
            let words = Set(text.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            for w in words where w.count >= 4 && !stopwords.contains(w) { counts[w, default: 0] += 1 }
        }
        return counts
            .filter { $0.value >= 2 }
            .sorted { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }
            .prefix(limit)
            .map { TrendingWord(word: $0.key, count: $0.value) }
    }
}
