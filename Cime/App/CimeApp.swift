import SwiftUI

/// The main application entry point that manages root session state, global UI and lifecycle refreshes
@main
struct CimeApp: App {
    
    /// Root application state shared across the view hierarchy via the environment
    @State private var store = CimeStore()
    /// Tracks whether the app is active, inactive, or in the background
    @Environment(\.scenePhase) private var scenePhase
    
    var body: some Scene {
        WindowGroup {
            rootContent
                .environment(store)
                .overlay {
                    EdgeGlowCelebration(trigger: store.celebrationToken)
                }
                .preferredColorScheme(.dark)
                .alert(
                    "Something Went Wrong",
                    isPresented: errorAlertBinding,
                    actions: {
                        Button("OK", role: .cancel) {
                            store.lastError = nil
                        }
                    },
                    message: {
                        if let error = store.lastError {
                            Text(error.description)
                        }
                    }
                )
                .onChange(of: scenePhase) { _, newPhase in
                    handleScenePhaseChange(newPhase)
                }
        }
    }
    
    /// Selects the top-level screen based on startup and authentication state.
    @ViewBuilder
    private var rootContent: some View {
        if store.isBootstrapping {
            SplashView()
        } else if store.appSession != nil {
            MainTabView()
        } else {
            LoginView()
        }
    }
    
    /// Two-way binding that presents an alert whenever `store.lastError` is non-nil
    /// and clears the error when dismissed.
    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { store.lastError != nil },
            set: { isPresented in
                if !isPresented {
                    store.lastError = nil
                }
            }
        )
    }
    
    /// Triggers a data refresh when the app becomes active after initial bootstrap completes.
    private func handleScenePhaseChange(_ newPhase: ScenePhase) {
        guard newPhase == .active, !store.isBootstrapping else { return }
        
        Task {
            await store.refreshOnForeground()
        }
    }
}
