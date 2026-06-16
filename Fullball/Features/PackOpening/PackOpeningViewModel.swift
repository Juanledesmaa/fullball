import SwiftUI

@MainActor
@Observable
final class PackOpeningViewModel {
    private let gacha: any GachaService
    private let catalog: any CatalogService
    private let walletService: any WalletService
    private let rewards: any RewardsService

    let banners: [Banner]
    var selectedBannerID: String
    var revealResults: [PullResult] = []
    var showReveal = false
    var errorMessage: String?
    var claimMessage: String?

    init(container: AppContainer) {
        self.gacha = container.gacha
        self.catalog = container.catalog
        self.walletService = container.wallet
        self.rewards = container.rewards
        self.banners = container.catalog.banners
        self.selectedBannerID = container.catalog.featuredBanner?.id
            ?? container.catalog.banners.first?.id ?? ""
    }

    var selectedBanner: Banner {
        banners.first { $0.id == selectedBannerID } ?? banners[0]
    }

    var pullsSinceIcon: Int { gacha.pullCount(for: selectedBannerID) }
    var pullsToGuarantee: Int { max(0, GachaEngine.hardPity - pullsSinceIcon) }

    func featuredCards() -> [Card] {
        selectedBanner.featuredCardIDs.compactMap { catalog.card(id: $0) }
    }

    func canAfford(multi: Bool) -> Bool {
        gacha.canAfford(multi ? selectedBanner.multiCost : selectedBanner.singleCost)
    }

    func costLabel(multi: Bool) -> String {
        let cost = multi ? selectedBanner.multiCost : selectedBanner.singleCost
        return "\(cost.amount) \(cost.currency.label)"
    }

    var dailyAvailable: Bool { rewards.canClaimDaily }

    func claimDaily() {
        if let r = rewards.claimDaily() {
            claimMessage = "Daily Drop claimed — +\(r.tickets) Tickets, +\(r.coins) Coins"
        }
    }

    func pull(multi: Bool) {
        do {
            let results = try gacha.pull(banner: selectedBanner, multi: multi)
            revealResults = results
            showReveal = true
        } catch {
            errorMessage = "Not enough \(multi ? selectedBanner.multiCost.currency.label : selectedBanner.singleCost.currency.label)"
        }
    }
}
