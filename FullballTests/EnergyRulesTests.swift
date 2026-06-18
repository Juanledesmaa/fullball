import Testing
@testable import Fullball

struct EnergyRulesTests {
    @Test func fullEnergyHasNoPenalty() {
        let s = Stats(pace: 80, shooting: 80, passing: 80, defending: 80)
        #expect(EnergyRules.applyPenalty(to: s, energy: 100) == s)
        #expect(EnergyRules.applyPenalty(to: s, energy: 50) == s)
    }

    @Test func lowEnergyScalesStatsDown() {
        let s = Stats(pace: 80, shooting: 80, passing: 80, defending: 80)
        let tired = EnergyRules.applyPenalty(to: s, energy: 0)
        #expect(tired.shooting < s.shooting)
        #expect(tired.overall < s.overall)
        #expect(tired.shooting == 56) // 80 * (1 - 0.30)
    }

    @Test func penaltyIsMonotonicInEnergy() {
        let s = Stats(pace: 80, shooting: 80, passing: 80, defending: 80)
        let e10 = EnergyRules.applyPenalty(to: s, energy: 10).overall
        let e40 = EnergyRules.applyPenalty(to: s, energy: 40).overall
        #expect(e10 <= e40)
    }

    @Test func regenIsClampedToMax() {
        #expect(EnergyRules.regen(from: 90, minutesElapsed: 1000) == EnergyRules.maxEnergy)
        #expect(EnergyRules.regen(from: 50, minutesElapsed: 0) == 50)
    }

    @Test func drainAfterMatchSubtractsBaseAndCaptainExtra() {
        #expect(EnergyRules.afterMatch(energy: 100, isCaptain: false) == 80)
        #expect(EnergyRules.afterMatch(energy: 100, isCaptain: true) == 70)
        #expect(EnergyRules.afterMatch(energy: 10, isCaptain: true) == 0)
    }

    @Test func refillCostIsProportionalToMissingEnergy() {
        #expect(EnergyRules.refillCost(currentEnergy: 100) == 0)
        #expect(EnergyRules.refillCost(currentEnergy: 0) == EnergyRules.maxRefillGems)
        let half = EnergyRules.refillCost(currentEnergy: 50)
        #expect(half > 0 && half < EnergyRules.maxRefillGems)
    }
}
