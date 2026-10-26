import SwiftUI

struct MainTabView: View {
    @Environment(PeaksStore.self) private var store
    @State private var tab: MainTab = .climb
    @State private var proveGoalIndex: Int?
    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                VStack(spacing: 0) {
                    header
                    ClimbView(proveGoalIndex: $proveGoalIndex)
                }
                .topoBackground()
                .navigationDestination(for: AppRoute.self) { route in
                    routeDestination(for: route)
                }
                .fullScreenCover(isPresented: Binding(
                    get: { proveGoalIndex != nil },
                    set: { if !$0 { proveGoalIndex = nil } }
                )) {
                    proveGoalView
                }
                .onAppear { store.refreshDayIfNeeded() }
            }
            .tabItem {
                Label("Climb", systemImage: "mountain.2.fill")
            }
            .tag(MainTab.climb)
            
            NavigationStack {
                SummitsView()
                    .topoBackground()
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Summits", systemImage: "flag.fill")
            }
            .tag(MainTab.summits)
            
            NavigationStack {
                CrewView()
                    .topoBackground()
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Crew", systemImage: "person.3.fill")
            }
            .tag(MainTab.crew)
            
            NavigationStack {
                ProfileView()
                    .topoBackground()
                    .navigationDestination(for: AppRoute.self) { route in
                        routeDestination(for: route)
                    }
            }
            .tabItem {
                Label("Profile", systemImage: "figure.climbing")
            }
            .tag(MainTab.profile)
        }
        .tint(Theme.primary)
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.abbreviated)))
                    .monoCaps(10)
                    .foregroundStyle(Theme.glacier)
                Text("Three Peaks")
                    .displayFont(36)
            }
            Spacer()
            HStack(spacing: 8) {
                Text("▲ \(store.streakDisplay)")
                    .monoCaps(11)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(Capsule().stroke(Theme.border))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func routeDestination(for route: AppRoute) -> some View {
        switch route {
        case .profile:
            ProfileView()
        case .person(let name):
            PersonView(name: name)
        }
    }

    @ViewBuilder
    private var proveGoalView: some View {
        if let index = proveGoalIndex, store.day.goals.indices.contains(index) {
            LiveCameraView(
                goal: store.day.goals[index].text,
                onClose: { proveGoalIndex = nil },
                onProof: { data, kind in
                    store.updateDay { day in
                        guard day.goals.indices.contains(index) else { return }
                        day.goals[index].proofJPEG = data
                        day.goals[index].proofKind = kind
                        day.goals[index].done = true
                    }
                    proveGoalIndex = nil
                }
            )
        }
    }
}

#Preview {
    MainTabView()
}
