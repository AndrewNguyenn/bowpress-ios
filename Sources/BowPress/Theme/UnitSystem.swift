import Foundation

/// User-selectable unit system for every place the app renders or accepts
/// unit-bearing values. Stored-on-disk values never change — only display
/// and input conversion does.
enum UnitSystem: String, CaseIterable, Identifiable, Codable {
    case imperial
    case metric

    var id: String { rawValue }

    var label: String {
        switch self {
        case .imperial: return "Imperial"
        case .metric:   return "Metric"
        }
    }

    /// AppStorage key shared by every view that reads or writes the preference.
    static let storageKey = "unitSystem"
}
