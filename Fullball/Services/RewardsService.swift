import Foundation
import SwiftData

/// What a daily drop grants.
struct DailyReward: Sendable {
    let coins: Int
    let tickets: Int
}

/// Daily login reward — a simple retention loop. Persists the last claim
/// day via the shared `LiveProgress` meta row.
@MainActor
protocol RewardsService: AnyObject {
    var canClaimDaily: Bool { get }
    func claimDaily() -> DailyReward?
}

@MainActor
final class DefaultRewardsService: RewardsService {
    private let context: ModelContext
    private let wallet: any WalletService
    private let meta: LiveProgress

    static let dailyReward = DailyReward(coins: 600, tickets: 3)

    init(context: ModelContext, wallet: any WalletService) {
        self.context = context
        self.wallet = wallet
        let descriptor = FetchDescriptor<LiveProgress>()
        if let existing = try? context.fetch(descriptor).first {
            self.meta = existing
        } else {
            let fresh = LiveProgress()
            context.insert(fresh)
            self.meta = fresh
            try? context.save()
        }
    }

    var canClaimDaily: Bool {
        guard let last = meta.lastDailyClaim else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    func claimDaily() -> DailyReward? {
        guard canClaimDaily else { return nil }
        let reward = Self.dailyReward
        wallet.credit(.coins, reward.coins)
        wallet.credit(.tickets, reward.tickets)
        meta.lastDailyClaim = .now
        try? context.save()
        return reward
    }
}
