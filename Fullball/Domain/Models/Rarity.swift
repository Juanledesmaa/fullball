import SwiftUI

/// Card rarity tiers, ordered low → high. Base pull weights are the
/// disclosed odds (must match the Odds sheet exactly).
enum Rarity: String, Codable, CaseIterable, Sendable, Comparable {
    case bronze, silver, gold, icon

    /// Disclosed base odds (sum = 1.0); must match the Odds sheet.
    var baseOdds: Double {
        switch self {
        case .bronze: return 0.70
        case .silver: return 0.22
        case .gold:   return 0.073
        case .icon:   return 0.007
        }
    }

    var rank: Int { Rarity.allCases.firstIndex(of: self)! }

    var displayName: String {
        switch self {
        case .bronze: return "Bronze"
        case .silver: return "Silver"
        case .gold:   return "Gold"
        case .icon:   return "Icon"
        }
    }

    /// Max star level (limit-break cap).
    var starCap: Int {
        switch self {
        case .bronze: return 3
        case .silver: return 4
        case .gold:   return 5
        case .icon:   return 5
        }
    }

    var color: Color {
        switch self {
        case .bronze: return Color(hex: 0xA8743A)
        case .silver: return Color(hex: 0x9AA0A6)
        case .gold:   return WC.gold
        case .icon:   return WC.coral
        }
    }

    static func < (lhs: Rarity, rhs: Rarity) -> Bool { lhs.rank < rhs.rank }
}
