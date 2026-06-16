import SwiftUI

@MainActor
@Observable
final class CardDetailViewModel {
    private let collection: any CollectionService
    private let wallet: any WalletService
    let card: Card
    private(set) var instance: CardInstance?

    init(container: AppContainer, cardID: String) {
        self.collection = container.collection
        self.wallet = container.wallet
        self.card = container.catalog.card(id: cardID)
            ?? Card(id: cardID, player: Player(id: cardID, displayName: cardID, nationTag: "?",
                    shirtNumber: 0, position: .mid, stats: Stats(pace: 0, shooting: 0, passing: 0, defending: 0)),
                    rarity: .bronze, artRef: "questionmark")
        self.instance = container.collection.instance(forCardID: cardID)
    }

    var owned: Bool { instance != nil }
    var level: Int { instance?.level ?? 1 }
    var stars: Int { instance?.stars ?? 0 }
    var xp: Int { instance?.xp ?? 0 }
    var copies: Int { instance?.copies ?? 0 }

    var levelCap: Int { UpgradeRules.levelCap(stars: stars) }
    var atLevelCap: Bool { level >= levelCap }
    var xpToNext: Int { UpgradeRules.xpToNext(level: level) }
    var xpProgress: Double { atLevelCap ? 1 : min(1, Double(xp) / Double(xpToNext)) }

    var effectiveStats: Stats {
        UpgradeRules.effectiveStats(base: card.player.stats, level: level, stars: stars)
    }

    var trainCost: Int { UpgradeRules.trainCoinCost(level: level) }
    var canTrain: Bool { owned && !atLevelCap && wallet.balance(.coins) >= trainCost }

    var copiesForNextStar: Int { UpgradeRules.copiesForStar(stars + 1) }
    var canLimitBreak: Bool {
        guard let instance else { return false }
        return UpgradeRules.canLimitBreak(
            UpgradeState(level: instance.level, stars: instance.stars, xp: instance.xp),
            copies: instance.copies, rarity: card.rarity)
    }
    var maxedStars: Bool { stars >= card.rarity.starCap }

    func train() { if let instance { collection.train(instance) } }
    func limitBreak() { if let instance { collection.limitBreak(instance) } }
}
