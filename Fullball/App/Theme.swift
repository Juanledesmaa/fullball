import SwiftUI

/// Design tokens lifted from the WC26 Wireframes handoff.
/// Bold black + coral on warm paper, Archivo display type.
enum WC {
    // Core palette (from wc-ui.jsx)
    static let ink = Color(hex: 0x16130F)
    // Adaptive neutrals (light/dark) — keep contrast in both appearances.
    static let sub = Color("SubText")
    static let faint = Color("FaintText")
    static let line = Color("LineColor")
    static let fill = Color("FillBG")
    static let fillD = Color("FillDeep")
    static let card = Color("CardBG")
    static let screen = Color("ScreenBG")
    static let coral = Color(hex: 0xFB4B3E)
    static let coralInk = Color(hex: 0xC9261A)
    static let coralSoft = Color(hex: 0xFFE6E2)
    static let go = Color(hex: 0x2E9E6B)
    static let gold = Color(hex: 0xE9C200)

    // WC2026 brand-inspired spectrum (the retro multicolor stripe motif).
    static let mint   = Color(hex: 0x19C3A6)
    static let lime   = Color(hex: 0x9BD61E)
    static let yellow = Color(hex: 0xF2C500)
    static let orange = Color(hex: 0xF2602B)
    static let blue   = Color(hex: 0x2D4BE0)
    static let purple = Color(hex: 0x7B43E0)
    static let violet = Color(hex: 0xA78BFA)
    static let magenta = Color(hex: 0xE0399E)
    static let sky    = Color(hex: 0x36C5F0)

    /// Ordered spectrum used for stripes, avatar backgrounds and accents.
    static let spectrum: [Color] = [coral, orange, yellow, lime, mint, sky, blue, purple, violet, magenta]

    /// Deterministic spectrum pick from any string (e.g. a nation tag).
    static func spectrumColor(for key: String) -> Color {
        var h: UInt64 = 1469598103934665603
        for b in key.utf8 { h = (h ^ UInt64(b)) &* 1099511628211 }
        return spectrum[Int(h % UInt64(spectrum.count))]
    }

    // Dark-mode aware variants for the paper screen / card / ink so the
    // app reads correctly in both appearances (design was light-only).
    static let screenBG = Color("ScreenBG")
    static let cardBG = Color("CardBG")
    static let inkText = Color("InkText")
    static let lineColor = Color("LineColor")

    // Type families. Archivo isn't bundled; fall back to the system
    // rounded/heavy faces which carry the same bold-display feel.
    static func display(_ size: CGFloat) -> Font { .system(size: size, weight: .black, design: .default) }
    static func ui(_ size: CGFloat, weight: Font.Weight = .regular) -> Font { .system(size: size, weight: weight) }
}

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}
