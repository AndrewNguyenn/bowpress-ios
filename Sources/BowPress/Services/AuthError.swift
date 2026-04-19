import Foundation

enum AuthError: Error, Equatable {
    case emailNotVerified(email: String)
    case invalidCode(attemptsRemaining: Int)
    case codeExpired
    case tooManyAttempts
}

extension AuthError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .emailNotVerified:
            return "Please verify your email to continue."
        case .invalidCode(let attemptsRemaining):
            return "Invalid code. \(attemptsRemaining) attempt\(attemptsRemaining == 1 ? "" : "s") remaining."
        case .codeExpired:
            return "Your verification code expired. Tap Resend to get a new one."
        case .tooManyAttempts:
            return "Too many incorrect attempts. Tap Resend to get a new code."
        }
    }
}
