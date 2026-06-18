import Foundation

/// Match tempo / risk. Aggressive creates more chances (both ends) and tires
/// players faster; conservative is calmer and gentler on energy.
enum Intensity: Int, Codable, Sendable, CaseIterable, Equatable {
    case conservative = -1
    case balanced = 0
    case aggressive = 1

    var displayName: String {
        switch self {
        case .conservative: return "Conservative"
        case .balanced:     return "Balanced"
        case .aggressive:   return "Aggressive"
        }
    }
    /// One-line, player-facing impact.
    var impact: String {
        switch self {
        case .conservative: return "Fewer chances both ways · players tire less"
        case .balanced:     return "Even tempo · normal energy use"
        case .aggressive:   return "More chances both ways · players tire faster"
        }
    }
    /// Energy-drain multiplier applied after the match.
    var drainFactor: Double {
        switch self {
        case .conservative: return 0.7
        case .balanced:     return 1.0
        case .aggressive:   return 1.4
        }
    }
}

/// Where the team tilts. Attack lifts your chances created AND conceded;
/// Defend lowers both.
enum Focus: Int, Codable, Sendable, CaseIterable, Equatable {
    case defend = -1
    case balanced = 0
    case attack = 1

    var displayName: String {
        switch self {
        case .defend:   return "Defend"
        case .balanced: return "Balanced"
        case .attack:   return "Attack"
        }
    }
    var impact: String {
        switch self {
        case .defend:   return "Fewer goals for and against"
        case .balanced: return "No tilt"
        case .attack:   return "More goals for — and against"
        }
    }
}

/// The two pre-match decisions. Pure value type.
struct Tactics: Codable, Sendable, Equatable {
    var intensity: Intensity = .balanced
    var focus: Focus = .balanced

    init(intensity: Intensity = .balanced, focus: Focus = .balanced) {
        self.intensity = intensity
        self.focus = focus
    }
}
