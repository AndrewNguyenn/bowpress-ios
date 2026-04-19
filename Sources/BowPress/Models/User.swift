import Foundation

enum AuthProvider: String, Codable, Equatable {
    case email
    case apple
    case google
}

struct User: Identifiable, Codable, Equatable {
    var id: String
    var email: String
    var name: String
    var createdAt: Date
    var emailVerified: Bool?
    var authProvider: AuthProvider?

    /// Password-based accounts own a password; social accounts don't.
    /// Missing value is treated as email for backward compatibility with older cached responses.
    var canChangePassword: Bool {
        authProvider == nil || authProvider == .email
    }
}
