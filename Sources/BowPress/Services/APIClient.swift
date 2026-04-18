import Foundation

// MARK: - Period Comparison Models

struct PeriodSlice: Codable {
    let label: String
    let plots: [ArrowPlot]
    let avgArrowScore: Double
    let xPercentage: Double
    let sessionCount: Int
    let config: BowConfiguration?   // dominant config active during this period
}

struct PeriodComparison: Codable {
    let period: AnalyticsPeriod
    let current: PeriodSlice
    let previous: PeriodSlice
}

// MARK: - APIClient

final class APIClient {
    static let shared = APIClient()
    private let baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8787"
    private var authToken: String?

    func setToken(_ token: String) { self.authToken = token }

    // MARK: - Auth
    func signInWithApple(identityToken: String) async throws -> User { fatalError("stub") }
    func signInWithGoogle(idToken: String) async throws -> User { fatalError("stub") }
    func signUp(name: String, email: String, password: String) async throws -> User { fatalError("stub") }
    func signIn(email: String, password: String) async throws -> User { fatalError("stub") }

    // MARK: - Bows
    func fetchBows() async throws -> [Bow] {
        #if DEBUG
        return DevMockData.bows
        #else
        return []
        #endif
    }
    func createBow(_ bow: Bow) async throws -> Bow { bow }
    func deleteBow(id: String) async throws {}

    // MARK: - Bow Configurations
    func fetchConfigurations(bowId: String) async throws -> [BowConfiguration] {
        #if DEBUG
        return DevMockData.bowConfigs(for: bowId)
        #else
        return []
        #endif
    }
    func createConfiguration(_ config: BowConfiguration) async throws -> BowConfiguration { config }

    // MARK: - Arrow Configurations
    func fetchArrowConfigs() async throws -> [ArrowConfiguration] {
        #if DEBUG
        return DevMockData.arrowConfigs
        #else
        return []
        #endif
    }
    func createArrowConfig(_ config: ArrowConfiguration) async throws -> ArrowConfiguration { config }
    func deleteArrowConfig(id: String) async throws {}

    // MARK: - Sessions
    func createSession(_ session: ShootingSession) async throws -> ShootingSession { session }
    func endSession(id: String, notes: String) async throws {}
    func plotArrow(_ plot: ArrowPlot) async throws -> ArrowPlot { plot }
    func completeEnd(_ end: SessionEnd) async throws -> SessionEnd { end }

    // MARK: - Analytics
    func fetchSuggestions() async throws -> [AnalyticsSuggestion] {
        #if DEBUG
        return DevMockData.suggestions()
        #else
        return []
        #endif
    }
    func markSuggestionRead(id: String) async throws {}
    func fetchAnalyticsOverview(period: AnalyticsPeriod) async throws -> AnalyticsOverview {
        #if DEBUG
        return DevMockData.overview(period: period)
        #else
        return AnalyticsOverview(period: period, sessionCount: 0, avgArrowScore: 0, xPercentage: 0, suggestions: [])
        #endif
    }

    func fetchComparison(period: AnalyticsPeriod) async throws -> PeriodComparison {
        #if DEBUG
        return DevMockData.comparison(period: period)
        #else
        // TODO: real API call
        throw URLError(.unsupportedURL)
        #endif
    }
}

enum AnalyticsPeriod: String, Codable, CaseIterable {
    case threeDays   = "3d"
    case week        = "7d"
    case twoWeeks    = "14d"
    case month       = "30d"
    case threeMonths = "90d"
    case sixMonths   = "180d"
    case year        = "365d"

    var label: String {
        switch self {
        case .threeDays:   "3 Days"
        case .week:        "1 Week"
        case .twoWeeks:    "2 Weeks"
        case .month:       "1 Month"
        case .threeMonths: "3 Months"
        case .sixMonths:   "6 Months"
        case .year:        "1 Year"
        }
    }
}

struct AnalyticsOverview: Codable {
    var period: AnalyticsPeriod
    var sessionCount: Int
    var avgArrowScore: Double   // 6–11 scale; X = 11
    var xPercentage: Double     // 0–100, % of arrows hitting X (ring 11)
    var suggestions: [AnalyticsSuggestion]
}
