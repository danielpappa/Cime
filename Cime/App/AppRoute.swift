/// Used for type-safe navigation across a `NavigationStack`.
enum AppRoute: Hashable {
    case profile            // current user profile screen
    case person(String)     // person/friend profile screen
}
