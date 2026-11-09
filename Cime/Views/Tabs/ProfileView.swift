import SwiftUI
import UIKit

struct ProfileView: View {
    @Environment(CimeStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    @State private var showAvatarCamera = false
    @State private var showResetConfirm = false
    @State private var showDeleteConfirm = false
    @State private var showRequests = false

    @State private var usernameDraft = ""
    @State private var usernameError: String?
    @State private var isSavingUsername = false
    @State private var history: [Int] = Array(repeating: 0, count: 14)

    private var reached: Int { CimeStore.unlockedCount(goals: store.day.goals) }
    private var username: String { store.profile?.username ?? "" }
    private var usernameChanged: Bool { !usernameDraft.isEmpty && usernameDraft != username }
    private var usernameValid: Bool { CimeStore.isValid(username: usernameDraft) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                avatarSection
                statsGrid
                LogoView(done: (0..<3).map { store.day.goals.indices.contains($0) && store.day.goals[$0].done })
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
        .task(id: store.profile?.username) { usernameDraft = username }
        .task(id: store.stats.summits) { history = await store.fetchHistory() }
        .sheet(isPresented: $showRequests) { FollowRequestsView() }
        .fullScreenCover(isPresented: $showAvatarCamera) {
            LiveCameraView(
                goal: "New profile photo",
                modes: [.photo],
                onClose: { showAvatarCamera = false },
                onProof: { data, _ in
                    showAvatarCamera = false
                    Task {
                        guard let small = data.jpegDownscaled(maxSide: 512, quality: 0.75) else { return }
                        do { try await store.updateAvatar(small) }
                        catch { store.lastError = "Couldn't update your photo" }
                    }
                }
            )
        }
        .confirmationDialog("Clear today's goals and proof?", isPresented: $showResetConfirm, titleVisibility: .visible) {
            Button("Reset today's peaks", role: .destructive) { store.resetDay() }
            Button("Cancel", role: .cancel) {}
        }
        .confirmationDialog("Delete your account? This permanently removes your profile, goals and proof.",
                            isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete account", role: .destructive) {
                Task {
                    do { try await store.deleteAccount() }
                    catch { store.lastError = "Couldn't delete your account" }
                }
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private var avatarSection: some View {
        VStack(spacing: 8) {
            Button { showAvatarCamera = true } label: {
                AvatarView(jpeg: store.profile?.avatarJPEG,
                           url: store.profile?.avatarURL.flatMap(URL.init(string:)),
                           letter: username, size: 112)
                    .overlay(Circle().stroke(Theme.summit, lineWidth: 2))
            }
            .emberGlow()

            Text("Tap to edit")
                .monoCaps(10)
                .foregroundStyle(Theme.mutedForeground)

            Text(username)
                .displayFont(28)
                .padding(.top, 8)
        }
    }

    private var statsGrid: some View {
        HStack(spacing: 12) {
            statCell("\(store.streakDisplay)", label: "day streak")
            statCell("\(reached)/3", label: "today")
            statCell("\(store.stats.summits)", label: "summits")
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
                ForEach(Array(history.enumerated()), id: \.offset) { _, count in
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
        let proofs = store.day.goals.filter { $0.proofJPEG != nil || $0.proofPath != nil }
        if !proofs.isEmpty {
            Text("Today's proof")
                .displayFont(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 32)

            LazyVGrid(columns: [GridItem(), GridItem(), GridItem()], spacing: 8) {
                ForEach(proofs) { goal in
                    Color.clear
                        .aspectRatio(1, contentMode: .fit)
                        .overlay { ProofThumb(goal: goal) }
                        .clipShape(RoundedRectangle(cornerRadius: 8))
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

            usernameField

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
                    isOn: store.profile?.reminders ?? false
                ) { new in
                    Task {
                        if new, !(await ReminderScheduler.requestPermission()) {
                            store.lastError = "Allow notifications for Cime in Settings to get reminders."
                            return
                        }
                        update { $0.reminders = new }
                    }
                }
                Divider().overlay(Theme.border)

                privacyRow
                Divider().overlay(Theme.border)

                requestsRow
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

            Button("Delete account") { showDeleteConfirm = true }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .foregroundStyle(Theme.destructive)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.destructive.opacity(0.5)))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Button("Sign out") {
                Task { try? await store.signOut() }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.bottom, 32)
        }
    }

    // MARK: Username (explicit Save button: the old version only saved on keyboard "return")

    private var usernameField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text("Username").foregroundStyle(Theme.mutedForeground)
                TextField("username", text: $usernameDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .onChange(of: usernameDraft) { _, new in
                        usernameError = nil
                        let cleaned = String(new.lowercased().filter {
                            $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "." || $0 == "_")
                        }.prefix(20))
                        if cleaned != new { usernameDraft = cleaned }
                    }
                    .onSubmit(saveUsername)

                if usernameChanged {
                    Button(action: saveUsername) {
                        if isSavingUsername { ProgressView() }
                        else { Text("Save").font(.subheadline.weight(.semibold)) }
                    }
                    .foregroundStyle(usernameValid ? Theme.summit : Theme.mutedForeground)
                    .disabled(!usernameValid || isSavingUsername)
                }
            }
            .padding(14)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if let usernameError {
                Text(usernameError).font(.footnote).foregroundStyle(Theme.destructive)
            } else if usernameChanged && !usernameValid {
                Text("3–20 characters: a–z, 0–9, _ and .")
                    .font(.footnote).foregroundStyle(Theme.mutedForeground)
            }
        }
    }

    private var privacyRow: some View {
        let current = store.profile?.privacyLevel ?? .friendsOnly
        return HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Summit Privacy").font(.body.weight(.medium))
                Text(current.hint)
                    .font(.subheadline)
                    .foregroundStyle(Theme.mutedForeground)
            }

            Spacer()

            Menu {
                Picker("Summit Privacy", selection: Binding(
                    get: { current },
                    set: { new in update { $0.privacyLevel = new } }
                )) {
                    ForEach(SummitPrivacy.allCases) { privacy in
                        Text(privacy.label).tag(privacy)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Text(current.label).font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down").font(.caption2.weight(.bold))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Theme.secondary.opacity(0.6))
                .foregroundStyle(Theme.foreground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(16)
    }

    private var requestsRow: some View {
        let count = store.incomingRequests.count
        return Button { showRequests = true } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Follow requests").font(.body.weight(.medium))
                    Text(count == 0 ? "No pending requests" : "\(count) waiting for your answer")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mutedForeground)
                }
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Theme.summit)
                        .foregroundStyle(Theme.snow)
                        .clipShape(Capsule())
                }
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(Theme.mutedForeground)
            }
            .padding(16)
        }
        .buttonStyle(.plain)
    }

    // MARK: Actions

    private func update(_ change: (inout Profile) -> Void) {
        guard var p = store.profile else { return }
        change(&p)
        Task {
            do { try await store.saveProfile(p) }
            catch { store.lastError = error.localizedDescription }
        }
    }

    private func saveUsername() {
        guard var p = store.profile, usernameChanged, usernameValid, !isSavingUsername else { return }
        p.username = usernameDraft
        isSavingUsername = true
        Task {
            defer { isSavingUsername = false }
            do {
                try await store.saveProfile(p)
                usernameError = nil
            } catch {
                usernameError = error.localizedDescription
                // keep the draft so the user can fix it instead of losing what they typed
            }
        }
    }

    private var sessionLabel: String {
        guard let session = store.appSession else { return "" }
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
    ProfileView()
        .environment(CimeStore())
}
