import Foundation
import SwiftData

// MARK: - Milestones

/// Grants milestone rewards as career points cross thresholds. Persists how
/// many tiers have been claimed (one-time, not farmable).
@MainActor
protocol MilestoneService: AnyObject {
    func next(points: Int) -> MilestoneTier?
    /// Grant any newly-crossed tiers; returns them for a toast.
    @discardableResult func claim(points: Int) -> [MilestoneTier]
}

@MainActor
final class DefaultMilestoneService: MilestoneService {
    private let context: ModelContext
    private let wallet: any WalletService
    private let meta: LiveProgress

    init(context: ModelContext, wallet: any WalletService) {
        self.context = context
        self.wallet = wallet
        let descriptor = FetchDescriptor<LiveProgress>()
        if let existing = try? context.fetch(descriptor).first {
            self.meta = existing
        } else {
            let fresh = LiveProgress(); context.insert(fresh); self.meta = fresh; try? context.save()
        }
    }

    func next(points: Int) -> MilestoneTier? { Milestones.next(after: points) }

    @discardableResult
    func claim(points: Int) -> [MilestoneTier] {
        let tiers = Milestones.newlyClaimable(points: points, claimed: meta.milestonesClaimed)
        guard !tiers.isEmpty else { return [] }
        for tier in tiers {
            wallet.credit(.gems, tier.gems)
            wallet.credit(.tickets, tier.tickets)
        }
        meta.milestonesClaimed = Milestones.earnedCount(points)
        try? context.save()
        return tiers
    }
}

// MARK: - Form exchange

/// Converts live-earned Form Tokens into pull currency.
@MainActor
protocol ExchangeService: AnyObject {
    @discardableResult func buyTicket() -> Bool
    @discardableResult func buyGemPack() -> Bool
}

@MainActor
final class DefaultExchangeService: ExchangeService {
    private let wallet: any WalletService
    init(wallet: any WalletService) { self.wallet = wallet }

    @discardableResult
    func buyTicket() -> Bool {
        guard wallet.balance(.formTokens) >= ExchangeRates.formPerTicket else { return false }
        wallet.debit(.formTokens, ExchangeRates.formPerTicket)
        wallet.credit(.tickets, 1)
        return true
    }

    @discardableResult
    func buyGemPack() -> Bool {
        guard wallet.balance(.formTokens) >= ExchangeRates.formPerGemPack else { return false }
        wallet.debit(.formTokens, ExchangeRates.formPerGemPack)
        wallet.credit(.gems, ExchangeRates.gemsPerPack)
        return true
    }
}
