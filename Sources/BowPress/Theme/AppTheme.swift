import SwiftUI

#if canImport(UIKit)
import UIKit
import CoreText
#endif

// MARK: - Brand Colors (Kenrokuen)
//
// Tokens mirror the design system's `colors_and_type.css` (day) and
// `colors_and_type.dark.css` ("Yofuke" — late night, sumi-ink lacquer with a
// cool-green undertone). Each token is a trait-adaptive Color backed by a
// dynamic UIColor, so every existing `Color.appPaper`-style callsite picks up
// the right stratum from the active UITraitCollection without code changes.
//
// Dark is a re-authored variant, not a flat invert: warm "kami" type, lifted
// pond/pine/moss, maple kept warm so alerts still feel like alerts, and the
// World Archery scoring colors stay canonical. Hairlines still replace
// shadows; cards are still rectangles; Fraunces is still italic in display.

#if canImport(UIKit)
private func hexUI(_ hex: String, _ a: Double = 1) -> UIColor {
    var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    let r = CGFloat((rgb >> 16) & 0xFF) / 255
    let g = CGFloat((rgb >>  8) & 0xFF) / 255
    let b = CGFloat( rgb        & 0xFF) / 255
    return UIColor(red: r, green: g, blue: b, alpha: CGFloat(a))
}
#endif

/// Trait-adaptive Color from a light/dark hex pair.
private func bpDynamic(light: String, dark: String, lightAlpha: Double = 1, darkAlpha: Double = 1) -> Color {
    #if canImport(UIKit)
    let ui = UIColor { trait in
        trait.userInterfaceStyle == .dark
            ? hexUI(dark, darkAlpha)
            : hexUI(light, lightAlpha)
    }
    return Color(ui)
    #else
    return bpFallback(light, lightAlpha)
    #endif
}

/// Constant Color across themes — used for World Archery scoring rings,
/// which are canonical and never reskinned.
private func bpConstant(_ hex: String, _ a: Double = 1) -> Color {
    #if canImport(UIKit)
    return Color(hexUI(hex, a))
    #else
    return bpFallback(hex, a)
    #endif
}

#if !canImport(UIKit)
private func bpFallback(_ hex: String, _ a: Double) -> Color {
    var h = hex.trimmingCharacters(in: .init(charactersIn: "#"))
    if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
    var rgb: UInt64 = 0
    Scanner(string: h).scanHexInt64(&rgb)
    let r = Double((rgb >> 16) & 0xFF) / 255
    let g = Double((rgb >>  8) & 0xFF) / 255
    let b = Double( rgb        & 0xFF) / 255
    return Color(red: r, green: g, blue: b, opacity: a)
}
#endif

extension Color {
    // ── Surfaces (paper → sumi lacquer) ───────────────────
    static let appPaper   = bpDynamic(light: "#eef2ec", dark: "#161b19")
    static let appPaper2  = bpDynamic(light: "#e4ebe3", dark: "#1c2220")
    static let appCream   = bpDynamic(light: "#f6f8f3", dark: "#232a27")

    // ── Ink (lacquer black → moonlit "kami" paper-white) ──
    static let appInk     = bpDynamic(light: "#1f2a26", dark: "#e7ebe4")
    static let appInk2    = bpDynamic(light: "#4a5752", dark: "#a4ada7")
    static let appInk3    = bpDynamic(light: "#8a9690", dark: "#6e7872")

    static let appLine    = bpDynamic(light: "#c7d2c9", dark: "#2d352f")
    static let appLine2   = bpDynamic(light: "#d9e1d8", dark: "#242a26")

    // ── Brand accents (pond water → moonlit pond) ─────────
    // pond-dk inverts direction in dark: "heavier" reads as lighter on sumi.
    static let appPond    = bpDynamic(light: "#4a7989", dark: "#79aabc")
    static let appPondDk  = bpDynamic(light: "#2d5a6b", dark: "#a3c8d6")
    static let appPondLt  = bpDynamic(light: "#8fb3bf", dark: "#3a5663")
    static let appDeep    = bpDynamic(light: "#1e3e4a", dark: "#c4dde4")

