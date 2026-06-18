import Foundation

/// Attack↔Defend dial. Raises (attack) or lowers (defend) both your chances
/// created AND chances conceded.
enum Mentality: Int, Codable, Sendable, CaseIterable, Equatable {
    case parkBus  = -2
    case defend   = -1
    case balanced =  0
    case attack   =  1
    case allOut   =  2

    var displayName: String {
        switch self {
        case .parkBus:  return "Park the Bus"
        case .defend:   return "Defend"
        case .balanced: return "Balanced"
        case .attack:   return "Attack"
        case .allOut:   return "All Out"
        }
    }
}

/// A side's pre-match decisions. Persisted later; pure value type here.
struct Tactics: Codable, Sendable, Equatable {
    var formation: Formation = .diamond
    var mentality: Mentality = .balanced
    var markerID: String? = nil     // your player assigned to mark their danger man
    var counter: PlayStyle? = nil   // your counter-pick vs the opponent's team style

    init(formation: Formation = .diamond, mentality: Mentality = .balanced,
         markerID: String? = nil, counter: PlayStyle? = nil) {
        self.formation = formation
        self.mentality = mentality
        self.markerID = markerID
        self.counter = counter
    }
}
