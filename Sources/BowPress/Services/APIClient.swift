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

// MARK: - Auth response shapes

struct SignUpResult: Equatable {
    let email: String
}

private struct SignUpResponseBody: Decodable {
    let status: String
    let email: String
}

private struct AuthSuccessBody: Decodable {
    let user: User
    let token: String
}

private struct ErrorBody: Decodable {
    let error: String?
    let email: String?
    let attemptsRemaining: Int?
}

// MARK: - Protocol

protocol BowPressAPIClient: AnyObject {
    func setToken(_ token: String)
    func signInWithApple(identityToken: String) async throws -> User
    func signInWithGoogle(idToken: String) async throws -> User
    func signUp(name: String, email: String, password: String) async throws -> SignUpResult
    func signIn(email: String, password: String) async throws -> User
    func verifyEmail(email: String, code: String) async throws -> User
    func resendVerification(email: String) async throws

    // Bows
    func fetchBows() async throws -> [Bow]
    func createBow(_ bow: Bow) async throws -> Bow
    func deleteBow(id: String) async throws

    // Bow Configurations
    func fetchConfigurations(bowId: String) async throws -> [BowConfiguration]
    func createConfiguration(_ config: BowConfiguration) async throws -> BowConfiguration

    // Arrow Configurations
    func fetchArrowConfigs() async throws -> [ArrowConfiguration]
    func createArrowConfig(_ config: ArrowConfiguration) async throws -> ArrowConfiguration
    func deleteArrowConfig(id: String) async throws

    // Sessions
    func fetchSessions() async throws -> [ShootingSession]
    func createSession(_ session: ShootingSession) async throws -> ShootingSession
    func endSession(id: String, notes: String) async throws
    func fetchPlots(sessionId: String) async throws -> [ArrowPlot]
    func plotArrow(_ plot: ArrowPlot) async throws -> ArrowPlot
    func completeEnd(_ end: SessionEnd) async throws -> SessionEnd
}

// MARK: - APIClient

final class APIClient: BowPressAPIClient {
    static let shared = APIClient()
    private let baseURL = ProcessInfo.processInfo.environment["API_BASE_URL"] ?? "http://localhost:8787"
    private var authToken: String?
    private let session: URLSession
    private let decoder: JSONDecoder

    init(session: URLSession = .shared) {
        self.session = session
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    func setToken(_ token: String) { self.authToken = token }
    var hasToken: Bool { authToken != nil }

    // MARK: - Auth
    func signInWithApple(identityToken: String) async throws -> User { fatalError("stub") }
    func signInWithGoogle(idToken: String) async throws -> User { fatalError("stub") }

    func signUp(name: String, email: String, password: String) async throws -> SignUpResult {
        let body: [String: String] = ["name": name, "email": email, "password": password]
        let (data, response) = try await post(path: "/auth/signup", body: body)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if http.statusCode == 202 {
            let decoded = try decoder.decode(SignUpResponseBody.self, from: data)
            return SignUpResult(email: decoded.email)
        }
        throw try authError(from: data, status: http.statusCode)
    }

    func signIn(email: String, password: String) async throws -> User {
        let body: [String: String] = ["email": email, "password": password]
        let (data, response) = try await post(path: "/auth/signin", body: body)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if (200..<300).contains(http.statusCode) {
            let decoded = try decoder.decode(AuthSuccessBody.self, from: data)
            setToken(decoded.token)
            return decoded.user
        }
        if http.statusCode == 403, let body = try? decoder.decode(ErrorBody.self, from: data),
           body.error == "email_not_verified", let echoed = body.email {
            throw AuthError.emailNotVerified(email: echoed)
        }
        throw try authError(from: data, status: http.statusCode)
    }

    func verifyEmail(email: String, code: String) async throws -> User {
        let body: [String: String] = ["email": email, "code": code]
        let (data, response) = try await post(path: "/auth/verify-email", body: body)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if (200..<300).contains(http.statusCode) {
            let decoded = try decoder.decode(AuthSuccessBody.self, from: data)
            setToken(decoded.token)
            return decoded.user
        }
        throw try verifyEmailError(from: data, status: http.statusCode)
    }

    func resendVerification(email: String) async throws {
        let body: [String: String] = ["email": email]
        let (data, response) = try await post(path: "/auth/resend-verification", body: body)
        guard let http = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        if (200..<300).contains(http.statusCode) { return }
        throw try authError(from: data, status: http.statusCode)
    }

    // MARK: - HTTP helpers

    private func post(path: String, body: [String: String]) async throws -> (Data, URLResponse) {
        guard let url = URL(string: baseURL + path) else { throw URLError(.badURL) }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let token = authToken {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return try await session.data(for: request)
    }

    private func authError(from data: Data, status: Int) throws -> Error {
        if let body = try? decoder.decode(ErrorBody.self, from: data), let code = body.error {
            return NSError(domain: "APIClient", code: status, userInfo: [NSLocalizedDescriptionKey: code])
        }
        return NSError(domain: "APIClient", code: status, userInfo: [NSLocalizedDescriptionKey: "HTTP \(status)"])
    }

    private func verifyEmailError(from data: Data, status: Int) throws -> Error {
        let body = try? decoder.decode(ErrorBody.self, from: data)
        switch (status, body?.error) {
        case (401, "invalid_code"):
            return AuthError.invalidCode(attemptsRemaining: body?.attemptsRemaining ?? 0)
        case (410, "verification_expired"):
            return AuthError.codeExpired
        case (429, "too_many_attempts"):
            return AuthError.tooManyAttempts
        default:
            return try authError(from: data, status: status)
        }
    }

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
    func fetchSessions() async throws -> [ShootingSession] {
        #if DEBUG
        return DevMockData.bows.flatMap { DevMockData.sessions(for: $0.id) }
        #else
        return []
        #endif
    }
    func createSession(_ session: ShootingSession) async throws -> ShootingSession { session }
    func endSession(id: String, notes: String) async throws {}
    func fetchPlots(sessionId: String) async throws -> [ArrowPlot] { [] }
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
