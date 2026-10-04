// GoogleSignIn SPM package must be added manually in Xcode:
// File → Add Package Dependencies → https://github.com/google/GoogleSignIn-iOS
// Until then this stub lets the project build.
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
import UIKit

@MainActor
final class GoogleSignInManager {
    static let shared = GoogleSignInManager()
    private init() {}

    private let gmailReadScope = "https://www.googleapis.com/auth/gmail.readonly"

    func configure() {
#if canImport(GoogleSignIn)
        guard let id = Bundle.main.object(forInfoDictionaryKey: "GIDClientID") as? String,
              !id.isEmpty else { return }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: id)
#endif
    }

    func signIn() async throws -> (token: String, email: String) {
#if canImport(GoogleSignIn)
        guard let vc = rootViewController() else { throw ServiceError.noCredentials }
        let result = try await GIDSignIn.sharedInstance.signIn(
            withPresenting: vc,
            hint: nil,
            additionalScopes: [gmailReadScope]
        )
        return (result.user.accessToken.tokenString, result.user.profile?.email ?? "")
#else
        throw ServiceError.noCredentials
#endif
    }

    func restoreSignIn() async -> (token: String, email: String)? {
#if canImport(GoogleSignIn)
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            try await user.refreshTokensIfNeeded()
            return (user.accessToken.tokenString, user.profile?.email ?? "")
        } catch { return nil }
#else
        return nil
#endif
    }

    func freshToken() async throws -> String {
#if canImport(GoogleSignIn)
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw ServiceError.noCredentials
        }
        try await user.refreshTokensIfNeeded()
        return user.accessToken.tokenString
#else
        throw ServiceError.noCredentials
#endif
    }

    func signOut() {
#if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
#endif
    }

    func handle(_ url: URL) -> Bool {
#if canImport(GoogleSignIn)
        return GIDSignIn.sharedInstance.handle(url)
#else
        return false
#endif
    }

    private func rootViewController() -> UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
