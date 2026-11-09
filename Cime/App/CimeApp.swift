import SwiftUI

@main
struct CimeApp: App {
    @State private var store = CimeStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            Group {
                if store.isBootstrapping {
                    // 1. Show Splash screen while store initializes session & data
                    SplashView()
                } else if store.appSession != nil {
                    // 2. Main Authenticated Flow
                    MainTabView()
                } else {
                    // 3. Unauthenticated Login Flow
                    LoginView()
                }
            }
            .environment(store)
            .overlay { EdgeGlowCelebration(trigger: store.celebrationToken) }
            .preferredColorScheme(.dark)
            // 4. Alert bound to store.lastError
            .alert(
                "Error",
                isPresented: Binding(
                    get: { store.lastError != nil },
                    set: { isPresented in
                        if !isPresented { store.lastError = nil }
                    }
                ),
                actions: {
                    Button("OK", role: .cancel) {
                        store.lastError = nil
                    }
                },
                message: {
                    if let error = store.lastError {
                        Text(error.debugDescription)
                    }
                }
            )
            // 5. Refresh store data when app enters active foreground state
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task {
                        await store.refreshOnForeground()
                    }
                }
            }
        }
    }
}
