import Foundation

struct Bow: Identifiable, Codable, Equatable {
    var id: String
    var userId: String
    var name: String
    var brand: String
    var model: String
    var createdAt: Date
}
