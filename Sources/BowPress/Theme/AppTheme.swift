import SwiftUI

#if canImport(UIKit)
import UIKit
import CoreText
#endif

// MARK: - Brand Colors (Kenrokuen)
//
// Tokens mirror bowpress-design-system/project/colors_and_type.css verbatim.
// Light-mode only; dark mode deferred per spec. Kenrokuen is quiet by default —
// color is data. Hairlines replace shadows. Cards are rectangles.

private func hex(_ hex: String, _ a: Double = 1) -> Color {
    var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255
    let g = Double((rgb >>  8) & 0xFF) / 255
    let b = Double( rgb        & 0xFF) / 255
    return Color(red: r, green: g, blue: b, opacity: a)
}

extension Color {
    // ── Surfaces (paper) ──────────────────────────────────
    static let appPaper   = hex("#eef2ec")
    static let appPaper2  = hex("#e4ebe3")
    static let appCream   = hex("#f6f8f3")

    // ── Ink (text + hairlines) ────────────────────────────
    static let appInk     = hex("#1f2a26")
    static let appInk2    = hex("#4a5752")
    static let appInk3    = hex("#8a9690")

    static let appLine    = hex("#c7d2c9")
    static let appLine2   = hex("#d9e1d8")

    // ── Brand accents (water + garden) ────────────────────
    static let appPond    = hex("#4a7989")
    static let appPondDk  = hex("#2d5a6b")
    static let appPondLt  = hex("#8fb3bf")
    static let appDeep    = hex("#1e3e4a")

    static let appMoss    = hex("#6d8551")
    static let appPine    = hex("#4a5f3a")
    static let appMaple   = hex("#b5614a")
    static let appStone   = hex("#9aa3a0")

    // ── Target / scoring palette ──────────────────────────
    // Real World Archery face. Never reskinned. Never tinted.
    static let appTgtWhite  = hex("#f6f8f3")
    static let appTgtBlack  = hex("#1f2a26")
    static let appTgtBlue   = hex("#4ea8c9")
    static let appTgtRed    = hex("#d94b3b")
    static let appTgtYellow = hex("#f0d04a")

    // ── Semantic status ───────────────────────────────────
    static let appSuccess = Color.appPine
    static let appWarning = Color.appMaple
    static let appDanger  = hex("#a0392a")
    static let appInfo    = Color.appPond

    // ── Backward-compat aliases (kept so Wave 1 doesn't break
    //    the existing screens that Wave 2 will rewrite). ────
    static let appBackground    = Color.appPaper
    static let appSurface       = Color.appPaper
    static let appSurface2      = Color.appCream
    static let appBorder        = Color.appLine
    static let appBorderStrong  = hex("#a7b6ab")

    static let appText          = Color.appInk2
    static let appTextPrimary   = Color.appInk
    static let appTextSecondary = Color.appInk2
    static let appTextTertiary  = Color.appInk3

    static let appAccent       = Color.appPond
    static let appAccentInk    = Color.appPondDk
    static let appAccentAlt    = Color.appMoss
    // Approximation of rgba(74,121,137,.24) — low-opacity neutral.
    static let appAccentSubtle = Color(white: 0, opacity: 0.24)
    static let appAccentWash   = Color.appPond.opacity(0.08)

    // Old target aliases → map to new appTgt*.
    static let appTargetGold   = Color.appTgtYellow
    static let appTargetYellow = Color.appTgtYellow
    static let appTargetRed    = Color.appTgtRed
    static let appTargetBlue   = Color.appTgtBlue
    static let appTargetBlack  = Color.appTgtBlack
    static let appTargetWhite  = Color.appTgtWhite
    static let appTargetInk    = Color.appInk
}

// MARK: - Design Tokens

enum AppTheme {
    /// Kenrokuen is flat-edged. No rounded cards.
    enum Radius {
        static let sm:   CGFloat = 0
        static let md:   CGFloat = 1    // chips — barely perceptible
        static let lg:   CGFloat = 2
        static let card: CGFloat = 0    // CARDS ARE RECTANGLES
        static let pill: CGFloat = 0    // pills are flat stamps, not capsules

