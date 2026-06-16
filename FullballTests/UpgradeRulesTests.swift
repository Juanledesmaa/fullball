import Testing
@testable import Fullball

struct UpgradeRulesTests {

    @Test func levelCapScalesWithStars() {
        #expect(UpgradeRules.levelCap(stars: 0) == 10)
        #expect(UpgradeRules.levelCap(stars: 1) == 20)
        #expect(UpgradeRules.levelCap(stars: 5) == 60)
    }

    @Test func xpRollsLevelUpOnThreshold() {
        let start = UpgradeState(level: 1, stars: 0, xp: 0)
        let one = UpgradeRules.applyXP(start, gained: UpgradeRules.xpToNext(level: 1))
        #expect(one.level == 2)
        #expect(one.xp == 0)
    }

    @Test func xpCarriesRemainderForward() {
        let start = UpgradeState(level: 1, stars: 0, xp: 0)
        let s = UpgradeRules.applyXP(start, gained: UpgradeRules.xpToNext(level: 1) + 30)
        #expect(s.level == 2)
        #expect(s.xp == 30)
    }

    @Test func xpClampsAtLevelCap() {
        let start = UpgradeState(level: 1, stars: 0, xp: 0)
        let s = UpgradeRules.applyXP(start, gained: 1_000_000)
        #expect(s.level == UpgradeRules.levelCap(stars: 0))
        #expect(s.xp == 0)
    }

    @Test func limitBreakAddsStarAndConsumesCopies() {
        let start = UpgradeState(level: 1, stars: 0, xp: 0)
        let result = UpgradeRules.limitBreak(start, copies: 3, rarity: .gold)
        #expect(result.state.stars == 1)
        #expect(result.copies == 2) // copiesForStar(1) == 1
    }

    @Test func limitBreakRaisesLevelCap() {
        let before = UpgradeRules.levelCap(stars: 0)
        let after = UpgradeRules.limitBreak(UpgradeState(level: 1, stars: 0, xp: 0),
                                            copies: 5, rarity: .icon)
        #expect(UpgradeRules.levelCap(stars: after.state.stars) > before)
    }

    @Test func cannotExceedStarCap() {
        let capped = UpgradeState(level: 1, stars: Rarity.bronze.starCap, xp: 0)
        #expect(!UpgradeRules.canLimitBreak(capped, copies: 99, rarity: .bronze))
        let noop = UpgradeRules.limitBreak(capped, copies: 99, rarity: .bronze)
        #expect(noop.state.stars == Rarity.bronze.starCap)
        #expect(noop.copies == 99)
    }

    @Test func insufficientCopiesIsNoOp() {
        let start = UpgradeState(level: 1, stars: 1, xp: 0) // next star needs 2 copies
        #expect(!UpgradeRules.canLimitBreak(start, copies: 1, rarity: .gold))
        let noop = UpgradeRules.limitBreak(start, copies: 1, rarity: .gold)
        #expect(noop.state.stars == 1)
    }

    @Test func effectiveStatsGrowWithLevelAndStars() {
        let base = Stats(pace: 50, shooting: 50, passing: 50, defending: 50)
        let lvl1 = UpgradeRules.effectiveStats(base: base, level: 1, stars: 0)
        let upgraded = UpgradeRules.effectiveStats(base: base, level: 5, stars: 2)
        #expect(lvl1.pace == 50)
        #expect(upgraded.pace > lvl1.pace)
        #expect(upgraded.shooting > lvl1.shooting)
    }
}

struct LeaderboardTests {
    @Test func ranksByPointsThenName() {
        let entries = [
            LeaderboardEntry(userName: "Zed", points: 100),
            LeaderboardEntry(userName: "Ana", points: 100),   // tie → name asc
            LeaderboardEntry(userName: "Max", points: 250),
        ]
        let ranked = Leaderboard.ranked(entries)
        #expect(ranked[0].userName == "Max" && ranked[0].rank == 1)
        #expect(ranked[1].userName == "Ana" && ranked[1].rank == 2)
        #expect(ranked[2].userName == "Zed" && ranked[2].rank == 3)
    }
}
