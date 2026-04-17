import Foundation

struct User: Identifiable, Codable, Equatable {
    var id: String
    var email: String
    var name: String
    var createdAt: Date
}
