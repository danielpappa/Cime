import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(PeaksStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showAvatarCamera = false
    @State private var showResetConfirm = false

    private var reached: Int { PeaksStore.unlockedCount(goals: store.day.goals) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                avatarSection
                statsGrid
                TreCimeView(done: (0..<3).map { store.day.goals.indices.contains($0) && store.day.goals[$0].done })
                    .padding(16)
                    .background(Theme.card)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.top, 32)

                historySection
                proofGrid
                settingsSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .topoBackground()
        .navigationBarBackButtonHidden()
        .riseOnAppear()
        .fullScreenCover(isPresented: $showAvatarCamera) {
            LiveCameraView(
                goal: "New profile photo",
                modes: [.photo],
                onClose: { showAvatarCamera = false },
                onProof: { data, _ in
                    var profile = store.profile
                    profile.avatarJPEG = data
                    store.saveProfile(profile)
                    showAvatarCamera = false
                }
            )
        }
        .confirmationDialog("Clear today's goals and proof?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset today's peaks", role: .destructive) {
                store.resetDay()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 8) {
            Button { showAvatarCamera = true } label: {
                Group {
                    if let jpeg = store.profile.avatarJPEG, let ui = UIImage(data: jpeg) {
                        Image(uiImage: ui).resizable().scaledToFill()
                    } else {
                        Text(String(store.profile.username.prefix(1)).uppercased())
                            .displayFont(36)
                    }
                }
                .frame(width: 112, height: 112)
                .background(Theme.secondary)
                .clipShape(Circle())
                .overlay(Circle().stroke(Theme.summit, lineWidth: 2))
            }
            .emberGlow()

            Text("Tap to edit")
                .monoCaps(10)
                .foregroundStyle(Theme.mutedForeground)

            Text("@\(store.profile.username)")
                .displayFont(28)
                .padding(.top, 8)
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCell("\(store.streakDisplay)", label: "day streak")
            statCell("\(reached)/3", label: "today")
            statCell("41", label: "summits")
        }
        .padding(.top, 32)
    }

    private func statCell(_ value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value).displayFont(24)
            Text(label)
                .monoCaps(10)
                .foregroundStyle(Theme.mutedForeground)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.card)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Last 14 days")
                .displayFont(20)
                .padding(.top, 32)

            HStack(spacing: 6) {
                ForEach(Array(DemoContent.profileHistory.enumerated()), id: \.offset) { _, count in
                    VStack(spacing: 2) {
                        ForEach((0..<3).reversed(), id: \.self) { k in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(k < count ? Theme.summit : Theme.secondary)
                                .frame(height: 12)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private var proofGrid: some View {
        let proofs = store.day.goals.compactMap(\.proofJPEG)
        if !proofs.isEmpty {
            Text("Today's proof")
                .displayFont(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)

            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()], spacing: 8) {
                ForEach(Array(proofs.enumerated()), id: \.offset) { _, jpeg in
                    if let ui = UIImage(data: jpeg) {
                        Image(uiImage: ui)
                            .resizable()
                            .scaledToFill()
                            .aspectRatio(1, contentMode: .fill)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .padding(.top, 12)
        }
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings")
                .displayFont(20)
                .padding(.top, 32)

            Text("Account")
                .monoCaps(10)
                .foregroundStyle(Theme.glacier)

            HStack {
                Text("@").foregroundStyle(Theme.mutedForeground)
                TextField("username", text: Binding(
                    get: { store.profile.username },
                    set: { new in
                        let cleaned = new.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
                        var profile = store.profile
                        profile.username = cleaned.isEmpty ? "you" : cleaned
                        store.saveProfile(profile)
                    }
                ))
            }
            .padding(14)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(sessionLabel)
                .font(.subheadline)
                .foregroundStyle(Theme.mutedForeground)

            Text("Climbing")
                .monoCaps(10)
                .foregroundStyle(Theme.glacier)
                .padding(.top, 8)

            VStack(spacing: 0) {
                SettingsToggle(
                    label: "Morning reminder",
                    hint: "A nudge at 8:00 to pick your peaks",
                    isOn: store.profile.reminders
                ) { store.saveProfile(Profile(
                    username: store.profile.username,
                    avatarJPEG: store.profile.avatarJPEG,
                    reminders: $0,
                    privateSummits: store.profile.privateSummits
                )) }
                Divider().overlay(Theme.border)
                SettingsToggle(
                    label: "Private summits",
                    hint: "Only friends you follow back see your proof",
                    isOn: store.profile.privateSummits
                ) { store.saveProfile(Profile(
                    username: store.profile.username,
                    avatarJPEG: store.profile.avatarJPEG,
                    reminders: store.profile.reminders,
                    privateSummits: $0
                )) }
            }
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Text("Danger zone")
                .monoCaps(10)
                .foregroundStyle(Theme.glacier)
                .padding(.top, 8)

            Button("Reset today's peaks") { showResetConfirm = true }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .foregroundStyle(Theme.destructive)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.destructive.opacity(0.5)))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Sign out") {
                store.signOut()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 32)
        }
    }

    private var sessionLabel: String {
        guard let session = store.session else { return "" }
        switch session.provider {
        case .email: return "Signed in with \(session.email ?? "email")"
        case .apple: return "Signed in with Apple"
        case .google: return "Signed in with Google"
        }
    }
}

private struct SettingsToggle: View {
    let label: String
    let hint: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        Button { onChange(!isOn) } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(label).font(.body.weight(.medium))
                    Text(hint).font(.subheadline).foregroundStyle(Theme.mutedForeground)
                }
                Spacer()
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule().fill(isOn ? Theme.summit : Theme.secondary).frame(width: 48, height: 28)
                    Circle().fill(Theme.snow).frame(width: 20, height: 20).padding(4)
                }
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    MainTabView()
}
