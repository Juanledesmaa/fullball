import Testing
@testable import Fullball

struct OpponentGeneratorTests {
    private let cat = MockCatalogService()
    private func anyTag() -> String { cat.cards.first!.player.nationTag }

    @Test func deterministicForSameSeed() {
        let a = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 42)
        let b = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 42)
        #expect(a == b)
    }
    @Test func producesFivePlayersWithOneKeeper() {
        let side = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 7)
        #expect(side.players.count == 5)
        #expect(side.goalkeeper != nil)
        #expect(side.outfield.count == 4)
    }
    @Test func fallsBackToGlobalPoolWhenNationTooSmall() {
        let side = OpponentGenerator.opponent(awayTag: "ZZZ", cards: cat.cards, seed: 3)
        #expect(side.players.count == 5)
    }
    @Test func opponentStatsAreBoostedAboveCatalog() {
        let side = OpponentGenerator.opponent(awayTag: anyTag(), cards: cat.cards, seed: 5)
        for p in side.players {
            guard let raw = cat.cards.first(where: { $0.id == p.id })?.player.stats else { continue }
            // Boost is multiplicative (>1) and clamped to 99, so each stat is >= its catalog value.
            #expect(p.stats.pace >= raw.pace)
            #expect(p.stats.shooting >= raw.shooting)
            #expect(p.stats.passing >= raw.passing)
            #expect(p.stats.defending >= raw.defending)
            #expect(p.stats.overall >= raw.overall)
        }
    }
}
