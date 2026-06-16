import SwiftUI

/// The four wallet currencies. Form Tokens are earned only from live
/// matches and are never purchasable.
enum Currency: String, CaseIterable, Sendable, Identifiable {
    case coins, gems, tickets, formTokens

    var id: String { rawValue }

    // Themed for the agent fantasy: Cash is agency money, Gems the premium
    // transfer budget, Tickets scout passes, Rep unlocks bigger signings.
    var label: String {
        switch self {
        case .coins: return "Cash"
        case .gems: return "Gems"
        case .tickets: return "Scouts"
        case .formTokens: return "Rep"
        }
    }

    var symbol: String {
        switch self {
        case .coins: return "banknote.fill"
        case .gems: return "diamond.fill"
        case .tickets: return "binoculars.fill"
        case .formTokens: return "star.circle.fill"
        }
    }

    var tint: Color {
        switch self {
        case .coins: return WC.go
        case .gems: return Color(hex: 0x4FA8E0)
        case .tickets: return WC.coral
        case .formTokens: return WC.gold
        }
    }
}
