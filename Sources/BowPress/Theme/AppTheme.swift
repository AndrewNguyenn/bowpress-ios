import SwiftUI

// MARK: - Brand Colors
//
// Tokens mirror bowpress-design-system/project/colors_and_type.css so the
// iOS surface and any web/prototype surface stay in lockstep.

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

private func dynamic(light: String, dark: String) -> Color {
    Color(UIColor { t in
        t.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
    })
}

private func dynamic(light: UIColor, dark: UIColor) -> Color {
    Color(UIColor { t in t.userInterfaceStyle == .dark ? dark : light })
}

extension Color {
    // Neutrals / surfaces
    static let appBackground   = dynamic(light: "#f5f5f5", dark: "#1c1c1c")
    static let appSurface      = dynamic(light: "#f3f4f6", dark: "#1f2937")
    static let appSurface2     = dynamic(light: "#ffffff", dark: "#111827")
    static let appBorder       = dynamic(light: "#e5e7eb", dark: "#374151")
    static let appBorderStrong = dynamic(light: "#d1d5db", dark: "#4b5563")

    // Text
    static let appText          = dynamic(light: "#374151", dark: "#9ca3af")
    static let appTextPrimary   = dynamic(light: "#111827", dark: "#f3f4f6")
    static let appTextSecondary = dynamic(light: "#6b7280", dark: "#9ca3af")
    static let appTextTertiary  = dynamic(light: "#9ca3af", dark: "#6b7280")

    // Brand accents
    static let appAccent    = dynamic(light: "#4d7c5e", dark: "#7dd4a0")
    static let appAccentInk = dynamic(light: "#2f5a3d", dark: "#4ade80")
    static let appAccentAlt = Color(UIColor(hex: "#2a9d8f"))
    static let appAccentSubtle = dynamic(
        light: UIColor(hex: "#4d7c5e").withAlphaComponent(0.35),
        dark:  UIColor(hex: "#7dd4a0").withAlphaComponent(0.15)
    )
    static let appAccentWash = dynamic(
        light: UIColor(hex: "#4d7c5e").withAlphaComponent(0.10),
        dark:  UIColor(hex: "#7dd4a0").withAlphaComponent(0.10)
    )

    // Target / scoring palette — flat across light + dark (data, not chrome)
    static let appTargetGold   = Color(UIColor(hex: "#ffd900"))
    static let appTargetYellow = Color(UIColor(hex: "#fff233"))
    static let appTargetRed    = Color(UIColor(hex: "#e04738"))
    static let appTargetBlue   = Color(UIColor(hex: "#00bae3"))
    static let appTargetBlack  = Color(UIColor(hex: "#1a1a1a"))
    static let appTargetWhite  = Color(UIColor(hex: "#fafaf2"))
    static let appTargetInk    = Color(UIColor(hex: "#1f2937"))

    // Semantic status
    static let appSuccess = Color.appAccent
    static let appWarning = Color(UIColor(hex: "#f59e0b"))
    static let appDanger  = Color(UIColor(hex: "#dc2626"))
    static let appInfo    = Color.appAccentAlt
}

#else

// macOS fallback — light-mode static values (app is iOS-primary)
extension Color {
    static let appBackground   = Color(red: 0.961, green: 0.961, blue: 0.961)
    static let appSurface      = Color(red: 0.953, green: 0.957, blue: 0.965)
    static let appSurface2     = Color.white
    static let appBorder       = Color(red: 0.898, green: 0.906, blue: 0.918)
    static let appBorderStrong = Color(red: 0.820, green: 0.835, blue: 0.859)

    static let appText          = Color(red: 0.216, green: 0.255, blue: 0.318)
    static let appTextPrimary   = Color(red: 0.067, green: 0.094, blue: 0.153)
    static let appTextSecondary = Color(red: 0.420, green: 0.447, blue: 0.502)
    static let appTextTertiary  = Color(red: 0.612, green: 0.639, blue: 0.686)

    static let appAccent    = Color(red: 0.302, green: 0.486, blue: 0.369)
    static let appAccentInk = Color(red: 0.184, green: 0.353, blue: 0.239)
    static let appAccentAlt = Color(red: 0.165, green: 0.616, blue: 0.561)
    static let appAccentSubtle = Color(red: 0.302, green: 0.486, blue: 0.369, opacity: 0.35)
    static let appAccentWash   = Color(red: 0.302, green: 0.486, blue: 0.369, opacity: 0.10)

    static let appTargetGold   = Color(red: 1.0,   green: 0.851, blue: 0.0)
    static let appTargetYellow = Color(red: 1.0,   green: 0.949, blue: 0.2)
    static let appTargetRed    = Color(red: 0.878, green: 0.278, blue: 0.22)
    static let appTargetBlue   = Color(red: 0.0,   green: 0.729, blue: 0.890)
    static let appTargetBlack  = Color(red: 0.102, green: 0.102, blue: 0.102)
    static let appTargetWhite  = Color(red: 0.980, green: 0.980, blue: 0.949)
    static let appTargetInk    = Color(red: 0.122, green: 0.161, blue: 0.216)

    static let appSuccess = Color.appAccent
    static let appWarning = Color(red: 0.961, green: 0.620, blue: 0.043)
    static let appDanger  = Color(red: 0.863, green: 0.149, blue: 0.149)
    static let appInfo    = Color.appAccentAlt
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
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 24
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    /// Elevation tokens — radius/y values mirror the CSS blur/offset from
    /// `--shadow-*` so on-device shadows match the prototype 1:1.
    enum Shadow {
        struct Params {
            let opacity: Double
            let radius: CGFloat
            let y: CGFloat
        }
        static let sm      = Params(opacity: 0.04, radius: 2, y: 1)
        static let md      = Params(opacity: 0.08, radius: 8, y: 4)
        static let lg      = Params(opacity: 0.12, radius: 24, y: 8)
        static let card    = Params(opacity: 0.08, radius: 8, y: 4)
        static let cardSm  = Params(opacity: 0.07, radius: 6, y: 3)
    }
}

extension View {
    func appShadow(_ params: AppTheme.Shadow.Params) -> some View {
        shadow(color: .black.opacity(params.opacity),
               radius: params.radius, x: 0, y: params.y)
    }
}

// MARK: - Card Style ViewModifier

struct AppCardStyle: ViewModifier {
    var accent: Color = .appBorder
    var strokeWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .fill(Color.appSurface)
                    .appShadow(AppTheme.Shadow.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppTheme.Radius.card, style: .continuous)
                    .strokeBorder(accent, lineWidth: strokeWidth)
            )
    }
}

extension View {
    func appCardStyle(accent: Color = .appBorder, strokeWidth: CGFloat = 1) -> some View {
        modifier(AppCardStyle(accent: accent, strokeWidth: strokeWidth))
    }
}
