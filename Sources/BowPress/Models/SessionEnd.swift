import Foundation

struct SessionEnd: Identifiable, Codable, Equatable {
    var id: String
    var sessionId: String
    var endNumber: Int
    var notes: String?
    var completedAt: Date
}