        // Legacy aliases so existing callsites compile.
        static let small:  CGFloat = 0
        static let medium: CGFloat = 1
        static let large:  CGFloat = 2
    }

    /// 8pt grid, tighter overall.
    enum Spacing {
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 14
        static let lg:  CGFloat = 22
        static let xl:  CGFloat = 32
        static let xxl: CGFloat = 48
    }

    /// Elevation tokens — Kenrokuen is flat. Hairlines replace shadows.
    /// Kept here only for the rare third-party surface (modal sheet, toast).
    enum Shadow {
        struct Params {
            let opacity: Double
            let radius: CGFloat
            let y: CGFloat
        }
        static let modalSheet = Params(opacity: 0.25, radius: 30, y: 30)
        static let card       = Params(opacity: 0,    radius: 0,  y: 0)
        static let sm         = Params(opacity: 0,    radius: 0,  y: 0)
        static let md         = Params(opacity: 0,    radius: 0,  y: 0)
        static let lg         = Params(opacity: 0,    radius: 0,  y: 0)
        // Legacy alias.
        static let cardSm     = Params(opacity: 0,    radius: 0,  y: 0)
    }
}

extension View {
    /// Applies a shadow using the given params. For the flat Kenrokuen cards
    /// this is a no-op (opacity 0); the helper survives for `modalSheet`.
    func appShadow(_ params: AppTheme.Shadow.Params) -> some View {
        shadow(color: .black.opacity(params.opacity),
               radius: params.radius, x: 0, y: params.y)
    }
}

// MARK: - Card Style ViewModifier
//
// Signature preserved so existing `.appCardStyle()` callers keep compiling.
// Body rewritten for Kenrokuen — flat rectangle, 1px hairline, no radius,
// no shadow.

struct AppCardStyle: ViewModifier {
    var accent: Color = .appLine
    var strokeWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content
            .background(Color.appPaper)
            .overlay(
                Rectangle().strokeBorder(accent, lineWidth: strokeWidth)
            )
    }
}

extension View {
    func appCardStyle(accent: Color = .appLine, strokeWidth: CGFloat = 1) -> some View {
        modifier(AppCardStyle(accent: accent, strokeWidth: strokeWidth))
    }
}

// MARK: - Typography
//
// Three families, each with a distinct job:
// - Fraunces (serif, italic for display): titles, big numerals, scores
// - Inter (sans): UI, micro-labels (UPPERCASE w/ wide tracking)
// - JetBrains Mono: data, timestamps, telemetry, delta values
//
// Resolution strategy: the Font extensions below try the most common registered
// names. If iOS hasn't registered that name (e.g. font bundle missing or the
// variable-font PostScript name differs), SwiftUI silently falls back to the
// system typeface — which is the same behavior our explicit fallback produces.
// We additionally probe UIFont at runtime to pick a known-registered name.

#if canImport(UIKit)
private func hasFont(_ name: String) -> Bool {
    UIFont(name: name, size: 12) != nil
}

/// 4-char OpenType tag → Int (used for variable-font axis keys).
/// 'opsz' → 0x6F70737A, 'wght' → 0x77676874, etc.
private func axisTag(_ s: StaticString) -> Int {
    var r = 0
    s.withUTF8Buffer { bytes in
        for b in bytes { r = (r << 8) + Int(b) }
    }
    return r
}

