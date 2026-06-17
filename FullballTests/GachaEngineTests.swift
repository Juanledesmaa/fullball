import Testing
@testable import Fullball

struct GachaEngineTests {

    // MARK: base odds

    @Test func baseOddsHoldOverLargeN() {
        var rng = SeededRandomProvider(seed: 0xC0FFEE)
        let n = 300_000
        var counts: [Rarity: Int] = [:]
        for _ in 0..<n {
            let r = rng.nextUnit()
            let rarity = GachaEngine.rarity(forPullNumber: 1, roll: r)
            counts[rarity, default: 0] += 1
        }
        func frac(_ r: Rarity) -> Double { Double(counts[r, default: 0]) / Double(n) }

        // Each tier should land near its disclosed base odds.
        #expect(abs(frac(.bronze) - 0.70) < 0.01)
        #expect(abs(frac(.silver) - 0.22) < 0.01)
        #expect(abs(frac(.gold)  - 0.073) < 0.01)
        #expect(abs(frac(.icon)  - 0.007) < 0.004)
    }

    @Test func baseOddsSumToOne() {
        let sum = Rarity.allCases.reduce(0.0) { $0 + $1.baseOdds }
        #expect(abs(sum - 1.0) < 1e-9)
    }

    @Test func rarityThresholdsArePartitioned() {
        // Roll 0 → lowest tier; roll just under 1 → top tier.
        #expect(GachaEngine.rarity(forPullNumber: 1, roll: 0.0) == .bronze)
        #expect(GachaEngine.rarity(forPullNumber: 1, roll: 0.9999) == .icon)
    }

    // MARK: soft pity

    @Test func softPityRaisesCombinedTopOdds() {
        let base = Rarity.icon.baseOdds
        #expect(GachaEngine.iconOdds(forPullNumber: 39) == base)
        #expect(GachaEngine.iconOdds(forPullNumber: 40) > base)
        // Monotonic ramp from soft pity to hard pity.
        for n in GachaEngine.softPityStart..<GachaEngine.hardPity {
            #expect(GachaEngine.iconOdds(forPullNumber: n + 1) > GachaEngine.iconOdds(forPullNumber: n))
        }
        #expect(GachaEngine.iconOdds(forPullNumber: 45) > GachaEngine.iconOdds(forPullNumber: 40))
    }

    // MARK: hard pity

    @Test func hardPityGuaranteesIconForAnyRoll() {
        for roll in [0.0, 0.25, 0.5, 0.75, 0.999] {
            #expect(GachaEngine.rarity(forPullNumber: GachaEngine.hardPity, roll: roll) == .icon)
        }
    }

    @Test func hardPityRollResetsCounter() {
        var rng = ScriptedRandomProvider([0.99, 0.0, 0.0]) // rarity roll ignored at hard pity
        let pity = PityState(pullsSinceIcon: GachaEngine.hardPity - 1, guaranteeFeatured: false)
        let outcome = GachaEngine.roll(banner: Fixtures.standardBanner, pity: pity,
                                       pool: Fixtures.pool, provider: &rng)
        #expect(outcome.card.rarity == .icon)
        #expect(outcome.pityAfter.pullsSinceIcon == 0)
    }

    @Test func nonIconRollIncrementsCounter() {
        var rng = ScriptedRandomProvider([0.0, 0.0]) // bronze, pick first
        let pity = PityState(pullsSinceIcon: 5)
        let outcome = GachaEngine.roll(banner: Fixtures.standardBanner, pity: pity,
                                       pool: Fixtures.pool, provider: &rng)
        #expect(outcome.card.rarity == .bronze)
        #expect(outcome.pityAfter.pullsSinceIcon == 6)
    }

    // MARK: 50/50

    @Test func lostFiftyFiftyGivesOffBannerAndSetsGuarantee() {
        // hard pity icon, coin >= 0.5 -> off-banner, pick index 0
        var rng = ScriptedRandomProvider([0.99, 0.9, 0.0])
        let pity = PityState(pullsSinceIcon: GachaEngine.hardPity - 1, guaranteeFeatured: false)
        let outcome = GachaEngine.roll(banner: Fixtures.featuredBanner, pity: pity,
                                       pool: Fixtures.pool, provider: &rng)
        #expect(outcome.card.rarity == .icon)
        #expect(!Fixtures.featuredBanner.featuredCardIDs.contains(outcome.card.id))
        #expect(outcome.pityAfter.guaranteeFeatured == true)
    }

    @Test func wonFiftyFiftyGivesFeaturedNoGuarantee() {
        // coin < 0.5 -> featured immediately
        var rng = ScriptedRandomProvider([0.99, 0.1, 0.0])
        let pity = PityState(pullsSinceIcon: GachaEngine.hardPity - 1, guaranteeFeatured: false)
        let outcome = GachaEngine.roll(banner: Fixtures.featuredBanner, pity: pity,
                                       pool: Fixtures.pool, provider: &rng)
        #expect(Fixtures.featuredBanner.featuredCardIDs.contains(outcome.card.id))
        #expect(outcome.pityAfter.guaranteeFeatured == false)
    }

    @Test func guaranteedFeaturedSkipsCoinAndPinsFeatured() {
        // guaranteeFeatured true -> no coin consumed, featured for sure
        var rng = ScriptedRandomProvider([0.99, 0.0])
        let pity = PityState(pullsSinceIcon: GachaEngine.hardPity - 1, guaranteeFeatured: true)
        let outcome = GachaEngine.roll(banner: Fixtures.featuredBanner, pity: pity,
                                       pool: Fixtures.pool, provider: &rng)
        #expect(Fixtures.featuredBanner.featuredCardIDs.contains(outcome.card.id))
        #expect(outcome.pityAfter.guaranteeFeatured == false)
    }
}
