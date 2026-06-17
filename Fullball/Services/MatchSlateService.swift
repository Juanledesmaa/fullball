import Foundation
import SwiftData

/// Owns the current procedurally-generated match slate and lets the player
/// pay Gems to refresh it early. The free slate refreshes every time block;
/// a manual refresh mixes a counter into the seed (new matches) and persists
/// it so the refreshed slate survives relaunch.
@MainActor
@Observable
final class MatchSlateService {
    private let catalog: any CatalogService
    private let wallet: any WalletService
    private let context: ModelContext
    private let meta: LiveProgress

    private(set) var fixtures: [Fixture]
    private(set) var slateID: String

    init(context: ModelContext, catalog: any CatalogService, wallet: any WalletService) {
        self.context = context
        self.catalog = catalog
        self.wallet = wallet
        let descriptor = FetchDescriptor<LiveProgress>()
        if let existing = try? context.fetch(descriptor).first {
            self.meta = existing
        } else {
            let fresh = LiveProgress(); context.insert(fresh); self.meta = fresh; try? context.save()
        }
        // Reset the manual-refresh counter when the free time block rolls over.
        let base = DeviceSeed.slateID()
        if meta.slateBlock != base {
            meta.slateBlock = base
            meta.slateRefreshCount = 0
            try? context.save()
        }
        let id = Self.effectiveID(base: base, refresh: meta.slateRefreshCount)
        self.slateID = id
        self.fixtures = Self.generate(slateID: id, catalog: catalog)
    }

    var refreshCount: Int { meta.slateRefreshCount }
    var nextRefreshCost: Int { RefreshRules.cost(forCount: refreshCount) }
    var canAffordRefresh: Bool { wallet.balance(.gems) >= nextRefreshCost }

    /// Pay Gems to regenerate a fresh slate now. Returns false if unaffordable.
    @discardableResult
    func refresh() -> Bool {
        guard wallet.debit(.gems, nextRefreshCost) else { return false }
        meta.slateRefreshCount += 1
        try? context.save()
        let base = meta.slateBlock ?? DeviceSeed.slateID()
        slateID = Self.effectiveID(base: base, refresh: meta.slateRefreshCount)
        fixtures = Self.generate(slateID: slateID, catalog: catalog)
        return true
    }

    private static func effectiveID(base: String, refresh: Int) -> String {
        refresh == 0 ? base : "\(base)#r\(refresh)"
    }

    private static func generate(slateID: String, catalog: any CatalogService) -> [Fixture] {
        FixtureGenerator.slate(seed: DeviceSeed.sharedSeed(for: slateID),
                               nations: catalog.nations, cards: catalog.cards)
    }
}
