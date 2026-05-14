import SwiftUI

/// User-controlled appearance preference. Persisted via @AppStorage at
/// `ThemePreference.storageKey` and applied at the app root with
/// `.preferredColorScheme(prefs.colorScheme)`.
enum ThemePreference: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "themePreference"

    var id: String { rawValue }

    /// nil = follow the OS (system); .light / .dark = pin.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }

    /// Title Case label for the row value display in Settings.
    var displayLabel: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// Cycle order used by the Settings row tap-to-cycle: System → Light → Dark → System.
    var next: ThemePreference {
        switch self {
        case .system: return .light
        case .light:  return .dark
        case .dark:   return .system
        }
    }
}
