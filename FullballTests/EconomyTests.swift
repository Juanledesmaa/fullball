import Testing
@testable import Fullball

struct EconomyTests {

    // MARK: milestones

    @Test func earnedCountAcrossThresholds() {
        #expect(Milestones.earnedCount(0) == 0)
        #expect(Milestones.earnedCount(499) == 0)
        #expect(Milestones.earnedCount(500) == 1)
        #expect(Milestones.earnedCount(1500) == 2)
        #expect(Milestones.earnedCount(100_000) == Milestones.tiers.count)
    }

    @Test func newlyClaimableSkipsAlreadyClaimed() {
        // At 1500 pts with 0 claimed → tiers 0 and 1 are claimable.
        let first = Milestones.newlyClaimable(points: 1500, claimed: 0)
        #expect(first.count == 2)
        // With 2 already claimed → nothing new yet.
        #expect(Milestones.newlyClaimable(points: 1500, claimed: 2).isEmpty)
        // Cross the next threshold → exactly one new tier.
        #expect(Milestones.newlyClaimable(points: 3000, claimed: 2).count == 1)
    }

    @Test func nextMilestonePointsToward() {
        #expect(Milestones.next(after: 0)?.threshold == 500)
        #expect(Milestones.next(after: 600)?.threshold == 1500)
        #expect(Milestones.next(after: 100_000) == nil)
    }

    // MARK: exchange

    @Test func agentCommissionScalesWithPoints() {
        #expect(AgentRules.commission(forPoints: 0) == 0)
        #expect(AgentRules.commission(forPoints: 100) == 100 * AgentRules.cashPerPoint)
        #expect(AgentRules.commission(forPoints: -50) == 0)   // no commission on penalties
    }

    @Test func transferPriceRisesWithRarityAndOverall() {
        let bronze = TransferRules.price(rarity: .bronze, overall: 60)
        let icon = TransferRules.price(rarity: .icon, overall: 90)
        #expect(icon > bronze)
        #expect(TransferRules.price(rarity: .gold, overall: 90) >
                TransferRules.price(rarity: .gold, overall: 70))
    }

    @Test func refreshCostEscalates() {
        #expect(RefreshRules.cost(forCount: 0) == 150)
        #expect(RefreshRules.cost(forCount: 1) == 300)
        #expect(RefreshRules.cost(forCount: 2) == 450)
        #expect(RefreshRules.cost(forCount: 1) > RefreshRules.cost(forCount: 0))
    }

    @Test func exchangeAffordabilityGates() {
        #expect(!ExchangeRates.canBuyTicket(form: ExchangeRates.formPerTicket - 1))
        #expect(ExchangeRates.canBuyTicket(form: ExchangeRates.formPerTicket))
        #expect(!ExchangeRates.canBuyGemPack(form: ExchangeRates.formPerGemPack - 1))
        #expect(ExchangeRates.canBuyGemPack(form: ExchangeRates.formPerGemPack))
    }
}
