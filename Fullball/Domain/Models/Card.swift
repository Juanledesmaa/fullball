import Foundation

/// A static catalog card: a player at a given rarity, with an art reference.
/// Loaded from bundled JSON; never mutated.
struct Card: Codable, Sendable, Identifiable, Hashable {
    let id: String
    let player: Player
    let rarity: Rarity
    var artRef: String? = nil   // legacy SF-symbol stand-in (unused once images land)

    var displayName: String { player.displayName }
    /// Storage path / cache key for the portrait. Convention: the card id.
    var imageRef: String { id }
}
