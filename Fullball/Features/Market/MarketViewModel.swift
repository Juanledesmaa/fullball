import SwiftUI

@MainActor
@Observable
final class MarketViewModel {
    private let market: TransferMarketService
    private let walletService: any WalletService
    var toast: String?

    init(container: AppContainer) {
        self.market = container.market
        self.walletService = container.wallet
    }

    var listings: [TransferListing] { market.listings }
    var cash: Int { walletService.balance(.coins) }

    func canAfford(_ l: TransferListing) -> Bool { market.canAfford(l) }
    func owned(_ l: TransferListing) -> Bool { market.owned(l) }

    func sign(_ l: TransferListing) {
        if market.sign(l) {
            toast = "Signed \(l.card.funnyName) for \(l.price) Cash"
        } else {
            toast = "Not enough Cash to sign \(l.card.funnyName)"
        }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            self?.toast = nil
        }
    }
}
