import UIKit
import GoogleSignIn
import Observation

/// Thin wrapper around the Google Sign-In SDK.
/// Owns the SDK interaction only — routing decisions live in AppStateManager.
@Observable
class AuthenticationManager {
    var isLoading: Bool = false

    // Google user info — populated after a successful sign-in.
    var userName: String = ""
    var userEmail: String = ""
    var googleSub: String = ""
    var userProfileImageURL: URL?

    // MARK: - Async Google Sign-In

    /// Presents the Google Sign-In sheet and returns the ID token on success.
    /// Throws AuthError.canceled if the user dismisses the sheet.
    func getGoogleIDToken() async throws -> String {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            throw AuthError.noViewController
        }

        return try await withCheckedThrowingContinuation { continuation in
            isLoading = true
            GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController) { [weak self] result, error in
                DispatchQueue.main.async {
                    self?.isLoading = false

                    if let error = error {
                        if (error as NSError).code == GIDSignInError.canceled.rawValue {
                            continuation.resume(throwing: AuthError.canceled)
                        } else {
                            continuation.resume(throwing: error)
                        }
                        return
                    }

                    guard let user = result?.user,
                          let idToken = user.idToken?.tokenString else {
                        continuation.resume(throwing: AuthError.noIDToken)
                        return
                    }

                    self?.updateUserInfo(from: user)
                    continuation.resume(returning: idToken)
                }
            }
        }
    }

    // MARK: - Sign Out

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        userName = ""
        userEmail = ""
        googleSub = ""
        userProfileImageURL = nil
    }

    // MARK: - Private Helpers

    private func updateUserInfo(from user: GIDGoogleUser) {
        userName = user.profile?.name ?? ""
        userEmail = user.profile?.email ?? ""
        googleSub = user.userID ?? ""
        userProfileImageURL = user.profile?.imageURL(withDimension: 200)
    }

    // MARK: - Errors

    enum AuthError: LocalizedError {
        case noViewController
        case canceled
        case noIDToken

        var errorDescription: String? {
            switch self {
            case .noViewController: return "Could not find a view controller to present sign-in."
            case .canceled: return "Sign-in was cancelled."
            case .noIDToken: return "Google did not return an ID token."
            }
        }
    }
}
