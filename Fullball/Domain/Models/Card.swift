import Foundation

/// A static catalog card: a player at a given rarity, with an art reference.
/// Loaded from bundled JSON; never mutated.
struct Card: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let player: Player
    let rarity: Rarity
    let artRef: String   // SF Symbol name used as stand-in art

    var displayName: String { player.displayName }
}
