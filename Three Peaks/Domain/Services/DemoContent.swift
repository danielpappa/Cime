import Foundation

enum DemoContent {
    static let people: [Person] = [
        Person(name: "maya.k", full: "Maya Krüger", bio: "Trail runner. Early riser.", streak: 23, summits: 112),
        Person(name: "jonas", full: "Jonas Berg", bio: "Med student, coffee-powered.", streak: 9, summits: 54),
        Person(name: "ari_lane", full: "Ari Lane", bio: "Cooking my way through 2026.", streak: 15, summits: 77),
        Person(name: "lea.m", full: "Lea Moser", bio: "Climber from Bolzano.", streak: 31, summits: 140),
        Person(name: "tomasz", full: "Tomasz Nowak", bio: "Building things after hours.", streak: 4, summits: 19),
        Person(name: "nina.v", full: "Nina Vidal", bio: "Piano, pages, pilates.", streak: 12, summits: 60),
        Person(name: "kofi", full: "Kofi Mensah", bio: "Learning Italian, one word a day.", streak: 7, summits: 33),
    ]

    static let friendSummits: [FriendSummit] = [
        FriendSummit(name: "maya.k", goal: "Run 8k before work", imageName: "f1", time: "06:42"),
        FriendSummit(name: "jonas", goal: "Finish chapter 4 notes", imageName: "f2", time: "09:15"),
        FriendSummit(name: "ari_lane", goal: "Cook instead of ordering", imageName: "f3", time: "12:30"),
    ]

    static let profileHistory: [Int] = [3, 3, 2, 3, 3, 1, 3, 3, 3, 0, 2, 3, 3, 3]

    static let peakNames = ["Base", "Ridge", "Summit"]

    static func person(named name: String) -> Person? {
        people.first { $0.name == name }
    }
}
