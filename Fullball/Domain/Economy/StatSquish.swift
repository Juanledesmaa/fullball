import Foundation

/// Global balance knob that compresses authored player stats toward an anchor
/// before they enter play. The bundled/remote catalogs were authored hot (icons
/// near 90 OVR, individual stats up to 99); this pulls the ceiling down while
/// barely moving the floor, so early-game numbers feel earned.
///
/// Transform per stat: `new = anchor + (stat - anchor) * factor`, clamped 1...99.
/// `factor < 1` compresses toward `anchor`; `anchor` is the (roughly) fixed
/// point. Pure + deterministic — applied once at the catalog-load chokepoint
/// (`ResolvedCatalogService`), so it hits bundled, Firestore and api-football
/// catalogs uniformly. Set `factor = 1` to disable.
enum StatSquish {
    static let anchor = 56.0
    static let factor = 0.62

    static func value(_ v: Int) -> Int {
        let squished = anchor + (Double(v) - anchor) * factor
        return min(99, max(1, Int(squished.rounded())))
    }

    static func apply(_ s: Stats) -> Stats {
        Stats(pace: value(s.pace), shooting: value(s.shooting),
              passing: value(s.passing), defending: value(s.defending))
    }

    static func apply(_ card: Card) -> Card {
        let p = card.player
        let squished = Player(id: p.id, displayName: p.displayName, nationTag: p.nationTag,
                              shirtNumber: p.shirtNumber, position: p.position,
                              name: p.name, epithet: p.epithet, stats: apply(p.stats))
        return Card(id: card.id, player: squished, rarity: card.rarity, artRef: card.artRef)
    }
}
