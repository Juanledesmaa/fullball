import Foundation

/// A single player as the engine sees them. `stats` are the FINAL effective
/// stats — the caller has already applied level/star (UpgradeRules) and any
/// energy penalty (EnergyRules) before handing them to the engine. The engine
/// itself is energy-agnostic and pure.
struct MatchPlayer: Sendable, Equatable, Identifiable {
    let id: String
    let position: Position
    let stats: Stats
    var style: PlayStyle { PlayStyle.from(stats) }
}

/// One team entering a match: exactly 5 players (one GK) plus their tactics
/// and the captain.
struct MatchSide: Sendable, Equatable {
    let players: [MatchPlayer]
    let tactics: Tactics
    let captainID: String?

    var goalkeeper: MatchPlayer? { players.first { $0.position == .gk } }
    var outfield: [MatchPlayer] { players.filter { $0.position != .gk } }
    func player(_ id: String?) -> MatchPlayer? {
        guard let id else { return nil }
        return players.first { $0.id == id }
    }
}

/// Per-player tallies produced by a match.
struct PlayerContribution: Sendable, Equatable, Identifiable {
    let playerID: String
    var goals = 0
    var assists = 0
    var saves = 0
    var points = 0
    var id: String { playerID }
}

/// One resolved possession, ordered, for later playback animation.
struct PossessionEvent: Sendable, Equatable, Identifiable {
    enum Outcome: String, Sendable, Equatable {
        case turnover, goal, save, miss
    }
    let index: Int
    let attackingHome: Bool
    let ballPlayerID: String
    let outcome: Outcome
    let assistID: String?
    var id: Int { index }
}

/// Full deterministic result of a match.
struct MatchResult: Sendable, Equatable {
    let homeGoals: Int
    let awayGoals: Int
    let events: [PossessionEvent]
    let homeContributions: [PlayerContribution]
    let awayContributions: [PlayerContribution]
}
