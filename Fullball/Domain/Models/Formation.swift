/// 5-a-side shape (GK fixed + 4 outfield). Forms a shape RPS triangle.
enum Formation: String, Codable, Sendable, CaseIterable, Equatable {
    case diamond     // 1-2-1, balanced
    case defensive   // 2-1-1
    case attacking   // 1-1-2

    /// Shape RPS: defensive > attacking > diamond > defensive.
    func edge(against other: Formation) -> Int {
        if self == other { return 0 }
        switch (self, other) {
        case (.defensive, .attacking), (.attacking, .diamond), (.diamond, .defensive): return 1
        default: return -1
        }
    }

    var displayName: String {
        switch self {
        case .diamond:   return "Diamond 1-2-1"
        case .defensive: return "Defensive 2-1-1"
        case .attacking: return "Attacking 1-1-2"
        }
    }
}
