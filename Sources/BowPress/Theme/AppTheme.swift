import SwiftUI

// MARK: - Brand Colors

#if canImport(UIKit)
import UIKit

private extension UIColor {
    convenience init(hex: String) {
        var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
        if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
        var rgb: UInt64 = 0
        Scanner(string: h).scanHexInt64(&rgb)
        let r = CGFloat((rgb >> 16) & 0xFF) / 255
        let g = CGFloat((rgb >>  8) & 0xFF) / 255
        let b = CGFloat( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// Page/screen background — anduwu.dev --bg
    static let appBackground = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "#1c1c1c") : UIColor(hex: "#f5f5f5")
    })
    /// Card / elevated surface — anduwu.dev --code-bg / --social-bg base
    static let appSurface = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "#1f2937") : UIColor(hex: "#f3f4f6")
    })
    /// Body text — anduwu.dev --text
    static let appText = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "#9ca3af") : UIColor(hex: "#374151")
    })
    /// Heading / primary text — anduwu.dev --text-h
    static let appTextPrimary = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "#f3f4f6") : UIColor(hex: "#111827")
    })
    /// Primary brand accent (forest green) — anduwu.dev --accent
    static let appAccent = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "#7dd4a0") : UIColor(hex: "#4d7c5e")
    })
    /// Secondary accent (teal) — anduwu.dev --accent-alt
    static let appAccentAlt = Color(UIColor { _ in UIColor(hex: "#2a9d8f") })
    /// Subtle accent fill — anduwu.dev --accent-bg
    static let appAccentSubtle = Color(UIColor { t in
        t.userInterfaceStyle == .dark
            ? UIColor(hex: "#7dd4a0").withAlphaComponent(0.15)
            : UIColor(hex: "#4d7c5e").withAlphaComponent(0.35)
    })
    /// Dividers and strokes — anduwu.dev --border
    static let appBorder = Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: "#374151") : UIColor(hex: "#e5e7eb")
    })
}

#else

// macOS fallback — light-mode static colors (app is iOS-primary)
extension Color {
    static let appBackground  = Color(red: 0.961, green: 0.961, blue: 0.961)
    static let appSurface     = Color(red: 0.953, green: 0.957, blue: 0.965)
    static let appText        = Color(red: 0.216, green: 0.255, blue: 0.318)
    static let appTextPrimary = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let appAccent      = Color(red: 0.302, green: 0.486, blue: 0.369)
    static let appAccentAlt   = Color(red: 0.165, green: 0.616, blue: 0.561)
    static let appAccentSubtle = Color(red: 0.302, green: 0.486, blue: 0.369, opacity: 0.35)
    static let appBorder      = Color(red: 0.898, green: 0.906, blue: 0.918)
}

#endif

// MARK: - Design Tokens

enum AppTheme {
    enum Radius {
        static let small:  CGFloat = 4
        static let medium: CGFloat = 8
        static let large:  CGFloat = 14
        static let card:   CGFloat = 18
        static let pill:   CGFloat = 999
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
    }
}

// MARK: - Card Style ViewModifier

struct AppCardStyle: ViewModifier {
    var accent: Color = .appBorder

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(Color.appSurface)
                    .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(accent, lineWidth: 1)
            )
    }
}

extension View {
    func appCardStyle(accent: Color = .appBorder) -> some View {
        modifier(AppCardStyle(accent: accent))
    }
}
