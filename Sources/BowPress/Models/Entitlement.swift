import Foundation

struct Entitlement: Codable, Equatable {
    var isActive: Bool
    var inTrial: Bool
    var provider: String?      // "apple" | "google"
    var productId: String?
    var expiresAt: Date?
    var autoRenew: Bool
}

extension Entitlement {
    static let inactive = Entitlement(
        isActive: false,
        inTrial: false,
        provider: nil,
        productId: nil,
        expiresAt: nil,
        autoRenew: false
    )
}
