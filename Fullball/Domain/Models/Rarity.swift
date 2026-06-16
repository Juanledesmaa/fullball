import SwiftUI

/// Card rarity tiers, ordered low → high. Base pull weights are the
/// disclosed odds (must match the Odds sheet exactly).
enum Rarity: String, Codable, CaseIterable, Sendable, Comparable {
    case bronze, silver, gold, epic, icon

    /// Disclosed base odds as a fraction of 1.0.
    var baseOdds: Double {
        switch self {
        case .bronze: return 0.70
        case .silver: return 0.22
        case .gold:   return 0.065
        case .epic:   return 0.012
        case .icon:   return 0.003
        }
    }

    var rank: Int { Rarity.allCases.firstIndex(of: self)! }

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        case .epic:   return "Epic"
        case .icon:   return "Icon"
        }
    }

    /// Max star level reachable for a card of this rarity (limit-break cap).
    var starCap: Int {
        switch self {
        case .bronze: return 3
        case .silver: return 4
        case .gold:   return 5
        case .epic:   return 5
        case .icon:   return 5
        }
    }

    /// Accent color used across the UI for this tier.
    var color: Color {
        switch self {
        case .bronze: return Color(hex: 0xA8743A)
        case .silver: return Color(hex: 0x9AA0A6)
        case .gold:   return WC.gold
        case .epic:   return Color(hex: 0x7C3AED)
        case .icon:   return WC.coral
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rank < rhs.rank }
}
