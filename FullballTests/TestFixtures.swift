import Foundation
@testable import Fullball

/// Small synthetic catalog for engine tests — a handful of cards per
/// rarity, plus featured/off-banner Icons.
enum Fixtures {
    static func player(_ id: String) -> Player {
        Player(id: id, displayName: id, nationTag: "TST", shirtNumber: 10,
               position: .fwd, stats: Stats(pace: 70, shooting: 70, passing: 70, defending: 50))
    }

    static func card(_ id: String, _ rarity: Rarity) -> Card {
        Card(id: id, player: player(id), rarity: rarity, artRef: "figure")
    }

    static let pool: [Card] = {
        var cards: [Card] = []
        for r in [Rarity.bronze, .silver, .gold, .epic] {
            for i in 0..<5 { cards.append(card("\(r.rawValue)-\(i)", r)) }
        }
        // Icons: two featured, two off-banner.
        cards.append(card("icon-feat-0", .icon))
        cards.append(card("icon-feat-1", .icon))
        cards.append(card("icon-off-0", .icon))
        cards.append(card("icon-off-1", .icon))
        return cards
    }()

    static let featuredBanner = Banner(
        id: "featured", title: "Today's Match", subtitle: "Rate-up",
        type: .featured, featuredCardIDs: ["icon-feat-0", "icon-feat-1"],
        singleCost: .ticket(1), multiCost: .gems(1600))

    static let standardBanner = Banner(
        id: "standard", title: "Standard", subtitle: "Always on",
        type: .standard, featuredCardIDs: [],
        singleCost: .ticket(1), multiCost: .gems(1600))
}
