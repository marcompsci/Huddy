import AuthenticationServices
import Foundation
import SwiftUI

// MARK: - Account manager: wraps Sign in with Apple + session token in Keychain

@Observable
@MainActor
final class VegaAccountManager {
    static let shared = VegaAccountManager()
    private init() {}

    private(set) var userID:       String? = Keychain.get("vega.apple.userID")
    private(set) var userEmail:    String? = Keychain.get("vega.apple.email")
    private(set) var userName:     String? = Keychain.get("vega.apple.name")
    private(set) var sessionToken: String? = Keychain.get(Keychain.Keys.vegaSessionToken)

    var isSignedIn: Bool { userID != nil && !(sessionToken?.isEmpty ?? true) }

    // MARK: - Handle credential from SignInWithAppleButton

    func handleCredential(_ credential: ASAuthorizationAppleIDCredential) async {
        let uid   = credential.user
        let email = credential.email ?? Keychain.get("vega.apple.email") ?? ""
        let first = credential.fullName?.givenName  ?? ""
        let last  = credential.fullName?.familyName ?? ""
        let name  = [first, last].filter { !$0.isEmpty }.joined(separator: " ")

        // Persist identity fields (Apple only sends name/email on the very first sign-in)
        Keychain.set(uid, key: "vega.apple.userID")
        if !email.isEmpty { Keychain.set(email, key: "vega.apple.email") }
        if !name.isEmpty  { Keychain.set(name,  key: "vega.apple.name")  }
        userID    = uid
        userEmail = email.isEmpty ? Keychain.get("vega.apple.email") : email
        userName  = name.isEmpty  ? Keychain.get("vega.apple.name")  : name

        // Try to exchange identity token with backend for a real session token
        if let token = await exchangeAppleToken(credential: credential, uid: uid, name: name) {
            Keychain.set(token, key: Keychain.Keys.vegaSessionToken)
            sessionToken = token
        } else {
            // No backend configured yet — issue a stub token so the UI unblocks
            let stub = "stub_\(uid.prefix(8))_\(Int(Date().timeIntervalSince1970))"
            Keychain.set(stub, key: Keychain.Keys.vegaSessionToken)
            sessionToken = stub
        }
    }

    private func exchangeAppleToken(
        credential: ASAuthorizationAppleIDCredential,
        uid: String,
        name: String
    ) async -> String? {
        guard
            let tokenData = credential.identityToken,
            let identityToken = String(data: tokenData, encoding: .utf8),
            let rawURL = Keychain.get(Keychain.Keys.vegaBackendURL), !rawURL.isEmpty,
            let url = URL(string: rawURL)?.appendingPathComponent("v1/auth/apple")
        else { return nil }

        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "identity_token": identityToken,
            "user_id":        uid,
            "full_name":      name
        ])

        guard
            let (data, resp)  = try? await URLSession.shared.data(for: req),
            let http = resp as? HTTPURLResponse, http.statusCode == 200,
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let token = json["session_token"] as? String
        else { return nil }

        return token
    }

    // MARK: - Session validation (call on launch)

    /// Returns true if the stored session token is still valid, false if expired / revoked.
    /// A stub token (no backend configured) is treated as valid.
    @discardableResult
    func validateSession() async -> Bool {
        guard let token = Keychain.get(Keychain.Keys.vegaSessionToken), !token.isEmpty else {
            return false
        }
        // Stub tokens are always "valid" — they just won't reach a real backend
        if token.hasPrefix("stub_") { return true }

        guard
            let rawURL = Keychain.get(Keychain.Keys.vegaBackendURL), !rawURL.isEmpty,
            let url = URL(string: rawURL)?.appendingPathComponent("v1/session")
        else { return true }

        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse else { return true }

        if http.statusCode == 401 {
            Keychain.delete(Keychain.Keys.vegaSessionToken)
            sessionToken = nil
            return false
        }
        return http.statusCode == 200
    }

    // MARK: - Sign out

    func signOut() {
        ["vega.apple.userID", "vega.apple.email", "vega.apple.name"]
            .forEach { Keychain.delete($0) }
        Keychain.delete(Keychain.Keys.vegaSessionToken)
        userID = nil; userEmail = nil; userName = nil; sessionToken = nil
    }

    // MARK: - Delete account

    func deleteAccount() async {
        // Clear local state first
        VegaSession.shared.clear()
        await VegaMemoryManager.shared.forgetEverything()

        // Notify backend
        if let token = Keychain.get(Keychain.Keys.vegaSessionToken),
           let rawURL = Keychain.get(Keychain.Keys.vegaBackendURL),
           !rawURL.isEmpty,
           let url = URL(string: rawURL)?.appendingPathComponent("v1/account") {
            var req = URLRequest(url: url, timeoutInterval: 15)
            req.httpMethod = "DELETE"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            _ = try? await URLSession.shared.data(for: req)
        }
        signOut()
    }
}

// MARK: - Sign in with Apple button

struct VegaSignInButton: View {
    @State private var account = VegaAccountManager.shared
    @State private var error: String?

    var body: some View {
        VStack(spacing: 8) {
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                Task { @MainActor in
                    switch result {
                    case .success(let auth):
                        if let cred = auth.credential as? ASAuthorizationAppleIDCredential {
                            await account.handleCredential(cred)
                        }
                    case .failure(let err):
                        if (err as? ASAuthorizationError)?.code != .canceled {
                            error = err.localizedDescription
                        }
                    }
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            if let error {
                Text(error)
                    .font(HUDFont.mono(10))
                    .foregroundStyle(Color.hudRed)
                    .multilineTextAlignment(.center)
            }
        }
    }
}
