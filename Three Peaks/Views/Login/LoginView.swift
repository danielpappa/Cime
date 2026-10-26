import SwiftUI

struct LoginView: View {
    @Environment(PeaksStore.self) private var store
    @State private var email = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Three goals · live proof")
                .monoCaps(10)
                .foregroundStyle(Theme.glacier)

            Text("Three Peaks")
                .displayFont(48)
                .padding(.top, 8)

            TreCimeView(done: [true, true, true])
                .padding(.top, 40)

            Spacer()

            VStack(spacing: 12) {
                Button("Continue with Apple") { signIn(.apple) }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.foreground)
                    .foregroundStyle(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Button("Continue with Google") { signIn(.google) }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.card)
                    .foregroundStyle(Theme.foreground)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                HStack {
                    Rectangle().fill(Theme.border).frame(height: 1)
                    Text("or").monoCaps(10).foregroundStyle(Theme.mutedForeground)
                    Rectangle().fill(Theme.border).frame(height: 1)
                }
                .padding(.vertical, 8)

                HStack(spacing: 8) {
                    TextField("you@email.com", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .padding(16)
                        .background(Theme.card)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                    Button("Go") {
                        if email.contains("@") {
                            store.signIn(Session(provider: .email, email: email))
                        }
                    }
                    .font(.headline)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Theme.primary)
                    .foregroundStyle(Theme.primaryForeground)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Text("Demo sign-in · no real account is created")
                    .monoCaps(10)
                    .foregroundStyle(Theme.mutedForeground)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 64)
        .padding(.bottom, 40)
        .topoBackground()
        .riseOnAppear()
    }

    private func signIn(_ provider: AuthProvider) {
        store.signIn(Session(provider: provider, email: nil))
    }
}

#Preview {
    MainTabView()
}
