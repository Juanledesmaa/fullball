/// A player's tactical style, derived from their dominant outfield stat.
/// Forms a rock-paper-scissors triangle used in duels and counter-picks.
enum PlayStyle: String, Codable, Sendable, CaseIterable, Equatable {
    case technical   // passing-led
    case physical    // defending-led
    case pace        // speed-led

    /// Derive from base/effective stats. Tie priority: technical > physical > pace.
    static func from(_ s: Stats) -> PlayStyle {
        if s.passing >= s.defending && s.passing >= s.pace { return .technical }
        if s.defending >= s.pace { return .physical }
        return .pace
    }

    /// RPS: pace > physical > technical > pace.
    /// +1 if `self` beats `other`, -1 if it loses, 0 if same style.
    func edge(against other: PlayStyle) -> Int {
        if self == other { return 0 }
        switch (self, other) {
        case (.pace, .physical), (.physical, .technical), (.technical, .pace): return 1
        default: return -1
        }
    }

    var displayName: String {
        switch self {
        case .technical: return "Technical"
        case .physical:  return "Physical"
        case .pace:      return "Pace"
        }
    }
}
