import Foundation
import Observation

@Observable
final class AppState {
    #if DEBUG
    var isAuthenticated: Bool = true
    var currentUser: User? = User(id: "dev", email: "dev@bowpress.app", name: "Dev Archer", createdAt: Date())
    #else
    var isAuthenticated: Bool = false
    var currentUser: User?
    #endif
    var pendingVerificationEmail: String? = nil
    #if DEBUG
    var bows: [Bow] = DevMockData.bows
    var arrowConfigs: [ArrowConfiguration] = DevMockData.arrowConfigs
    var unreadSuggestionCount: Int = DevMockData.suggestions().filter { !$0.wasRead }.count
    #else
    var bows: [Bow] = []
    var arrowConfigs: [ArrowConfiguration] = []
    var unreadSuggestionCount: Int = 0
    #endif
}
