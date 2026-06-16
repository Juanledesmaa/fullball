import Foundation

/// Field position for a stylized catalog player.
enum Position: String, Codable, CaseIterable, Sendable {
    case gk = "GK"
    case def = "DEF"
    case mid = "MID"
    case fwd = "FWD"

    var displayName: String {
        switch self {
        case .gk:  return "Goalkeeper"
        case .def: return "Defender"
        case .mid: return "Midfielder"
        case .fwd: return "Forward"
        }
    }

    /// SF Symbol stand-in art for this position.
    var symbol: String {
        switch self {
        case .gk:  return "figure.handball"
        case .def: return "shield.lefthalf.filled"
        case .mid: return "figure.run"
        case .fwd: return "figure.soccer"
        }
    }
}

/// Base attributes for a player. Plain value type loaded from JSON.
struct Stats: Codable, Sendable, Hashable {
    var pace: Int
    var shooting: Int
    var passing: Int
    var defending: Int

    /// Overall rating — simple mean, used for sorting / display.
    var overall: Int { Int((Double(pace + shooting + passing + defending) / 4.0).rounded()) }

    static func + (lhs: Stats, rhs: Stats) -> Stats {
        Stats(pace: lhs.pace + rhs.pace,
              shooting: lhs.shooting + rhs.shooting,
              passing: lhs.passing + rhs.passing,
              defending: lhs.defending + rhs.defending)
    }
}

/// Stylized, fictional catalog player. No real likeness — identified by a
/// nation tag + shirt number (e.g. "Argentina · #10 · Forward").
struct Player: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let displayName: String   // e.g. "Argentina #10"
    let nationTag: String     // e.g. "ARG"
    let shirtNumber: Int
    let position: Position
    let stats: Stats
}
