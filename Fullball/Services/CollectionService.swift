import Foundation
import SwiftData

/// An owned card paired with its catalog entry, for display.
struct OwnedCard: Identifiable {
    let instance: CardInstance
    let card: Card
    var id: String { card.id }

    var rarity: Rarity { card.rarity }
    var effectiveStats: Stats {
        UpgradeRules.effectiveStats(base: card.player.stats,
                                    level: instance.level, stars: instance.stars)
    }
}

/// Owns the player's collection (`CardInstance`s) and upgrade actions.
@MainActor
protocol CollectionService: AnyObject {
    func owned() -> [OwnedCard]
    func instance(forCardID id: String) -> CardInstance?
    /// Adds a pulled card; returns true if it's newly owned.
    @discardableResult func acquire(cardID: String) -> Bool
    /// Spend coins to train (apply XP) a card. Returns true on success.
    @discardableResult func train(_ instance: CardInstance) -> Bool
    /// Consume duplicate copies to add a star. Returns true on success.
    @discardableResult func limitBreak(_ instance: CardInstance) -> Bool
}

@MainActor
final class SwiftDataCollectionService: CollectionService {
    private let context: ModelContext
    private let catalog: any CatalogService
    private unowned let wallet: any WalletService

    init(context: ModelContext, catalog: any CatalogService, wallet: any WalletService) {
        self.context = context
        self.catalog = catalog
        self.wallet = wallet
    }

    func owned() -> [OwnedCard] {
        let descriptor = FetchDescriptor<CardInstance>(
            sortBy: [SortDescriptor(\.dateAcquired, order: .reverse)])
        let instances = (try? context.fetch(descriptor)) ?? []
        return instances.compactMap { inst in
            catalog.card(id: inst.cardID).map { OwnedCard(instance: inst, card: $0) }
        }
    }

    func instance(forCardID id: String) -> CardInstance? {
        let descriptor = FetchDescriptor<CardInstance>(
            predicate: #Predicate { $0.cardID == id })
        return try? context.fetch(descriptor).first
    }

    @discardableResult
    func acquire(cardID: String) -> Bool {
        if let existing = instance(forCardID: cardID) {
            existing.copies += 1          // duplicate → limit-break fuel
            try? context.save()
            return false
        }
        let inst = CardInstance(cardID: cardID)
        context.insert(inst)
        try? context.save()
        return true
    }

    @discardableResult
    func train(_ instance: CardInstance) -> Bool {
        guard let card = catalog.card(id: instance.cardID) else { return false }
        let cap = UpgradeRules.levelCap(stars: instance.stars)
        guard instance.level < cap else { return false }
        let cost = UpgradeRules.trainCoinCost(level: instance.level)
        guard wallet.debit(.coins, cost) else { return false }
        let state = UpgradeState(level: instance.level, stars: instance.stars, xp: instance.xp)
        let next = UpgradeRules.applyXP(state, gained: UpgradeRules.xpPerTrain)
        instance.level = next.level
        instance.xp = next.xp
        _ = card // rarity not needed for training, kept for symmetry
        try? context.save()
        return true
    }

    @discardableResult
    func limitBreak(_ instance: CardInstance) -> Bool {
        guard let card = catalog.card(id: instance.cardID) else { return false }
        let state = UpgradeState(level: instance.level, stars: instance.stars, xp: instance.xp)
        guard UpgradeRules.canLimitBreak(state, copies: instance.copies, rarity: card.rarity)
        else { return false }
        let result = UpgradeRules.limitBreak(state, copies: instance.copies, rarity: card.rarity)
        instance.stars = result.state.stars
        instance.copies = result.copies
        try? context.save()
        return true
    }
}
