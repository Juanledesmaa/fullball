import Foundation

/// Raw, provider-agnostic player signal used to synthesize a fictional
/// card. Carries NO real name — only structural data (nation, position,
/// rating) — so likeness can never leak into the catalog.
struct PlayerSignal: Sendable {
    let nationTag: String
    let position: Position
    let rating: Double?   // e.g. api-football 0–10 match rating
}

/// Turns real-world *structure* (nations, positions, ratings) into wholly
/// fictional cards (`TAG #num`). The single chokepoint that enforces the
/// no-real-likeness constraint — unit-tested.
enum Fictionalizer {
    /// Map a 0–10 rating to a rarity band (mirrors the offline generator).
    static func rarity(forRating rating: Double?) -> Rarity {
        guard let r = rating else { return .bronze }
        switch r {
        case 7.6...: return .icon
        case 6.8..<7.6: return .gold
        case 6.6..<6.8: return .silver
        default: return .bronze
        }
    }

    static func stats(rarity: Rarity, position: Position, seed: Int) -> Stats {
        let overall: Int = {
            switch rarity {
            case .bronze: return 62; case .silver: return 70; case .gold: return 78
            case .icon: return 91
            }
        }()
        func jit(_ base: Int, _ salt: Int) -> Int {
            // Deterministic ±5 jitter from the seed — no Math.random.
            let j = ((seed &* 31 &+ salt) % 11) - 5
            return max(38, min(99, base + j))
        }
        switch position {
        case .fwd: return Stats(pace: jit(overall + 5, 1), shooting: jit(overall + 6, 2),
                                passing: jit(overall - 3, 3), defending: jit(overall - 18, 4))
        case .mid: return Stats(pace: jit(overall, 1), shooting: jit(overall - 2, 2),
                                passing: jit(overall + 6, 3), defending: jit(overall - 4, 4))
        case .def: return Stats(pace: jit(overall - 2, 1), shooting: jit(overall - 16, 2),
                                passing: jit(overall - 2, 3), defending: jit(overall + 7, 4))
        case .gk:  return Stats(pace: jit(overall - 10, 1), shooting: jit(overall - 24, 2),
                                passing: jit(overall - 4, 3), defending: jit(overall + 9, 4))
        }
    }

    /// Build fictional cards from raw signals. Shirt numbers are assigned
    /// per-nation in arrival order. Names are ALWAYS `TAG #num`.
    static func cards(from signals: [PlayerSignal]) -> [Card] {
        var nextShirt: [String: Int] = [:]
        var cards: [Card] = []
        for (i, sig) in signals.enumerated() {
            let shirt = (nextShirt[sig.nationTag] ?? 1)
            nextShirt[sig.nationTag] = shirt + 1
            let rarity = rarity(forRating: sig.rating)
            let id = "\(sig.nationTag)-\(shirt)"
            let player = Player(id: id, displayName: "\(sig.nationTag) #\(shirt)",
                                nationTag: sig.nationTag, shirtNumber: shirt,
                                position: sig.position,
                                stats: stats(rarity: rarity, position: sig.position, seed: i + shirt))
            cards.append(Card(id: id, player: player, rarity: rarity, artRef: sig.position.symbol))
        }
        return cards
    }
}
