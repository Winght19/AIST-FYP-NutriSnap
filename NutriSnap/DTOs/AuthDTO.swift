import Foundation

/// Sent to the backend to exchange a Google ID token for an app JWT.
struct AuthRequestDTO: Codable {
    let idToken: String
}

/// Returned by the backend after a successful Google token exchange.
struct AuthResponseDTO: Codable {
    /// The app's own JWT — stored in Keychain for all subsequent requests.
    let jwt: String
    /// True when this is the first time the Google account has signed in.
    let isNewUser: Bool
    /// The user's profile, included for existing users so we can skip a second fetch.
    let profile: UserProfileDTO?
}