/// Fraunces variable font constructor. Sets `opsz` + `wght` axes explicitly
/// so titles get display-italic forms (chunkier glyphs, more character) and
/// body sizes keep text-italic forms (plain, readable). Without this,
/// SwiftUI's `.custom(name:).weight()` uses the font's default axis values
/// — which on the variable build is `opsz=9pt` regardless of render size,
/// matching the CSS fallback `font-optical-sizing: none` and producing
/// uniformly plain italics. The web design uses CSS `auto` (the default),
/// which scales opsz with font size — we mirror that here.
private func frauncesUIFont(size: CGFloat, italic: Bool, weight: Font.Weight) -> UIFont? {
    let candidates: [String] = italic
        ? ["Fraunces-Italic", "Fraunces-9ptBlackItalic", "FrauncesRoman-Italic"]
        : ["Fraunces", "Fraunces-9ptBlack", "FrauncesRoman-Regular"]
    guard let name = candidates.first(where: hasFont),
          let base = UIFont(name: name, size: size) else { return nil }
    let wghtValue: CGFloat
    switch weight {
    case .ultraLight: wghtValue = 100
    case .thin:       wghtValue = 200
    case .light:      wghtValue = 300
    case .regular:    wghtValue = 400
    case .medium:     wghtValue = 500
    case .semibold:   wghtValue = 600
    case .bold:       wghtValue = 700
    case .heavy:      wghtValue = 800
    case .black:      wghtValue = 900
    default:          wghtValue = 500
    }
    // opsz axis is 9…144 per the Fraunces build. We mirror CSS auto-opsz:
    // optical size tracks the render size so display-sized text gets the
    // display glyphs (more stroke contrast, more pronounced italic forms).
    // Clamp to the font's supported range.
    let opszValue = min(max(size, 9), 144)
    let variationKey = UIFontDescriptor.AttributeName(
        rawValue: kCTFontVariationAttribute as String
    )
    let descriptor = base.fontDescriptor.addingAttributes([
        variationKey: [
            axisTag("opsz"): opszValue,
            axisTag("wght"): wghtValue,
        ],
    ])
    return UIFont(descriptor: descriptor, size: size)
}
#else
private func hasFont(_ name: String) -> Bool { false }
#endif

/// Resolves the first registered PostScript/family name from `candidates`,
/// returning nil if none are registered.
private func firstRegistered(_ candidates: [String]) -> String? {
    candidates.first(where: hasFont)
}

extension Font {
    /// Fraunces serif — display type. Italic by default (per spec; hero
    /// numerals pass `italic: false` so they render upright).
    ///
    /// Sets the `opsz` variable-axis so display-sized titles render with the
    /// chunky, higher-character display italic forms (matching CSS `auto`
    /// optical sizing in the web prototype), not the plain text-italic
    /// forms you get from the variable font's default `opsz=9` axis value.
    static func bpDisplay(_ size: CGFloat, italic: Bool = true, weight: Font.Weight = .medium) -> Font {
        #if canImport(UIKit)
        if let ui = frauncesUIFont(size: size, italic: italic, weight: weight) {
            return Font(ui)
        }
        #endif
        return .system(size: size, weight: weight, design: .serif)
    }

    /// Inter sans — UI, labels, body.
    static func bpUI(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let candidates = ["Inter", "InterVariable", "Inter-Regular"]
        if let n = firstRegistered(candidates) {
            return .custom(n, size: size).weight(weight)
        }
        return .system(size: size, weight: weight, design: .default)
    }

    /// JetBrains Mono — telemetry.
    static func bpMono(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let base: String
        switch weight {
        case .medium, .semibold, .bold, .heavy, .black:
            base = "JetBrainsMono-Medium"
        default:
            base = "JetBrainsMono-Regular"
        }
        if hasFont(base) {
            return .custom(base, size: size)
        }
        return .system(size: size, weight: weight, design: .monospaced)
    }

    /// Uppercase-label style (11pt by default). Callers apply `.tracking`
    /// and `.textCase(.uppercase)` themselves via `appTracking` + textCase.
    static func bpLabel(_ size: CGFloat = 11) -> Font {
        bpUI(size, weight: .semibold)
    }

    /// Eyebrow micro-label (9pt). Callers apply `.tracking(size * 0.22)`
    /// and `.textCase(.uppercase)`.
    static func bpEyebrow(_ size: CGFloat = 9) -> Font {
        bpUI(size, weight: .semibold)
    }
}

extension View {
    /// Applies CSS-style letter-spacing expressed in em. For example,
    /// `letter-spacing: 0.22em` at font-size 11pt is `tracking(11 * 0.22)`.
    func appTracking(_ em: CGFloat, at fontSize: CGFloat) -> some View {
        self.tracking(em * fontSize)
    }
}
