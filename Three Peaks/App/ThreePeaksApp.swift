import SwiftUI

@main
struct ThreePeaksApp: App {
    @State private var store = PeaksStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if store.session != nil {
                    MainTabView()
                } else {
                    LoginView()
                }
            }
            .environment(store)
            .preferredColorScheme(.dark)
        }
    }
}
