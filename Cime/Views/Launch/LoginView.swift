import SwiftUI
import AuthenticationServices
import CryptoKit

struct LoginView: View {
    @Environment(CimeStore.self) private var store
    @Environment(\.colorScheme) private var colorScheme

    @State private var email = ""
    @State private var username = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var isLoading = false
    @State private var message: String?
    @State private var messageIsError = true
    @State private var appleNonce = ""
    
    @FocusState private var focus: Field?
    private enum Field: Hashable { case username, email, password }

    private var canSubmit: Bool {
        if isSignUp {
            return email.contains("@") && !username.isEmpty && password.count >= 8 && !isLoading
        } else {
            return !email.isEmpty && password.count >= 8 && !isLoading
        }
    }

    var body: some View {
        GeometryReader { geo in
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Three goals · Three Peaks")
                            .monoCaps(10)
                            .foregroundStyle(Theme.glacier)
                        
                        Text("Cime")
                            .displayFont(48)
                            .padding(.top, 8)
                        
                        LogoView(done: [true, true, false])
                            .padding(.top, 20)
                            .scaleEffect(0.7)
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            SignInWithAppleButton(.continue) { request in
                                let nonce = Self.randomNonce()
                                appleNonce = nonce
                                request.requestedScopes = [.fullName, .email]
                                request.nonce = Self.sha256(nonce)
                            } onCompletion: { result in
                                handleApple(result)
                            }
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            
                            Button { handleGoogle() } label: {
                                HStack(spacing: 6) {
                                    Image("GoogleLogo")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 18, height: 18)
                                    Text("Continue with Google")
                                        .font(.system(size: 19, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(Theme.card)
                                .foregroundStyle(Theme.foreground)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            
                            HStack {
                                Rectangle().fill(Theme.border).frame(height: 1)
                                Text("or").monoCaps(10).foregroundStyle(Theme.mutedForeground)
                                Rectangle().fill(Theme.border).frame(height: 1)
                            }
                            .padding(.vertical, 8)
                            
                            if isSignUp {
                                field { TextField("Username", text: $username)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .textContentType(.username)
                                    .focused($focus, equals: .username)
                                    .submitLabel(.next)
                                    .onSubmit { focus = .email } }
                                    .id(Field.username)

                                field { TextField("your@email.com", text: $email)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .keyboardType(.emailAddress).textContentType(.emailAddress)
                                    .focused($focus, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focus = .password } }
                                    .id(Field.email)
                            } else {
                                field { TextField("Email or Username", text: $email)
                                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                                    .textContentType(.username)            // lets the password manager autofill
                                    .focused($focus, equals: .email)
                                    .submitLabel(.next)
                                    .onSubmit { focus = .password } }
                                    .id(Field.email)
                            }

                            field { SecureField("Password (8+ characters)", text: $password)
                                .textContentType(isSignUp ? .newPassword : .password)
                                .focused($focus, equals: .password)
                                .submitLabel(isSignUp ? .join : .go)
                                .onSubmit { if canSubmit { submit() } } }
                                .id(Field.password)
                            
                            Button {
                                submit()
                            } label: {
                                Group {
                                    if isLoading { ProgressView() }
                                    else { Text(isSignUp ? "Create account" : "Sign in") }
                                }
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Theme.primary)
                                .foregroundStyle(Theme.primaryForeground)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(!canSubmit)
                            .opacity(canSubmit ? 1 : 0.4)
                            
                            HStack {
                                Button(isSignUp ? "Have an account? Sign in" : "New here? Create account") {
                                    isSignUp.toggle()
                                    message = nil
                                }
                                Spacer()
                                if !isSignUp {
                                    Button("Forgot password?") { resetPassword() }
                                }
                            }
                            .font(.subheadline)
                            .foregroundStyle(Theme.mutedForeground)
                            
                            if let message {
                                Text(message)
                                    .font(.footnote)
                                    .foregroundStyle(messageIsError ? Theme.destructive : Theme.glacier)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 12)
                    .padding(.bottom, 40)
                    .frame(minHeight: geo.size.height)
                }
                .scrollDismissesKeyboard(.interactively)   // drag down to dismiss
                .scrollBounceBehavior(.basedOnSize)        // no bounce when it all fits
                .onChange(of: focus) { _, field in         // keep the active field visible
                    guard let field else { return }
                    withAnimation { proxy.scrollTo(field, anchor: .center) }
                }
            }
        }
        .topoBackground()
        .riseOnAppear()
    }

    private func field<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(16)
            .background(Theme.card)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.border))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: Actions

    private func submit() {
        let input = email.trimmingCharacters(in: .whitespaces)
        let user = username.trimmingCharacters(in: .whitespaces).lowercased()
        isLoading = true
        message = nil
        Task {
            defer { isLoading = false }
            do {
                if isSignUp {
                    let needsConfirmation = try await store.signUp(email: input, username: user, password: password)
                    if needsConfirmation { show("Check your inbox to confirm your email.", error: false) }
                } else {
                    try await store.signIn(identifier: input, password: password)
                }
            } catch {
                show(error.localizedDescription)
            }
        }
    }

    private func resetPassword() {
        let email = email.trimmingCharacters(in: .whitespaces)
        guard email.contains("@") else { show("Enter your email first."); return }
        Task {
            do {
                try await store.sendPasswordReset(email: email)
                show("Password reset email sent.", error: false)
            } catch {
                show(error.localizedDescription)
            }
        }
    }

    private func handleApple(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .failure(let error):
            if (error as? ASAuthorizationError)?.code != .canceled { show(error.localizedDescription) }
        case .success(let auth):
            guard let cred = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = cred.identityToken,
                  let idToken = String(data: tokenData, encoding: .utf8) else {
                show("Apple sign-in failed.")
                return
            }
            isLoading = true
            Task {
                defer { isLoading = false }
                do { try await store.signInWithApple(idToken: idToken, nonce: appleNonce) }
                catch { show(error.localizedDescription) }
            }
        }
    }
    
    private func handleGoogle() {
        isLoading = true
        message = nil
        Task {
            defer { isLoading = false }
            do { try await store.signInWithGoogle() }
            catch let e as ASWebAuthenticationSessionError where e.code == .canceledLogin { /* user closed the sheet */ }
            catch { show(error.localizedDescription) }
        }
    }

    private func show(_ text: String, error: Bool = true) {
        message = text
        messageIsError = error
    }

    // MARK: Nonce helpers (Apple requires a SHA-256 of the raw nonce in the request)

    private static func randomNonce(length: Int = 32) -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var bytes = [UInt8](repeating: 0, count: length)
        precondition(SecRandomCopyBytes(kSecRandomDefault, length, &bytes) == errSecSuccess)
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

#Preview {
    LoginView()
        .environment(CimeStore())
}