    static let appMoss    = bpDynamic(light: "#6d8551", dark: "#94ad7c")
    /// Pale moss — the "short" rung of the calendar heatmap. Needs a dark
    /// variant or the ramp inverts (a hardcoded pale tone reads brighter
    /// than the lifted appMoss/appPine on a sumi background).
    static let appMossLt  = bpDynamic(light: "#bfd3ab", dark: "#5e7349")
    static let appPine    = bpDynamic(light: "#4a5f3a", dark: "#a8c08a")
    // Maple stays warm in both themes so alerts feel like alerts.
    static let appMaple   = bpDynamic(light: "#b5614a", dark: "#d97a5e")
    static let appStone   = bpDynamic(light: "#9aa3a0", dark: "#8e9893")

    // ── Target face — real World Archery colors ───────────
    // The 3–10 rings come from World Archery and are NEVER reskinned. The
    // outer white ring is the single bend in dark: it re-tones to moonlit
    // cream so it doesn't punch a glaring hole in a sumi UI.
    static let appTgtWhite  = bpDynamic(light: "#f6f8f3", dark: "#d8dccf")
    static let appTgtBlack  = bpConstant("#1f2a26")
    static let appTgtBlue   = bpConstant("#4ea8c9")
    static let appTgtRed    = bpConstant("#d94b3b")
    static let appTgtYellow = bpConstant("#f0d04a")

    // ── WA score-bar palette ──────────────────────────────
    // Slightly desaturated WA ring colors for per-arrow bars / score chips.
    // Constant across themes — these are data tints, not chrome.
    static let appWAWhiteFill = bpConstant("#f4f1ea")
    static let appWAWhiteEdge = bpConstant("#b8b2a4")
    static let appWABlackFill = bpConstant("#2a2a28")
    static let appWABlackEdge = bpConstant("#1a1a18")
    static let appWABlueFill  = bpConstant("#3a6f8a")
    static let appWABlueEdge  = bpConstant("#1e3e4a")
    static let appWARedFill   = bpConstant("#b04a3a")
    static let appWARedEdge   = bpConstant("#7a2f24")
    static let appWAGoldFill  = bpConstant("#d8a23a")
    static let appWAGoldEdge  = bpConstant("#9a6f1a")

    // ── Semantic status ───────────────────────────────────
    static let appSuccess = Color.appPine
    static let appWarning = Color.appMaple
    static let appDanger  = bpDynamic(light: "#a0392a", dark: "#e08266")
    static let appInfo    = Color.appPond

    // ── Backward-compat aliases ───────────────────────────
    static let appBackground    = Color.appPaper
    static let appSurface       = Color.appPaper
    static let appSurface2      = Color.appCream
    static let appBorder        = Color.appLine
    static let appBorderStrong  = bpDynamic(light: "#a7b6ab", dark: "#3d4640")

    static let appText          = Color.appInk2
    static let appTextPrimary   = Color.appInk
    static let appTextSecondary = Color.appInk2
    static let appTextTertiary  = Color.appInk3

    static let appAccent       = Color.appPond
    static let appAccentInk    = Color.appPondDk
    static let appAccentAlt    = Color.appMoss
    // dark.css overrides: rgba(121,170,188,0.28) and rgba(121,170,188,0.10)
    static let appAccentSubtle = bpDynamic(light: "#000000", dark: "#79aabc",
                                            lightAlpha: 0.24, darkAlpha: 0.28)
    static let appAccentWash   = bpDynamic(light: "#4a7989", dark: "#79aabc",
                                            lightAlpha: 0.08, darkAlpha: 0.10)

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

    /// Eyebrow micro-label (11pt). Callers apply `.tracking(size * 0.22)`
    /// and `.textCase(.uppercase)`.
    static func bpEyebrow(_ size: CGFloat = 11) -> Font {
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
